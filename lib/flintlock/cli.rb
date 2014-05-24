require 'thor'
require 'flintlock/module'

module Flintlock
  class Cli < Thor
    include Thor::Actions

    desc "deploy MODULE DIRECTORY", "deploy a flintlock module MODULE to DIRECTORY"
    def deploy(uri, directory)
      mod = Flintlock::Module.new(uri)
      mod.deploy(directory)
    end
  end
end
