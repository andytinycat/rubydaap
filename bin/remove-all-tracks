#!/usr/bin/env ruby
require 'mongo'
include Mongo

storage = MongoClient.new("localhost", 27017).db("rubydaap").collection("tracks")
storage.remove()
