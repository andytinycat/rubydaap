#!/usr/bin/env ruby

# Standalone scanner

require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
require 'logger'
require 'digest/md5'
require 'find'

require_relative 'rubydaap/track'
require_relative 'rubydaap/scanner'

Scanner.new("/Users/andy/Music")

tracks = Track.get_all_dmap
p tracks
