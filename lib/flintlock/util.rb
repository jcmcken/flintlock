module Flintlock
  class Util
    def self.empty_directory?(directory)
      Dir[File.join(directory, '*')].empty?
    end
  
    def self.supported_archives
      ['.tar.gz', '.tar']
    end
  
    def self.supported_archive?(filename)
      Module.supported_archives.contains?(full_extname(filename))
    end
  
    def self.full_extname(filename)
      data = []
      current_filename = filename.dup
      while true
        ext = File.extname(current_filename)
        break if ext.empty?
        current_filename = current_filename.gsub(/#{ext}$/, '')
        data << ext
      end
      data.reverse.join
    end
  end
end
