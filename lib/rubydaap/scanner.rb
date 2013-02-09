class Scanner
  include Mongo

  require 'pp'
  def initialize(paths)
    @watch_paths = paths
    pp @watch_paths

    $log.info("Scanner watching paths: #{@watch_paths.join(", ")}")

    @watch_paths.each do |watch_path|
      Find.find(watch_path) do |path|
        Find.prune if path =~ /^.AppleDouble/
        Find.prune if path =~ /^\._/
        add_track(path)
      end
    end
  end

  def run
    @watch_paths.each do |path|
      listener = Listen.to(path)
      callback = Proc.new do |modified,added,removed| 
        if added.size > 0
          $log.info("New file(s) detected: #{added.join(", ")}")
          added.each {|file| add_track(file)}
        end
        if removed.size > 0
          $log.info("File(s) deleted: #{removed.join(", ")}")
          removed.each {|file| remove_track(file)}
        end
        invalidate_cache()
      end
      listener.change(&callback)
      listener.start(false) # doesn't block execution
    end
  end 

  def add_track(path)
    return if FileTest.directory?(path)
    begin
      track = Track.new(:path => path)
      # Make sure we haven't already added it
      if $db.find("_id" => track._id).to_a.length == 0
        $log.info("Adding file: #{path}; artist: #{track.artist} title #{track.title} album #{track.album}")
        $db.insert(track.to_json)
      end
    rescue RuntimeError => e
      $log.info("File not recognised by any TrackType: #{path}")
    end 
  end

  def remove_track(path)
    return if FileTest.directory?(path)
    $db.remove("path" => path)
  end

  def invalidate_cache
    DMAPCache.instance.tracks = nil
    DMAPCache.instance.playlist_items = nil
  end

end
