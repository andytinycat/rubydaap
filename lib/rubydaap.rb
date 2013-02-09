#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
require 'logger'
require 'digest/md5'
require 'find'

require_relative 'rubydaap/track'
require_relative 'rubydaap/scanner'

class App < Sinatra::Base
  register Sinatra::Async       # Used for long-lived /update call
  register Sinatra::ConfigFile

  $log = Logger.new(STDOUT)
  $log.level = Logger::INFO
  
  $db = Mongo::MongoClient.new("localhost", 27017).db("rubydaap").collection("tracks")

  # Config file
  config_file "../config.yml"

  # Global var for server name, used in various responses
  $server_name = settings.server_name

  # Start scanner
  scanner = Scanner.new("/Users/andy/Music", "/Users/andy/musictest")
  scanner.run

  # Debug enabled
  $dmap_debug = false

  # Use Thin; iTunes doesn't seem to like something
  # in the way Sinatra chunks the request up.
  #set :server, 'thin'
  #set :port, Sinatra::Application.port
  ##set :logging, true
  #set :show_exceptions, true

  $log.info("Starting up")

  # Register with Bonjour so iTunes can find us
  bonjour = DNSSD.register($server_name, "_daap._tcp", nil, Sinatra::Application.port)
  $log.info("Registered on Bonjour with server name '#{server_name}'")  

  before do
    # iTunes sends a weird full URI when requesting songs, with
    # the daap:// scheme. Rewrite this to an appropriate Sinatra
    # handler.
    if request.env['REQUEST_URI'] =~ /^daap:\/\/[^\/]+(.*)/
      request.path_info = $1
    end
    headers 'DAAP-Server' => "ruby-daap/#{settings.version}"
    content_type "application/x-dmap-tagged"
  end

  # This is the first thing a connecting client calls.
  get '/server-info' do
    $log.info("Client requesting /server-info: #{request.ip}")
    # DMAP response indicating what we support
    resp = DMAP.build do
      msrv do
        mstt 200
        mpro [0,2,0,2]
        apro [0,3,0,2]
        minm $server_name
        mslr 1
        msau 0
        mstm 1800
        msal 1
        msup 1
        mspi 1
        msex 1
        msbr 1
        msqy 1
        msix 1
        msrs 0
        msdc 1
      end
    end
    p resp if $dmap_debug
    resp.to_dmap
  end

  # After getting server info, the client tries to log in.
  # We assign them a random session ID.
  get '/login' do

    sid = rand(4095)
    $log.info("Login request from #{request.ip}: assigning sid #{sid}")
    resp = DMAP.build do
      mlog do
        mstt 200
        mlid sid
      end
    end
    p resp if $dmap_debug
    resp.to_dmap
  end

  # Clients call update after logging in, and after retrieving
  # the song list. The second call has a 'delta' parameter equal
  # to the last revision they received. This is a long-lived request
  # that iTunes expects to keep open until an update happens.
  # The call post-login has revision != delta - we return immediately
  # so the client can get on with connecting. After retrieving a track
  # list, the update call has revision == data; the client expects this
  # to get a response to this later, with a higher revision number. This
  # is what we do using async_sinatra.
  aget '/update' do
    vers  = params['revision-number'].to_i
    delta = params['delta'].to_i
    if vers == delta
      $log.info("Client #{request.ip} requesting to be notified about updates; handling with async")
      vers = vers + 1
      resp = DMAP.build do
        mupd do
          mstt 200
          musr vers
        end
      end
      EM.add_timer(15) {
        body { 
          p resp if $dmap_debug
          $log.info("Sending update to client #{request.ip}")
          resp.to_dmap 
        }
      }
    else 
      $log.info("Client #{request.ip} requesting server revision via /update on login")
      resp = DMAP.build do
        mupd do
          mstt 200
          musr vers
        end
      end
      p resp if $dmap_debug
      body { 
        p resp if $dmap_debug
        resp.to_dmap 
      }
    end
  end

  # Once they've called update, they'll ask for the list of databases.
  get '/databases' do
    $log.info("Client #{request.ip} requesting list of databases")
    resp = DMAP.build do
      avdb do
        mstt 200
        muty 0
        mtco 1
        mrco 1
        mlcl do
          mlit do
            miid 1
            mper 1
            minm $server_name
            mimc 2
            mctc 1
          end
        end
      end
    end
    p resp if $dmap_debug
    resp.to_dmap
  end

  # Song list
  get '/databases/1/items' do
    $log.info("Client #{request.ip} requesting list of items in database")
    tracks = Track.get_all_dmap
    resp = DMAP::Tag.new(:adbs, [
      DMAP::Tag.new(:mstt, 200),
      DMAP::Tag.new(:muty, 0),
      DMAP::Tag.new(:mtco, tracks.length),
      DMAP::Tag.new(:mrco, tracks.length),
      DMAP::Tag.new(:mlcl, 
        tracks
      )
    ])
    p resp if $dmap_debug
    resp.to_dmap
  end

  # Playlist list
  get '/databases/1/containers' do
    $log.info("Client #{request.ip} requesting list of playlists")
    count = Track.count
    resp = DMAP.build do
      aply do
        mstt 200
        muty 0
        mtco 1
        mrco 1
        mlcl do
          mlit do
            miid 1
            mper 1
            minm $server_name
            mimc count
            abpl 1
          end
        end
      end
    end
    p resp if $dmap_debug
    resp.to_dmap
  end

  # Song list in playlist
  get '/databases/1/containers/1/items' do
    $log.info("Client #{request.ip} requesting list of items in playlist")
    tracks = Track.get_all_short_dmap
    resp = DMAP::Tag.new(:apso, [
      DMAP::Tag.new(:mstt, 200),
      DMAP::Tag.new(:muty, 0),
      DMAP::Tag.new(:mtco, tracks.length),
      DMAP::Tag.new(:mrco, tracks.length),
      DMAP::Tag.new(:mlcl, 
        tracks
      )
    ])
    p resp if $dmap_debug
    resp.to_dmap
  end

  # Play a file
  # /databases/1/items/109.m4a?session-id=733
  get %r{/databases/1/items/(\d+)\.(.*)} do
    track = Track.get_by_itunes_id(params[:captures].first.to_i)
    if env["HTTP_RANGE"]
      $log.info("Client #{request.ip} is seeking in #{track.artist} - #{track.title} from #{track.album} [track ID #{params[:captures].first.to_i}]")
    else 
      $log.info("Client #{request.ip} is playing #{track.artist} - #{track.title} from #{track.album} [track ID #{params[:captures].first.to_i}]")
    end
    send_file track.path 
  end

  run! if app_file == $0

end
