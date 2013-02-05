require 'mp4info'
require 'dmap'

class Track
  include Mongo

  def Track.get_all
    storage  = MongoClient.new("localhost", 27017).db("rubydaap").collection("tracks")    
    tracks = Array.new
    storage.find().to_a.each {|bson| tracks << Track.new(:hash => bson)}
    tracks.each_with_index.map {|track,i| track.to_dmap(i+1)}
  end

  def Track.get_all_playlist
    storage  = MongoClient.new("localhost", 27017).db("rubydaap").collection("tracks")    
    tracks = Array.new
    storage.find().to_a.each {|bson| tracks << Track.new(:hash => bson)}
    tracks.each_with_index.map {|track,i| track.to_short_dmap(i+1)}
  end

  def initialize(args)

    if args.has_key? :path

      @info = Hash.new
      @path = args[:path]
      @file = MP4Info.open(@path)
      lookup_table = Hash[*%w(
        album                   ALB
        apple_store_id          APID          
        artist                  ART           
        comment                 CMT           
        compilation             CPIL          
        copyright               CPRT          
        year                    DAY           
        disk_number_and_total   DISK          
        genre                   GNRE          
        grouping                GRP           
        title                   NAM           
        rating                  RTNG          
        tempo                   TMPO          
        encoder                 TOO           
        track_number_and_total  TRKN          
        track_number            TRKN
        track_total             TRKN
        author                  WRT           
        mpeg_version            VERSION       
        layer                   LAYER         
        bitrate                 BITRATE       
        frequency               FREQUENCY     
        bytes                   SIZE          
        total_seconds           SECS          
        minutes                 MM            
        seconds                 SS            
        milliseconds            MS            
        formatted_time          TIME          
        copyright               COPYRIGHT     
        encrypted               ENCRYPTED
        _id                     ID
      )]

      lookup_table.each_pair do |key, value|
    
        if key == "track_number"
          @info[key] = @file.send(value.to_sym)[0]
          next
        end

        if key == "track_total"
          @info[key] = @file.send(value.to_sym)[1]
          next
        end

        if key == "_id"
          @info[key] = Digest::MD5.file(@path).hexdigest
          next
        end

        @info[key] = @file.send(value.to_sym)
      end

    elsif args.has_key? :hash
      @info = args[:hash] 
    end

  end

  def method_missing(sym, *args)
    if @info.has_key?(sym.to_s)
      @info[sym.to_s] || ""
    else
      raise "Metadata field '#{sym.to_s}' not found"
    end
  end

  def to_json
    json = {}
    @info.each_pair do |key, value|
      json[key] = self.send(key.to_sym)
    end
    json["_id"] = self._id
    json
  end

  def to_dmap(id)
    puts id
    DMAP::Tag.new(:mlit,
      [
        DMAP::Tag.new(:mikd, 2),
        DMAP::Tag.new(:miid, id),
        DMAP::Tag.new(:minm, self.title),
        DMAP::Tag.new(:mper, id),
        DMAP::Tag.new(:asal, self.album),
        DMAP::Tag.new(:agrp, ""),
        DMAP::Tag.new(:asar, self.artist),
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
        DMAP::Tag.new(:asfm, "mp3"),
        DMAP::Tag.new(:asgn, self.genre),
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
        DMAP::Tag.new(:miid, id),
        DMAP::Tag.new(:mcti, 1),
        DMAP::Tag.new(:minm, self.title)
      ]
    )
  end

end
