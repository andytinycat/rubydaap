#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'rack'
require 'sinatra/base'
require 'sinatra/config_file'
require 'sinatra/async'
require 'dnssd'
require 'dmap'
require 'mongo'
require 'logger'
require 'pp'

require_relative 'rubydaap/logging'
require_relative 'rubydaap/track'
require_relative 'rubydaap/scanner'

class App < Sinatra::Base
register Sinatra::Async
register Sinatra::ConfigFile

# Config file
config_file "config.yml"

# Use Thin; iTunes doesn't seem to like something
# in the way Sinatra chunks the request up.
set :server, 'thin'
set :port, Sinatra::Application.port
set :logging, true

# Hold a list of the clients already connected
clients = Array.new

# Register with Bonjour so iTunes can find us
bonjour = DNSSD.register("Test", "_daap._tcp", nil, Sinatra::Application.port) do |r|
  warn("Registered on Bonjour")
end

# Headers to send on every request
before do
  headers 'DAAP-Server' => "ruby-daap/0.1"
  content_type "application/x-dmap-tagged"
end

# This is the first thing a connecting client calls.
get '/server-info' do
  # DMAP response indicating what we support
  resp = DMAP.build do
    msrv do
      mstt 200
      mpro [0,2,0,6]
      apro [0,3,0,6]
      minm "Test"
      mslr 1
      msau 0
      mstm 1800
      msal 1
      msup 0
      mspi 1
      msex 1
      msbr 1
      msqy 1
      msix 1
      msrs 1
      msdc 1
    end
  end
  p resp
  resp.to_dmap
end

# After getting server info, the client tries to log in.
# We assign them a random session ID.
get '/login' do
  warn("Received login request from #{@env['REMOTE_ADDR']}")

  # Assign a random ID - don't allow it to collide
  sid = rand(4095)

  resp = DMAP.build do
    mlog do
      mstt 200
      mlid sid
    end
  end
  resp.to_dmap
end

# Clients will call update straight after logging in. It's stupid,
# iTunes does it even if you claim you don't support update.
aget '/update' do
  vers  = params['revision-number'].to_i
  delta = params['delta'].to_i
  puts "vers: #{vers} delta: #{delta}"
  if vers == delta
    vers = vers + 1
    resp = DMAP.build do
      mupd do
        mstt 200
        musr vers
      end
    end
    EM.add_timer(15) {
      body { resp.to_dmap }
    }
  else 
    resp = DMAP.build do
      mupd do
        mstt 200
        musr vers
      end
    end
    p resp
    body { resp.to_dmap }
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
          minm "Test"
          mimc 1
          mctc 1
        end
      end

    end
  end
  resp.to_dmap
end

# Song list
get '/databases/1/items' do
  tracks = Track.get_all.map {|track| track.to_dmap}
  resp = DMAP::Tag.new(:adbs, [
    DMAP::Tag.new(:mstt, 200),
    DMAP::Tag.new(:muty, 0),
    DMAP::Tag.new(:mtco, tracks.length),
    DMAP::Tag.new(:mrco, tracks.length),
    DMAP::Tag.new(:mlcl, 
      tracks
    )
  ])
  pp resp
  resp.to_dmap
end

# Playlist list
get '/databases/1/containers' do
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
          minm "Test"
          mimc 1
          abpl 1
        end
      end
    end
  end
  p resp
  resp.to_dmap
end

# Song list
get '/databases/1/containers/1/items' do
  tracks = Track.get_all.map {|track| track.to_short_dmap}
  resp = DMAP::Tag.new(:apso, [
    DMAP::Tag.new(:mstt, 200),
    DMAP::Tag.new(:muty, 0),
    DMAP::Tag.new(:mtco, tracks.length),
    DMAP::Tag.new(:mrco, tracks.length),
    DMAP::Tag.new(:mlcl, 
      tracks
    )
  ])
  pp resp
  resp.to_dmap


end
  run! if app_file == $0


end
