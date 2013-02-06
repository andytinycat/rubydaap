module Rubydaap
  module Support
    def tag(sym, var)
      DMAP::Tag.new(sym, var)
    end
  end
end
