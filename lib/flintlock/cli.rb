require 'thor'
require 'flintlock/module'
require 'flintlock/version'

module Flintlock
  class Cli < Thor
    include Thor::Actions

    desc "deploy MODULE DIRECTORY", "Deploy a flintlock module MODULE to DIRECTORY"
    method_option :debug, :type => :boolean, :description => "enable debug output", :default => false
    method_option :halt, :type => :string, :banner => 'STAGE', 
                  :description => "Halt after STAGE", :enum => ['fetch', 'detect', 'prepare', 'stage', 'start', 'modify']
    def deploy(uri, app_dir)
      app_dir = File.expand_path(app_dir)
      say_status "run", "fetching module", :magenta
      mod = get_module(uri, options)
      return if options[:halt] == 'fetch'

      begin
        say_status "run", "detecting compatibility", :magenta
        mod.detect
        return if options[:halt] == 'detect'

        say_status "info", "deploying #{mod.full_name} to '#{app_dir}'", :blue
        say_status "create", "creating deploy directory"
        mod.create_app_dir(app_dir) rescue abort("deploy directory is not empty")
        say_status "run", "installing and configuring dependencies", :magenta
        mod.prepare
        return if options[:halt] == 'prepare'

        say_status "create", "staging application files"
        mod.stage(app_dir)
        return if options[:halt] == 'stage'

        say_status "run", "launching the application", :magenta
        mod.start(app_dir)
        return if options[:halt] == 'start'

        say_status "run", "altering application runtime environment", :magenta
        mod.modify(app_dir)
        return if options[:halt] == 'modify'

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

    desc "package [DIRECTORY]", "Package up the given module directory"
    method_option :debug, :type => :boolean, :description => "enable debug output", :default => false
    def package(directory = Dir.pwd)
      handle_exception { Module.package(directory, options.dup) }
    end

    desc "defaults MODULE", "Print the default configuration settings for MODULE"
    def defaults(uri)
      mod = get_module(uri)
      mod.defaults.each do |k,v|
        puts "#{k}=#{v}"
      end
    end

    desc "version", "Print version information"
    def version
      puts Flintlock::VERSION
    end

    private

    def get_module(uri, options={})
      handle_exception do
        Flintlock::Module.new(uri, options)
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
