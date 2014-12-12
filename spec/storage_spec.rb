require 'spec_helper'
require 'fileutils'
require 'tempfile'

describe Flintlock::Index do
    before :each do
      @root = Dir.mktmpdir('idx')
      Dir.chdir(@root)
      @idx = Flintlock::Index.new(@root)
      FileUtils.touch('testfile')
    end

    after :each do
      Dir.chdir('/tmp')
      FileUtils.rm_rf(@root)
    end

    it 'should have no keys by default' do
      @idx.keys.should == []
    end

    it 'should correctly add a non-existent key/value' do
      @idx.put('key', 'val')
      @idx.get('key').should == ['val']
    end

    it 'should not add dupes' do 
      @idx.put('key', 'val')
      @idx.put('key', 'val')
      @idx.get('key').should == ['val']
    end

    it 'should add multiple values' do
      @idx.put('key', 'val1')
      @idx.put('key', 'val2')
      @idx.get('key').should == ['val1', 'val2']
      @idx.put('key', 'val2')
      @idx.get('key').should == ['val1', 'val2']
    end

    it 'should do nothing if non-matching key' do
      @idx.keys.should == []
      @idx.remove('key', 'val')
      @idx.keys.should == []
    end

    it 'should completely remove keys with no values' do
      @idx.keys.length.should == 0
      @idx.put('key', 'val')
      @idx.keys.length.should == 1
      @idx.remove('key', 'val')
      @idx.keys.length.should == 0
    end

    it 'should remove keys successfully' do
      @idx.put('key', 'val1')
      @idx.put('key', 'val2')
      @idx.remove('key', 'val1')
      @idx.get('key').should == ['val2']
      @idx.remove('key', 'val1')
      @idx.get('key').should == ['val2']
    end
end

describe Flintlock::Storage do
  context 'default storage dir' do
    before :each do
      @sto = Flintlock::Storage.new
    end

    it { @sto.root_dir.should == File.join(Flintlock::Storage.root, 'sha256') }
  end

  context 'provided storage dir' do
    before :each do
      @root = Dir.mktmpdir('cas')
      Dir.chdir(@root)
      @sto = Flintlock::Storage.new(@root)
      FileUtils.touch('testfile')
    end

    after :each do
      Dir.chdir('/tmp')
      FileUtils.rm_rf(@root)
    end

    it { @sto.root_dir.should == File.join(@root, 'sha256') }

    it 'adds files' do
      @sto.has_file?('testfile').should be_false
      @sto.add('testfile')
      @sto.has_file?('testfile').should be_true
    end

    it 'dryrun adds files' do
      @sto.add('testfile', :dryrun => true) 
      @sto.has_file?('testfile').should be_false
    end

    it 'returns cas data on add' do
      data = @sto.add('testfile')
      filepath = File.expand_path('testfile')
      sum = Flintlock::Storage.checksum('testfile')
      data[filepath].should == sum
      data.length.should == 1 # should have one key
    end

    it 'only adds files once' do
      data = @sto.add('testfile')
      cas_path = @sto.fullpath(data.values[0])
      mtime = File.mtime(cas_path)
      @sto.add('testfile')
      File.mtime(cas_path).should == mtime
    end

    it 'removes files' do
      data = @sto.add('testfile')
      sum = data.values[0]
      cas_path = @sto.fullpath(sum)
      @sto.remove(sum)
      @sto.has_file?('testfile').should be_false
    end

    it 'adds directories' do
      Dir.mkdir('foo')
      File.open('foo/bar', 'w') { |f| f.write('bar') }
      File.open('foo/baz', 'w') { |f| f.write('baz') }
      data = @sto.add_dir('foo')
      @sto.has_file?('foo/bar').should be_true
      @sto.has_file?('foo/baz').should be_true
      data.length.should == 2
      data.each do |filename, sum|
        File.file?(filename).should be_true
        Flintlock::Storage.checksum(filename).should == sum
      end
    end

    it 'adds files to the index' do
      FileUtils.touch('foo')
      data = @sto.add('foo')
      @sto.index.get(data.values[0]).should == [ File.expand_path('foo') ] 
    end

    it 'removes files from the index' do
      FileUtils.touch('foo')
      data = @sto.add('foo')
      FileUtils.rm('foo')
      sum = data.values[0]
      @sto.clean(sum)
      @sto.index.get(sum).should == []
    end

    it { @sto.filename('foobar').should == 'obar' }
    it { @sto.dirname('foobar').should == 'fo' }
  end
end
