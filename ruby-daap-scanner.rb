#!/usr/bin/env ruby

# File scanner for ruby-daap

require 'rubygems'
require 'bundler/setup'
require 'mongo'
require 'optparse'
require 'mp4info'
require 'find'
require 'logger'
require 'pp'
require_relative 'rubydaap/logging'
require_relative 'rubydaap/track'
require_relative 'rubydaap/scanner'

Scanner.new("/Users/andy/musictest")

tracks = Track.get_all.map {|track| track.to_dmap}
pp tracks

test = DMAP::Tag.new(:apso, [
    DMAP::Tag.new(:mstt, 200),
    DMAP::Tag.new(:muty, 0),
    DMAP::Tag.new(:mtco, tracks.length),
    DMAP::Tag.new(:mrco, tracks.length),
    DMAP::Tag.new(:mlcl, 
      tracks
    )
])

