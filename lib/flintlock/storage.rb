require 'digest/sha2'
require 'fileutils'
require 'pstore'

module Flintlock
  class Index
    attr_reader :filename

    def initialize(root = nil)
      @root = root || Storage.root
      @filename = File.join(@root, '.index')
      FileUtils.mkdir_p(@root)
      @cursor = PStore.new(@filename)
    end

    def put(key, value)
      transaction do
        current_val = @cursor[key]
        if current_val.nil?
          @cursor[key] = [value]
        elsif current_val.include?(value)
          return
        else
          @cursor[key] = current_val << value
        end 
        nil
      end
    end

    def remove(key, value)
      transaction do
        current_val = @cursor[key]
        return if current_val.nil?
        LOG.debug("index: removing value '#{value}' from key '#{key}'")
        current_val.delete(value)
        if current_val.empty?  
          @cursor.delete(key)
        else
          @cursor[key] = current_val
        end
        nil
      end
    end

    def get(key)
      transaction do
        @cursor[key] || []
      end
    end

    def keys
      transaction do
        @cursor.roots
      end
    end

    private

    def transaction(&block)
      @cursor.transaction do
        block.call
      end
    end
  end

  class Storage
    attr_reader :root, :index 

    def self.root
      File.expand_path(File.join('~', '.flintlock', 'cas'))  
    end

    def initialize(root = nil, umask = 0027)
      LOG.debug('loading CAS')
      @root = root || Storage.root
      File.umask(umask)
      LOG.debug('loading CAS index')
      @index = Index.new(@root)
    end

    def add(filename, options = {})
      dryrun = options[:dryrun] || false
      filename = File.expand_path(filename)
      sum = Storage.checksum(filename)
      path = fullpath(sum)
      if ! File.file?(path) and ! dryrun
        LOG.debug("adding '#{filename}' (#{sum}) to CAS")
        @index.put(sum, filename)
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.cp(filename, path) 
      end
      {filename => sum}
    end

    def has_file?(filename)
      File.file?(compute_fullpath(filename))
    end

    def add_dir(dir, options = {})
      data = Hash.new
      LOG.debug("adding directory '#{dir}' to CAS")
      Dir[File.join(dir, '**', '*')].each do |f|
        next if ! File.file?(f)
        data.update(add(f, options))
      end
      data
    end

    def dir_manifest(dir)
      add_dir(dir, :dryrun => true)
    end

    def remove(checksum)
      path = fullpath(checksum)
      if File.file?(path)
        LOG.debug("removing #{checksum} from CAS")
        FileUtils.rm_f(path)
      end
    end

    def clean(checksum)
      LOG.debug("running CAS GC on checksum '#{checksum}'")
      @index.get(checksum).each do |filename|
        if ! File.file?(filename)
          # remove index entries where the file no longer exists
          @index.remove(checksum, filename)
        end
      end
      # remove the stored file in the CAS if nothing referencing it
      remove(checksum) if @index.get(checksum).empty?
    end

    def size
      total = 0
      Dir[File.join(@root, '**', '*')].each do |f|
        total += File.size(f) if File.file?(f) && File.size?(f)
      end
      total
    end

    def gc
      LOG.debug('CAS performing full garbage collection')
      LOG.debug("CAS size pre-GC: #{size}")
      # garbage collect the CAS index
      @index.keys.each do |checksum|
        clean(checksum)
      end
      LOG.debug("CAS size post-GC: #{size}")
    end

    def self.checksum(filename)
      Digest::SHA256.file(filename).hexdigest
    end 

    def fullpath(checksum)
      File.join(directory(checksum), filename(checksum))
    end

    def compute_fullpath(filename)
      fullpath(Storage.checksum(filename))
    end

    def root_dir
      File.join(@root, 'sha256')
    end

    def directory(checksum)
      return File.join(root_dir, dirname(checksum))
    end
    
    def filename(checksum)
      checksum[2..-1]
    end

    def dirname(checksum)
      checksum[0..1]
    end
  end
end
