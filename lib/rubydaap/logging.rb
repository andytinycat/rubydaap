module Rubydaap
  module Logging
    def logger
      @logger ||= Logger.new(STDOUT).level = Logger::INFO
    end
  end
end
