require 'flintlock/metadata'
require 'flintlock/logger'
require 'flintlock/util'
require 'open3'
require 'fileutils'
require 'logger'
require 'shellwords'
require 'uri'
require 'tmpdir'
require 'tempfile'
require 'open-uri'

module Flintlock
  class InvalidModule < RuntimeError; end
  class UnsupportedModuleURI < RuntimeError; end
  class ModuleDownloadError < RuntimeError; end
  class RunFailure < RuntimeError; end
  class DependencyError < RuntimeError; end

  class Module
    attr_reader :uri, :metadata

    def initialize(uri = nil, options={})
      # track temporary files and directories for deletion
      @tmpfiles = []
     
      # destroy tmp files on exit 
      at_exit { handle_exit }

      @debug = !!options[:debug]
      @uri = uri || Dir.pwd
      @log = load_logger
      @root_dir = download_from_uri(@uri)
      @metadata = load_metadata

      load_scripts!
      validate

      @env = load_env(@defaults_script)

    end

    def download_from_uri(uri)
      case URI.parse(uri).scheme.split('+', 0)[0]
      when nil, 'file' # no scheme == local file
        if Util.supported_archive?(uri)
          handle_archive(uri)
        else
          uri
        end
      when 'git'
        handle_git_uri(uri)
      when 'http', 'https'
        raise UnsupportedModuleURI.new(uri) if ! Util.supported_archive?(uri)
        # over these protocols, we're getting an archive
        handle_archive(handle_http_uri(uri))
      else
        raise UnsupportedModuleURI, uri
      end
    end

    def handle_exit
      @tmpfiles.each { |x| FileUtils.rm_rf(x, :secure => true) }
    end

    def handle_git_uri(uri)
      raise DependencyError.new('git') if Util.which('git').nil?
      root_dir = Dir.mktmpdir
      @tmpfiles << root_dir
      command = Shellwords.join(['git', 'clone', uri, root_dir])
      stdout, stderr, status = Open3.capture3(command)
      raise ModuleDownloadError, uri if status.exitstatus != 0 
      root_dir
    end

    def handle_http_uri(uri, buffer=8192)
      tmpfile = Tempfile.new(['flintlock', Util.full_extname(uri)]).path
      @tmpfiles << tmpfile
      open(uri) do |input|
        open(tmpfile, 'wb') do |output|
          while ( buf = input.read(buffer))
            output.write buf
          end
        end
      end
      tmpfile
    rescue OpenURI::HTTPError
      raise ModuleDownloadError, uri
    end

    def handle_archive(filename)
      tmpdir = Dir.mktmpdir
      @tmpfiles << tmpdir
      case filename
      when /\.tar\.gz$/
        command = ['tar', 'xfz', filename, '-C', tmpdir]
      when /\.tar$/
        command = ['tar', 'xf', filename, '-C', tmpdir]
      else
        raise UnsupportedModuleURI, filename
      end
      _, _, status = Open3.capture3(Shellwords.join(command))
      raise ModuleDownloadError if status.exitstatus != 0
      tmpdir
    end

    def full_name
      @metadata.full_name
    end

    def self.stages
      ['prepare', 'stage', 'start', 'modify']
    end

    def self.script_names
      ['defaults', *Module.stages, 'stop']
    end

    def scripts
      [@modify_script, @prepare_script, @stage_script, @start_script, @stop_script, @defaults_script]
    end

    def scripts_exist?
      scripts.map { |x| File.file?(x) }.all?
    end

    def valid?
      @metadata.valid? && scripts_exist?
    end

    def prepare
      @log.info("running prepare stage: #{@prepare_script}")
      run_script(@prepare_script)
    end

    def stage(app_dir)
      @log.info("running stage stage: #{@stage_script}")
      run_script(@stage_script, app_dir)
    end
    
    def modify(app_dir)
      @log.info("running modify stage: #{@modify_script}")
      run_script(@modify_script, app_dir)
    end
  
    def start(app_dir)
      @log.info("running start stage: #{@start_script}")
      run_script(@start_script, app_dir)
    end
    
    def stop(app_dir)
      @log.info("running stop stage: #{@stop_script}")
      run_script(@stop_script, app_dir)
    end

    def current_env
      Hash[ENV.to_a] # get rid of ENV obj
    end

    def load_env(defaults_script)
      # hokey, but seems to work
      env_data = %x{set -a && source #{defaults_script} && env}.split.map{ |x| x.split('=', 2) }
      env = Hash[env_data]
      @log.debug("defaults script is #{defaults_script}")
      @log.debug("defaults env is #{env.inspect}")
      env = env.merge(current_env)
      @log.debug("merged env is #{env.inspect}")
      env
    end

    def create_app_dir(app_dir)
      FileUtils.mkdir_p(app_dir)
      raise if ! Util.empty_directory?(app_dir)
    end

    private

    def load_scripts!
      Module.script_names.map do |x|
        instance_variable_set("@#{x}_script".to_sym, File.join(@root_dir, 'bin', x))
      end
    end

    def validate
      raise InvalidModule.new(@uri) if ! valid?
    end

    def load_logger
      log = Logger.new(STDOUT)
      log.silence! if ! @debug
      log
    end

    def load_metadata
      begin
        Metadata.new(File.join(@root_dir, Metadata.filename)) 
      rescue Errno::ENOENT
        raise InvalidModule, uri
      end
    end

    def run(command)
      handle_run(*Open3.capture3(@env, command))
    end

    def detect_runtime(script)
      raw = File.open(script, &:readline)[/^\s*#!\s*(.+)/, 1] || ""
      raw.split
    rescue EOFError
      []
    end

    def empty_script?(script)
      File.read(script).strip.empty?
    end

    def skip_script?(script)
     skip = ! File.file?(script) || empty_script?(script)
     @log.debug("skipping '#{script}'") if skip
     skip
    end

    def run_script(script, *args)
      return if skip_script?(script)
      command = Shellwords.join([*detect_runtime(script), script, *args].compact)
      @log.debug("running command: #{command}")
      run(command)
    end

    def handle_run(stdout, stderr, status)
      stdout.lines.each { |x| @log.info(x) }
      if status.exitstatus != 0
        stderr.lines.each { |x| @log.error(x) }
        raise RunFailure
      end
    end
  end
end
