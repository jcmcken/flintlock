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
      stdout, stderr, status = Runner.run(['file', '--mime-type', filename], :capture => true) 
      stdout.split(':')[1].strip
    end

    def self.load_script_env(script)
      env_data = %x{set -a && source #{script} && env}.split("\n").map{ |x| x.split('=', 2) }
      env = Hash[env_data]
    end

    def self.relative_file(filename, directory)
      filename.gsub(/^#{directory}\/+/, '')
    end

    def self.diff(old_file, new_file)
      depends_on 'diff'
      # `diff' returns a non-zero exit code when a difference exists between files,
      # so don't raise on fail
      stdout, stderr, status = Runner.run(['diff', '-ruN', old_file, new_file], 
         :capture => true, :raise_on_fail => false)
      # `diff' returns `0' if no difference or `1' if there is a difference
      # otherwise, consider the command run a failure
      raise RunFailure if ! [0, 1].include?(status)
      stdout
    end

    def self.empty_script?(script)
      File.read(script).strip.empty?
    end

  end
end
