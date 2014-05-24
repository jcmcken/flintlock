require 'thor'
require 'flintlock/module'

module Flintlock
  class Cli < Thor
    include Thor::Actions

    desc "deploy MODULE DIRECTORY", "deploy a flintlock module MODULE to DIRECTORY"
    def deploy(uri, app_dir)
      mod = Flintlock::Module.new(uri)
      mod.deploy(app_dir)
    end
  end
end
