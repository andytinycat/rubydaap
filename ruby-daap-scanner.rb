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
require_relative 'lib/rubydaap/logging'
require_relative 'lib/rubydaap/track'
require_relative 'lib/rubydaap/scanner'

Scanner.new("/Users/andy/musictest")

tracks = Track.get_all
p tracks
