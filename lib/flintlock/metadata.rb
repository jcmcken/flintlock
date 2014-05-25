require 'json'

module Flintlock
  class Metadata
    attr_reader :filename

    def initialize(filename = nil)
      @filename = filename || default_metadata_file
      @data = Metadata.load(@filename)
    end

    def self.filename
      'metadata.json'
    end

    def valid?
      begin
        author
        version
        name
      rescue
        return false
      end 
      return true
    end

    def default_metadata_file
      File.join(Dir.pwd, Metadata.filename)
    end

    def self.load(filename)
      JSON.load(File.read(filename))
    end

    def author
      @data.fetch('author')
    end

    def version
      @data.fetch('version')
    end

    def name
      @data.fetch('name')
    end

    def full_name
      "#{author}/#{name} (#{version})"
    end

  end
end
