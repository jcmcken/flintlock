require 'flintlock/metadata'
require 'flintlock/logger'
require 'open3'
require 'fileutils'
require 'logger'
require 'shellwords'

module Flintlock
  class InvalidModule < RuntimeError; end
  class Module
    attr_reader :root_dir, :metadata

    def initialize(root_dir = nil, options={})
      @debug = !!options[:debug]
      @root_dir = root_dir || Dir.pwd
      @metadata = Metadata.new(File.join(@root_dir, Metadata.filename))
      @log = Logger.new(STDOUT)

      @log.silence! if ! @debug

      script_names.map do |x|
        instance_variable_set("@#{x}_script".to_sym, File.join(@root_dir, 'bin', x))
      end

      raise InvalidModule.new(root_dir) if ! valid?

      @env = default_env
      @log.debug("defaults script is #{@defaults_script}")
      @log.debug("env is #{@env.inspect}")
    end

    def full_name
      @metadata.full_name
    end

    def script_names
      ['defaults', 'modify', 'prepare', 'stage', 'start', 'stop']
    end

    def scripts
      [@modify_script, @prepare_script, @stage_script, @start_script, @stop_script, @defaults_script]
    end

    def scripts_exist?
      scripts.map { |x| File.file?(x) }.all?
    end

    def valid?
      @metadata.valid?
      scripts_exist?
    end

    def prepare
      @log.debug("running prepare stage: #{@prepare_script}")
      run_script(@prepare_script)
    end

    def stage(app_dir)
      @log.debug("running stage stage: #{@stage_script}")
      run_script(@stage_script, app_dir)
    end
    
    def modify(app_dir)
      @log.debug("running modify stage: #{@modify_script}")
      run_script(@modify_script, app_dir)
    end
  
    def start(app_dir)
      @log.debug("running start stage: #{@start_script}")
      run_script(@start_script, app_dir)
    end
    
    def stop(app_dir)
      @log.debug("running stop stage: #{@stop_script}")
      run_script(@stop_script, app_dir)
    end

    def deploy(app_dir)
      create_app_dir(app_dir)
      prepare
      stage(app_dir)
      start(app_dir)
      modify(app_dir)
    end

    def default_env
      # hokey, but seems to work
      env_data = %x{set -a && source #{@defaults_script} && env}.split.map{ |x| x.split('=', 2) }
      Hash[env_data]
    end

    def create_app_dir(app_dir)
      FileUtils.mkdir_p(app_dir)
      raise if ! Dir[File.join(app_dir, '*')].empty?
    end

    private

    def run(command)
      handle_run(*Open3.capture3(@env, command))
    end

    def run_script(script, *args)
      run(Shellwords.join([script, *args]))
    end

    def handle_run(stdout, stderr, status)
      case status.exitstatus
      when 0
        stdout.lines.each { |x| @log.debug(x) }
      when 1
        puts stderr
        raise 'script error'
      else
        puts stderr
        raise 'internal error'
      end
    end
  end
end
