module TrackTypes
  class MP3Track < Track

    attr_reader :file

    def initialize(path)
      @path = path
      @file = TagLib::MPEG::File.new(path)
    end

    def self.can_handle?(path)
      return true if File.extname(path) =~ /mp3/
    end

    def lookup_table
      {
        album:                   Proc.new {|file| file.tag.album},
        artist:                  Proc.new {|file| file.tag.artist},
        year:                    Proc.new {|file| file.tag.year},
        genre:                   Proc.new {|file| file.tag.genre},
        title:                   Proc.new {|file| file.tag.title},
        track_number:            Proc.new {|file| 
                                            tag = file.id3v2_tag.frame_list('TRCK').first.to_s
                                            if tag =~ /(\d+)\/(\d+)/
                                              $1
                                            else
                                              tag
                                            end
                                          },
        track_total:             Proc.new {|file| file.id3v2_tag.frame_list('TRCK').first.to_s
                                            tag = file.id3v2_tag.frame_list('TRCK').first.to_s
                                            if tag =~ /(\d+)\/(\d+)/
                                              $2
                                            else
                                              tag
                                            end
                                          },
        author:                  Proc.new {|file| file.id3v2_tag.frame_list('TCOM').first.to_s},
        bitrate:                 Proc.new {|file| file.audio_properties.bitrate},
        bytes:                   Proc.new {|file| File.size(@path)},
        total_seconds:           Proc.new {|file| file.audio_properties.length},
        _id:                     Proc.new {Digest::MD5.file(@path).hexdigest},
        itunes_id:               Proc.new {MongoSequence[:global].next},
        path:                    Proc.new {@path},
        filetype:                Proc.new {"mp3"}
      }
    end

  end
end
