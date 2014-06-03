require 'flintlock/metadata'
require 'flintlock/logger'
require 'flintlock/util'
require 'flintlock/runner'
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
  class PackagingError < RuntimeError; end

  class Module
    attr_reader :uri, :metadata

    def initialize(uri = nil, options={})
      # track temporary files and directories for deletion
      @tmpfiles = []

      # destroy tmp files on exit 
      at_exit { handle_exit }

      @uri = uri || Dir.pwd
      @log = Util.load_logger(!!options[:debug])
      @runner = Runner.new(options)
     
      @root_dir = detect_root_dir(download_from_uri(@uri))
      @metadata = load_metadata(@root_dir)

      load_scripts!
      validate

      @env = load_env(@defaults_script)
    end

    def download_from_uri(uri)
      case Util.get_uri_scheme(uri)
      when nil, 'file' # no scheme == local file
        handle_file(uri)
      when 'git'
        handle_git_uri(uri)
      when 'svn'
        handle_svn_uri(uri)
      when 'http', 'https'
        # over these protocols, we're getting an archive
        handle_file(handle_http_uri(uri))
      else
        raise UnsupportedModuleURI, uri
      end
    end

    def handle_exit
      @tmpfiles.each { |x| FileUtils.rm_rf(x, :secure => true) }
    end

    def handle_git_uri(uri)
      Util.depends_on 'git'

      root_dir = Dir.mktmpdir
      @tmpfiles << root_dir
      status = @runner.run(['git', 'clone', uri, root_dir])
      raise ModuleDownloadError, uri if status != 0 
      root_dir
    end

    def handle_svn_uri(uri)
      Util.depends_on 'svn'

      root_dir = Dir.mktmpdir
      @tmpfiles << root_dir
      status = @runner.run(['svn', 'checkout', uri, root_dir])
      raise ModuleDownloadError, uri if status != 0 
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
    rescue OpenURI::HTTPError, OpenSSL::SSL::SSLError
      raise ModuleDownloadError, uri
    end

    def handle_file(filename)
      @log.debug("handling file '#{filename}'")
      Util.depends_on 'tar'

      tmpdir = Dir.mktmpdir
      @tmpfiles << tmpdir

      mime = Util.mime_type(filename)
      @log.debug("mime-type is '#{mime}'")

      case mime 
      when 'application/x-directory'
        return filename
      when 'application/x-gzip'
        command = ['tar', 'xfz', filename, '-C', tmpdir]
      when 'application/x-tar'
        command = ['tar', 'xf', filename, '-C', tmpdir]
      else
        raise UnsupportedModuleURI, filename
      end
      status = @runner.run(command)
      raise ModuleDownloadError, filename if status != 0
      tmpdir
    end

    def full_name
      @metadata.full_name
    end

    def package_name
      @metadata.package_name
    end

    def self.stages
      ['detect', 'prepare', 'stage', 'start', 'modify']
    end

    def self.script_names
      ['defaults', *Module.stages, 'stop']
    end

    def scripts
      [@modify_script, @prepare_script, @stage_script, @start_script, @stop_script, @defaults_script, @detect_script]
    end

    def valid?
      @metadata.valid?
    end

    def detect
      @log.info("running detect stage: #{@detect_script}")
      run_script(@detect_script)
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
      env_data = %x{set -a && source #{defaults_script} && env}.split("\n").map{ |x| x.split('=', 2) }
      env = Hash[env_data]
      @log.debug("defaults script is #{defaults_script}")
      @log.debug("defaults env is #{env.inspect}")
      env = env.merge(current_env)
      @log.debug("merged env is #{env.inspect}")
      env
    end

    def defaults
      Hash[@env.to_a - ENV.to_a] 
    end

    def create_app_dir(app_dir)
      FileUtils.mkdir_p(app_dir)
      raise if ! Util.empty_directory?(app_dir)
    end

    def self.package(directory, options={})
      Util.depends_on 'tar'

      mod = Module.new(directory, options)
      archive = mod.package_name + '.tar.gz'

      if Util.path_split(directory).length > 1
        change_to = File.dirname(directory)
        archive_path = File.basename(directory)
      else
        change_to = '.'
        archive_path = directory
      end

      status = Runner.new(options).run(['tar', 'cfz', archive, '-C', change_to, archive_path])
      raise PackagingError.new(directory) if status != 0
      archive
    end

    private

    def load_scripts!
      Module.script_names.map do |x|
        instance_variable_set("@#{x}_script".to_sym, File.join(@root_dir, 'bin', x))
      end
    end

    def validate
      @log.debug('validating module')
      raise InvalidModule.new(@uri) if ! valid?
    end

    def load_metadata(root_dir)
      @log.debug('loading module metadata')
      begin
        Metadata.new(File.join(root_dir, Metadata.filename)) 
      rescue Errno::ENOENT
        raise InvalidModule, uri
      end
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
      command = [*Util.detect_runtime(script), script, *args].compact
      status = @runner.run(command, :env => @env)
      raise RunFailure if status != 0
    end

    def detect_root_dir(directory)
      contents = Dir[File.join(directory, '*')] 
      if contents.length == 1 && File.directory?(contents[0])
        contents[0]
      else
        directory
      end
    end
  end
end
