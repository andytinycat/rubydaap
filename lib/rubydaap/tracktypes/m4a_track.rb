module TrackTypes
  class M4ATrack < ::Track

    attr_reader :file

    def initialize(path)
      @path = path
      @file = MP4Info.open(path)
    end

    def self.can_handle?(path)
      return true if File.extname(path) =~ /m4a/
    end

    def lookup_table
      {
        album:                   :ALB,
        artist:                  :ART,
        year:                    :DAY,
        genre:                   :GNRE,
        title:                   :NAM,
        track_number:            Proc.new {|file| file.TRKN ? file.TRKN[0] : ""},
        track_total:             Proc.new {|file| file.TRKN ? file.TRKN[0] : ""},
        author:                  :WRT,
        bitrate:                 :BITRATE,
        bytes:                   :SIZE,
        total_seconds:           :SECS,
        _id:                     Proc.new {Digest::MD5.file(@path).hexdigest},
        itunes_id:               Proc.new {MongoSequence[:global].next},
        path:                    Proc.new {@path},
        filetype:                Proc.new {"m4a"}
      }
    end

    def close
      # noop
    end

  end
end
