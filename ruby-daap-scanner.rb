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
require 'taglib'
require_relative 'lib/rubydaap/logging'
require_relative 'lib/rubydaap/track'
require_relative 'lib/rubydaap/scanner'
require_relative 'lib/rubydaap/tracktypes/m4a_track.rb'
require_relative 'lib/rubydaap/tracktypes/mp3_track.rb'

Scanner.new("/Users/andy/Music")

tracks = Track.get_all_dmap
p tracks
