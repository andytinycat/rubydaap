#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'rack'
require 'sinatra/base'
require 'sinatra/config_file'
require 'sinatra/async'
require 'dnssd'
require 'dmap-ng'
require 'mongo'
require 'logger'
require 'digest/md5'

require_relative 'rubydaap/logging'
require_relative 'rubydaap/track'
require_relative 'rubydaap/scanner'

class App < Sinatra::Base
  register Sinatra::Async       # Used for long-lived /update call
  register Sinatra::ConfigFile

  # Config file
  config_file "../config.yml"

  # Global var for server name, used in various responses
  $server_name = settings.server_name

  # Debug enabled
  $dmap_debug = true

  # Use Thin; iTunes doesn't seem to like something
  # in the way Sinatra chunks the request up.
  set :server, 'thin'
  set :port, Sinatra::Application.port
  set :logging, true
  set :show_exceptions, true

  # Register with Bonjour so iTunes can find us
  bonjour = DNSSD.register($server_name, "_daap._tcp", nil, Sinatra::Application.port)

  # Headers to send on every request
  before do
    headers 'DAAP-Server' => "ruby-daap/#{settings.version}"
    content_type "application/x-dmap-tagged"
  end

  # This is the first thing a connecting client calls.
  get '/server-info' do
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

    resp = DMAP.build do
      mlog do
        mstt 200
        mlid sid
      end
    end
    p resp
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
          resp.to_dmap 
        }
      }
    else 
      resp = DMAP.build do
        mupd do
          mstt 200
          musr vers
        end
      end
      p resp
      body { 
        p resp if $dmap_debug
        resp.to_dmap 
      }
    end
  end

  # Once they've called update, they'll ask for the list of databases.
  get '/databases' do
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

  run! if app_file == $0

end
