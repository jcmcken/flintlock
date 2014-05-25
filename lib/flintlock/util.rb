module Flintlock
  class Util
    def self.empty_directory?(directory)
      Dir[File.join(directory, '*')].empty?
    end
  end
end
