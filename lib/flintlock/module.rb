require 'flintlock/metadata'
require 'flintlock/logger'
require 'flintlock/util'
require 'flintlock/runner'
require 'flintlock/storage'
require 'flintlock/error'
require 'open3'
require 'fileutils'
require 'logger'
require 'shellwords'
require 'uri'
require 'tmpdir'
require 'tempfile'
require 'open-uri'
require 'yaml'
require 'fileutils'

module Flintlock
  class Module
    attr_reader :uri, :metadata, :root_dir

    def initialize(uri = nil, options={})
      # track temporary files and directories for deletion
      @tmpfiles = []

      # destroy tmp files on exit 
      at_exit { handle_exit }

      @options = options
      @uri = uri || Dir.pwd

      # use base runner initially for downloading the module
      @runner = Runner.new
    end

    def loaded?
      @loaded
    end

    def load!
      @root_dir = fetch
      @metadata = load_metadata(@root_dir)

      @detect_script = File.join(@root_dir, 'bin', 'detect')
      @prepare_script = File.join(@root_dir, 'bin', 'prepare')
      @defaults_script = File.join(@root_dir, 'bin', 'defaults')
      @stage_script = File.join(@root_dir, 'bin', 'stage')
      @modify_script = File.join(@root_dir, 'bin', 'modify')
      @start_script = File.join(@root_dir, 'bin', 'start')
      @stop_script = File.join(@root_dir, 'bin', 'stop')
      @status_script = File.join(@root_dir, 'bin', 'status')
      
      validate

      @loaded = true

      # module's now loaded, use env runner
      @runner = EnvRunner.new(@defaults_script)
      @loaded
    end

    def fetch
      detect_root_dir(download_from_uri(@uri))
    end

    def create_dir(app_dir)
      FileUtils.mkdir_p(app_dir)
      raise if ! Util.empty_directory?(app_dir)
    end

    def detect
      LOG.info("running detect stage: #{@detect_script}")
      @runner.run(@detect_script)
      LOG.info('completed detect stage') 
    end

    def prepare
      LOG.info("running prepare stage: #{@prepare_script}")
      @runner.run(@prepare_script)
      LOG.info('completed prepare stage') 
    end

    def stage(app_dir)
      LOG.info("running stage stage: #{@stage_script}")
      module_stage(app_dir) # run internal staging procedures first
      # now run user staging procedures
      @runner.run(@stage_script, app_dir)
      # generated manifest based on staged files
      app = Application.new(app_dir, @options)
      app.initialize_manifest
      LOG.info('completed stage stage') 
    end

    def modify(app_dir)
      LOG.info("running modify stage: #{@modify_script}")
      @runner.run(@modify_script, app_dir)
      LOG.info('completed modify stage') 
    end

    def defaults
      @runner.defaults 
    end

    def module_stage(app_dir)
      LOG.info('staging flintlock scripts') 
      bindir = File.join(app_dir, 'bin')
      FileUtils.mkdir_p(bindir)
      [@defaults_script, @start_script, @stop_script, @status_script].each do |script|
        FileUtils.cp(script, bindir, :preserve => true)
      end
    end

    def download_from_uri(uri)
      LOG.debug("downloading module from #{uri}")
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
      LOG.debug("handling file '#{filename}'")
      Util.depends_on 'tar'

      tmpdir = Dir.mktmpdir
      @tmpfiles << tmpdir

      mime = Util.mime_type(filename)
      LOG.debug("mime-type is '#{mime}'")

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

    def create_deployment(app_dir)
      Deployment.new(self, app_dir, @options)
    end
    
    def full_name
      @metadata.full_name
    end

    def package_name
      @metadata.package_name
    end

    def self.stages
      ['detect', 'prepare', 'stage', 'start', 'modify', 'status']
    end

    def self.script_names
      ['defaults', *Module.stages, 'stop']
    end

    def errors
      errors = Array.new
      errors << "invalid metadata" if ! @metadata.valid?
      Module.script_names.each do |script|
        errors << "missing script '#{script}'" if ! File.file?(File.join(@root_dir, 'bin', script))
      end
      errors
    end

    def detect_root_dir(directory)
      contents = Dir[File.join(directory, '*')] 
      if contents.length == 1 && File.directory?(contents[0])
        contents[0]
      else
        directory
      end
    end

    def self.package(directory, options={})
      Util.depends_on 'tar'

      mod = Module.new(directory, options)
      mod.load!
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

    def validate
      LOG.debug('validating module')
      e = errors
      if ! e.empty?
        e.each { |error| LOG.error(error) }
        raise InvalidModule.new(@uri)
      end
    end

    def load_metadata(root_dir)
      LOG.debug('loading module metadata')
      begin
        Metadata.new(File.join(root_dir, Metadata.filename)) 
      rescue Errno::ENOENT
        raise InvalidModule, uri
      end
    end
  end
end
