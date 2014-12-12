require 'thor'
require 'flintlock/module'
require 'flintlock/version'
require 'flintlock/application'

module Flintlock
  class Cli < Thor
    include Thor::Actions

    method_option :debug, :type => :boolean, :desc => "Enable debug output", :default => false
    def initialize(*args)
      super
      LOG.unsilence! if options[:debug]
    end

    desc "deploy MODULE DIRECTORY", "Deploy a flintlock module MODULE to DIRECTORY"
    method_option :halt, :type => :string, :banner => 'STAGE', 
                  :desc => "Halt after STAGE", :enum => ['fetch', 'detect', 'prepare', 'stage', 'start', 'modify']
    def deploy(uri, app_dir)
      app_dir = File.expand_path(app_dir)
      say_status "run", "fetching module", :magenta
      mod = Flintlock::Module.new(uri, options)
      handle_exception { mod.load! }

      return if options[:halt] == 'fetch'

      begin
        say_status "run", "detecting compatibility", :magenta
        mod.detect
        return if options[:halt] == 'detect'

        say_status "info", "deploying #{mod.full_name} to '#{app_dir}'", :blue
        say_status "create", "creating deploy directory"
        mod.create_dir(app_dir) rescue abort("deploy directory is not empty")
        say_status "run", "installing and configuring dependencies", :magenta
        mod.prepare
        return if options[:halt] == 'prepare'

        say_status "create", "staging application files"
        mod.stage(app_dir)
        return if options[:halt] == 'stage'

        app = Application.new(app_dir, options)

        say_status "run", "launching the application", :magenta
        app.start
        return if options[:halt] == 'start'

        say_status "run", "altering application runtime environment", :magenta
        mod.modify(app.dir)
        return if options[:halt] == 'modify'

        say_status "run", "verifying the app is still up", :magenta
        abort('app crashed!') if ! app.status

        say_status "info", "complete!", :blue
      rescue Errno::EACCES => e
        abort("#{e.message.gsub(/Permission denied/, 'permission denied')}")
      rescue RunFailure
        abort('stage failed!')
      end
    end

    desc "new [DIRECTORY]", "Generate a new, minimal flintlock module"
    def new(directory = Dir.pwd)
      abort("directory isn't empty!") if ! Util.empty_directory?(directory)
      inside(directory) do
        empty_directory "bin"
        inside("bin") do
          Module.script_names.each do |script|
            create_file script
            chmod script, 0755, :verbose => false
          end
        end 
        create_file(Metadata.filename, Metadata.empty)
      end
    end

    desc "start [DIRECTORY]", "Start the application at DIRECTORY"
    def start(directory = Dir.pwd)
      check_app(directory)
      
      app = Application.new(directory, options)
      app.start
    end

    desc "stop [DIRECTORY]", "Stop the application at DIRECTORY"
    def stop(directory = Dir.pwd)
      check_app(directory)
      
      app = Application.new(directory, options)
      app.stop
    end

    desc "restart [DIRECTORY]", "Restart the application at DIRECTORY"
    def restart(directory = Dir.pwd)
      check_app(directory)
      
      app = Application.new(directory, options)
      abort('failed to restart app') if ! app.restart
    end

    desc "status [DIRECTORY]", "Determine whether the application at DIRECTORY is running"
    def status(directory = Dir.pwd)
      check_app(directory)
      
      app = Application.new(directory, options)
      if app.status
        puts 'running'
      else
        puts 'stopped'
        exit 1
      end 
    end

    desc "diff [DIRECTORY]", "Verify the integrity of the application deployed to DIRECTORY"
    def diff(directory = Dir.pwd)
      check_app(directory)
      
      app = Application.new(directory, options)
      diff = app.diff 
      if ! diff.empty?
        puts diff
        exit 1
      end
    end

    desc "package [DIRECTORY]", "Package up the given module directory"
    def package(directory = Dir.pwd)
      handle_exception { Module.package(directory, options.dup) }
    end

    desc "defaults MODULE", "Print the default configuration settings for MODULE"
    def defaults(uri)
      mod = Flintlock::Module.new(uri, options) 
      handle_exception { mod.load! }
      mod.defaults.each do |k,v|
        puts "#{k}=#{v}"
      end
    end

    desc "gc", "Perform garbage collection"
    def gc
      storage = Storage.new
      storage.gc
    end
    
    desc "destroy [DIRECTORY]", "Stop and destroy the application at DIRECTORY"
    def destroy(directory = Dir.pwd)
      check_app(directory)
      app = Application.new(directory, options)
      app.destroy
    end

    desc "version", "Print version information"
    def version
      puts Flintlock::VERSION
    end

    private

    def check_app(directory)
      dir = File.expand_path(directory)
      if ! Application.is_app?(dir, options)
        abort("'#{dir}' doesn't look like a valid flintlock deployment") 
      end
    end

    def handle_exception(&block)
      begin
        result = block.call
      rescue InvalidModule => e
        abort("invalid flintlock module '#{e}'")
      rescue UnsupportedModuleURI => e
        abort("don't know how to download '#{e}'!")
      rescue ModuleDownloadError => e
        abort("failed to download '#{e}'")
      rescue DependencyError => e
        abort("missing dependency: no such command '#{e}'")
      rescue Interrupt
        abort("interrupted by user")
      rescue PackagingError
        abort("packaging failed!")
      end
      result
    end

    def error(message)
      say_status "error", message, :red
    end

    def abort(message)
      error(message)
      exit(1)
    end
  end
end
