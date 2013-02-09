require 'mp4info'
require 'dmap'
require 'mongo_sequence'

MongoSequence.database = Mongo::Connection.new.db("rubydaap")

class Track
  include Mongo

  def self.count
    storage = MongoClient.new("localhost", 27017).db("rubydaap").collection("tracks")
    storage.count
  end

  def self.get
    storage = MongoClient.new("localhost", 27017).db("rubydaap").collection("tracks")    
    tracks = Array.new
    storage.find().to_a.each {|bson| tracks << Track.new(:hash => bson)}
    if block_given?
      tracks.each_with_index.map {|track,i| yield track, i}
    else
      tracks
    end
  end

  def self.get_by_itunes_id(itunes_id)
    storage = MongoClient.new("localhost", 27017).db("rubydaap").collection("tracks")
    Track.new( :hash => storage.find({:itunes_id => itunes_id}).to_a.first )
  end

  def self.get_all_dmap
    self.get{|track,i| track.to_dmap(i)}
  end

  def self.get_all_short_dmap
    self.get{|track,i| track.to_short_dmap(i)}
  end

  def initialize(args)

    if args.has_key? :path

      @info = Hash.new
      @path = args[:path]

      track_type = select_track_type(@path)
      if track_type == nil
        raise "Not a valid filetype: #{@path}"
      end

      if track_type == nil
        return nil
      end

      file = track_type.file

      track_type.lookup_table.each_pair do |key, value|

        if value.is_a? Proc
          @info[key] = value.call(file)
          next
        end

        @info[key] = file.send(value)
      end

    elsif args.has_key? :hash
      # Keys returned from MongoDB are strings, not symbols; we need them
      # to be symbols for the above lookup table to work.
      @info = Hash.new
      from_mongo = args[:hash] 
      from_mongo.each_pair do |key, value|
        @info[key.to_sym] = value
      end
    end

  end

  def method_missing(sym, *args)
    if @info.has_key?(sym)
      @info[sym] || ""
    else
      raise "Metadata field '#{sym.to_s}' not found"
    end
  end

  def to_json
    @info
  end

  def to_dmap(id)
    DMAP::Tag.new(:mlit,
      [
        DMAP::Tag.new(:mikd, 2),
        DMAP::Tag.new(:miid, self.itunes_id),
        DMAP::Tag.new(:minm, self.title.unpack("a*")[0]),
        DMAP::Tag.new(:mper, self.itunes_id),
        DMAP::Tag.new(:asal, self.album.unpack("a*")[0]),
        DMAP::Tag.new(:agrp, ""),
        DMAP::Tag.new(:asar, self.artist.unpack("a*")[0]),
        DMAP::Tag.new(:asbr, self.bitrate),
        DMAP::Tag.new(:asbt, 0),
        DMAP::Tag.new(:ascm, ""),
        DMAP::Tag.new(:asco, 0),
        DMAP::Tag.new(:ascp, self.author),
        DMAP::Tag.new(:asda, Time.new.to_i),
        DMAP::Tag.new(:asdm, Time.new.to_i),
        DMAP::Tag.new(:asdc, 0),
        DMAP::Tag.new(:asdn, 0),
        DMAP::Tag.new(:asdb, 0),
        DMAP::Tag.new(:aseq, ""),
        DMAP::Tag.new(:asfm, self.filetype),
        DMAP::Tag.new(:asgn, self.genre.unpack("a*")[0]),
        DMAP::Tag.new(:asdt, ""),
        DMAP::Tag.new(:asrv, 0),
        DMAP::Tag.new(:assr, 0),
        DMAP::Tag.new(:assz, self.bytes),
        DMAP::Tag.new(:asst, 0),
        DMAP::Tag.new(:assp, 0),
        DMAP::Tag.new(:astm, self.total_seconds * 1000),
        DMAP::Tag.new(:astc, self.track_total),
        DMAP::Tag.new(:astn, self.track_number),
        DMAP::Tag.new(:asur, 0),
        DMAP::Tag.new(:asyr, self.year),
        DMAP::Tag.new(:asdk, 0),
        DMAP::Tag.new(:asul, "")
      ]
    )
  end 

  def to_short_dmap(id)
    DMAP::Tag.new(:mlit,
      [
        DMAP::Tag.new(:mikd, 2),
        DMAP::Tag.new(:asdk, 0),
        DMAP::Tag.new(:miid, self.itunes_id),
        DMAP::Tag.new(:mcti, self.itunes_id),
        DMAP::Tag.new(:minm, self.title.encode('US-ASCII', {:undef => :replace}))
      ]
    )
  end

  def select_track_type(path)
    puts TrackTypes.constants
    TrackTypes.constants.each do |track_type|
      klass = TrackTypes.const_get(track_type)
      puts "Path: #{path}"
      if klass.can_handle?(path)
        thing = klass.new(path)
        puts "Thing class: #{thing.class}"
        return thing
      end
    end
    nil
  end

end
