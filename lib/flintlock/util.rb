require 'flintlock/logger'

module Flintlock
  class DependencyError < RuntimeError; end

  class Util
    def self.empty_directory?(directory)
      Dir[File.join(directory, '*')].empty?
    end
  
    def self.full_extname(filename)
      data = []
      current_filename = filename.dup
      while true
        ext = File.extname(current_filename)
        break if ext.empty? || ext =~ /^\.\d+$/
        current_filename = current_filename.gsub(/#{ext}$/, '')
        data << ext
      end
      data.reverse.join
    end

    def self.which(command)
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exe = File.join(path, command)
        return exe if File.executable?(exe)
      end
      nil
    end

    def self.get_uri_scheme(uri)
      scheme = URI.parse(uri).scheme
      return scheme.nil? ? nil : scheme.split('+', 0)[0] 
    end

    def self.load_logger(debug = false)
      log = Logger.new(STDOUT)
      log.silence! if ! debug
      log
    end

    def self.detect_runtime(script, default="/bin/sh")
      raw = File.open(script, &:readline)[/^\s*#!\s*(.+)/, 1] || default
      raw.split
    rescue EOFError
      [default]
    end

    def self.path_split(path)
      path.split(File::SEPARATOR).select { |x| ! x.empty? }
    end

    def self.depends_on(what)
      raise DependencyError.new(what) if which(what).nil?
    end

    def self.mime_type(filename)
      depends_on 'file'
      stdout, stderr, status = Runner.new.run(['file', '--mime-type', filename], :capture => true) 
      stdout.split(':')[1].strip
    end
  end
end
