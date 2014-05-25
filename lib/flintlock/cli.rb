require 'thor'
require 'flintlock/module'

module Flintlock
  class Cli < Thor
    include Thor::Actions

    desc "deploy MODULE DIRECTORY", "deploy a flintlock module MODULE to DIRECTORY"
    method_option :debug, :type => :boolean, :description => "enable debug output", :default => false
    def deploy(uri, app_dir)
      mod = get_module(uri, options)
      say_status "deploy", "#{mod.full_name} to '#{app_dir}'"
      say_status "create", "creating deploy directory"
      mod.create_app_dir(app_dir) rescue abort("deploy directory is not empty")
      say_status "prepare", "installing and configuring dependencies"
      mod.prepare
      say_status "stage", "staging application files"
      mod.stage(app_dir)
      say_status "start", "launching the application"
      mod.start(app_dir)
      say_status "modify", "altering application runtime environment"
      mod.modify(app_dir)
    end

    private

    def get_module(uri, options={})
      begin
        Flintlock::Module.new(uri, options)
      rescue InvalidModule => e
        abort("invalid flintlock module '#{e}'")
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
