require 'flintlock/storage'
require 'flintlock/util'
require 'fileutils'

module Flintlock
  class Application
    attr_reader :dir, :defaults_script, :start_script, :status_script, :stop_script

    def initialize(dir, options = {})
      @dir = File.expand_path(dir)

      @defaults_script = File.join(@dir, 'bin', 'defaults')
      @start_script = File.join(@dir, 'bin', 'start')
      @status_script = File.join(@dir, 'bin', 'status')
      @stop_script = File.join(@dir, 'bin', 'stop')

      @runner = EnvRunner.new(@defaults_script)
      @storage = Storage.new

      @manifest = nil

      load_manifest! if has_manifest?
    end

    def errors
      errors = []
      errors << "missing application manifest" if ! has_manifest?
      [@defaults_script, @start_script, @status_script, @stop_script].each do |script|
        errors << "missing script '#{script}'" if ! File.file?(script)
      end
      errors.each { |e| LOG.error(e) }
      errors
    end

    def self.is_app?(dir, options = {})
      app = Application.new(dir, options)
      app.has_manifest?
    end

    def manifest_file
      File.join(@dir, '.manifest.yml')
    end

    def has_manifest?
      File.file?(manifest_file)
    end

    def loaded?
      ! @manifest.nil?
    end

    def compute_manifest(options = {})
      store = !!options[:store] # don't store by default
      raw = @storage.add_dir(@dir, :dryrun => !store)
      raw.keys.each do |k|
        raw[Util.relative_file(k, dir)] = raw.delete(k)
      end
      raw
    end

    def load_manifest!
      @manifest = YAML.load_file(manifest_file)
    end

    def initialize_manifest
      # compute manifest, storing the checked files in the CAS
      @manifest = compute_manifest(:store => true)
      # now write the manifest to the app dir
      write_manifest
    end

    def write_manifest
      fd = File.open(manifest_file, 'w')
      fd.write(YAML.dump(@manifest))
      fd.close
    end

    def diff
      data = ""
      @manifest.each do |k,v|
        newpath = File.join(@dir, k)
        oldpath = @storage.fullpath(v)
        LOG.debug("diffing old '#{oldpath}' and new '#{newpath}'")
        data << Util.diff(oldpath, newpath) 
      end
      data
    end

    def verified?
      current = compute_manifest
      @manifest.each do |k,v|
        return false if current[k] != v
      end 
      true
    end

    def start
      LOG.info("starting app: #{@start_script}")
      @runner.run(@start_script)
    end

    def stop
      LOG.info("stopping app: #{@stop_script}")
      @runner.run(@stop_script)
    end

    def status
      LOG.info("running status: #{@status_script}")
      begin
        @runner.run(@status_script)
        true
      rescue RunFailure
        false
      end
    end

    def restart
      LOG.info('executing application restart')
      stop if status
      return false if status # still running! just bomb out
      start
      status
    end

    def unsafe_clean
      LOG.debug('cleaning application artifacts')
      # first, remove the manifest file to render this application unusable
      FileUtils.rm([manifest_file], :force => true)

      # now remove all associated files from the CAS
      @manifest.each do |filename,checksum|
        @storage.clean(checksum)
      end
    end

    def clean
      begin
        unsafe_clean
        true
      rescue
        false
      end    
    end

    def destroy
      LOG.debug('preparing to destroy application')
      stop if status
      return false if status
      LOG.debug('removing all application files')
      FileUtils.rm_rf(@dir)
      clean
      LOG.debug('successfully destroyed application')
    end
  end
end
