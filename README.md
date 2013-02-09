rubydaap
========

This will eventually be a fully-featured DAAP (iTunes music sharing)
server written in Ruby. It's written as a Sinatra app, with Thin as
the Rack webserver. Tracks are stored in MongoDB; there's no
real need for a relational database since the DAAP protocol doesn't
really require us to consider track->album relationships.

Right now it implements the basic features required of any DAAP server.
See below for the current status, and future feature enhancements.

*Note:* this has only been tested with new versions of iTunes, and
on Mac OS X. It should work on any platform, and with any DAAP client,
but all of the DAAP protocol work was done by watching what iTunes does.

Features
========

- Reads MP3 and MP4 (.m4a, m4p, etc.) files.
- Uses the superb [Listen gem](https://github.com/guard/listen) to update 
  the library when files are added or removed. Works on Mac OS X, Windows, and Linux.
- Updates clients on a configurable period when files are added/removed.
- Simple to add support for more audio file types.

Requires
========
 
Ruby dependencies
-----------------

- Ruby 1.9.x
- Bundler

Bundler will do the job of installing all the required gems.

Native dependencies
-------------------

- [taglib](http://taglib.github.com/)
- bson_ext and taglib-ruby require a compiler to build on Linux/Mac OS X

Installing
==========

Mac OS X
--------
    
1) Get the files and the gems required:

    git clone https://github.com/andytinycat/rubydaap
    cd rubydaap
    bundle install

2) Edit the config file to point to your music dirs (see Config below)

3) Start the server

    bin/start
