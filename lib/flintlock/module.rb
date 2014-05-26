require 'flintlock/metadata'
require 'flintlock/logger'
require 'flintlock/util'
require 'open3'
require 'fileutils'
require 'logger'
require 'shellwords'
require 'uri'

module Flintlock
  class InvalidModule < RuntimeError; end
  class UnsupportedModuleURI < RuntimeError; end
  class ModuleDownloadError < RuntimeError; end
  class RunFailure < RuntimeError; end

  class Module
    attr_reader :uri, :metadata

    def initialize(uri = nil, options={})
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
      case URI.parse(uri).scheme
      when nil # no scheme == local file
        uri
      when 'git'
        handle_git_uri(uri)
      else
        raise UnsupportedModuleURI, uri
      end
    end

    def handle_git_uri(uri)
      root_dir = Dir.mktmpdir
      command = Shellwords.join(['git', 'clone', uri, root_dir])
      stdout, stderr, status = Open3.capture3(command)
      raise ModuleDownloadError, uri if status.exitstatus != 0 
      root_dir
    end
    
    def full_name
      @metadata.full_name
    end

    def self.script_names
      ['defaults', 'modify', 'prepare', 'stage', 'start', 'stop']
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

    def load_env(defaults_script)
      # hokey, but seems to work
      env_data = %x{set -a && source #{defaults_script} && env}.split.map{ |x| x.split('=', 2) }
      env = Hash[env_data]
      @log.debug("defaults script is #{defaults_script}")
      @log.debug("env is #{env.inspect}")
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

    def run_script(script, *args)
      run(Shellwords.join([script, *args]))
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
