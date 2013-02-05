class Scanner
  include Logging
  include Mongo

  def initialize(*paths)
    @storage = MongoClient.new("localhost", 27017).db("rubydaap").collection("tracks")
    @watch_paths = Array.new.push(*paths)

    @watch_paths.each do |watch_path|
      Find.find(watch_path) do |path|
        if FileTest.directory?(path)
          next
        else
          if File.extname(path) == ".m4a"
            track = Track.new(:path => path)
            begin
              # Make sure we haven't already added it
              if @storage.find("_id" => track._id).to_a.length == 0
                logger.warn "Added track with details: #{track.to_json}"
                @storage.insert(track.to_json)
              end
            rescue Mongo::OperationFailure => e
              logger.error "Failed to store track in DB: #{e.message}"
            end 
          end
        end
      end
    end
  end

  def run
  end

end
