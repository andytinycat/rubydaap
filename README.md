rubydaap
========

This will eventually be a full-featured DAAP (iTunes music sharing)
server written in Ruby. It's written as a Sinatra app, with Thin as
the Rack webserver. Tracks are stored in MongoDB; there's no
real need for a relational database since the DAAP protocol doesn't
really require us to consider track->album relationships.

Right now, it's just a mockup for the future app.
