require 'thor'
require 'flintlock/module'

module Flintlock
  class Cli < Thor
    include Thor::Actions

    desc "deploy MODULE DIRECTORY", "deploy a flintlock module MODULE to DIRECTORY"
    method_option :debug, :type => :boolean, :description => "enable debug output", :default => false
    def deploy(uri, app_dir)
      mod = get_module(uri, options)
      say_status "info", "deploying #{mod.full_name} to '#{app_dir}'", :blue
      say_status "create", "creating deploy directory"
      mod.create_app_dir(app_dir) rescue abort("deploy directory is not empty")
      say_status "run", "installing and configuring dependencies", :magenta
      mod.prepare
      say_status "create", "staging application files"
      mod.stage(app_dir)
      say_status "run", "launching the application", :magenta
      mod.start(app_dir)
      say_status "run", "altering application runtime environment", :magenta
      mod.modify(app_dir)
      say_status "info", "complete!", :blue
    end

    private

    def get_module(uri, options={})
      begin
        Flintlock::Module.new(uri, options)
      rescue InvalidModule => e
        abort("invalid flintlock module '#{e}'")
      rescue UnsupportedModuleURI => e
        abort("don't know how to download '#{e}'!")
      end
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
