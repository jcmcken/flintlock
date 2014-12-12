require 'spec_helper'
require 'fileutils'

describe Flintlock do
  before(:each) do
    include Flintlock
  end

  context 'with fake fs' do
    include FakeFS::SpecHelpers 
  
    it "should detect a simple runtime" do
      File.open('foo', 'w') { |f| f.write("#!/bin/bash") }
      Flintlock::Util.detect_runtime('foo').should == ['/bin/bash'] 
    end
  
    it "should detect a complex runtime" do
      File.open('foo', 'w') { |f| f.write("#!/usr/bin/env bash -eu") }
      Flintlock::Util.detect_runtime('foo').should == ['/usr/bin/env', 'bash', '-eu'] 
    end
  
    it "should select default runtime" do
      File.open('foo', 'w') { |f| f.write("echo 'test'") }
      Flintlock::Util.detect_runtime('foo').should == ['/bin/sh'] 
    end
     
    it "should select runtime for empty script" do
      FileUtils.touch('foo')
      Flintlock::Util.detect_runtime('foo').should == ['/bin/sh'] 
    end

    it "should detect empty directory" do
      Dir.mkdir('foo')
      Flintlock::Util.empty_directory?('foo').should be_true
      Dir.mkdir('bar')
      FileUtils.touch('bar/foo')
      Flintlock::Util.empty_directory?('bar').should be_false
    end

    it "should detect executables in path" do
      Dir.mkdir('bin')
      FileUtils.touch('bin/someexe')
      FileUtils.chmod 0444, 'bin/someexe'
      ENV.stub(:[]).with('PATH').and_return('bin')
      Flintlock::Util.which('someexe').should be_nil
      FileUtils.chmod 0755, 'bin/someexe'
      Flintlock::Util.which('someexe').should == 'bin/someexe'
    end
  end

  context 'with real fs' do
    describe 'real filesystem' do
      # some sanity checking on the mime parser
      it "should detect dir mime-type" do
        Flintlock::Util.mime_type('/etc').should == 'application/x-directory'
      end
    
      it "should detect file mime-type" do
        Flintlock::Util.mime_type('/etc/hosts').should == 'text/plain'
      end

    end
  end

  context 'misc utils' do
    describe 'misc utils' do
      it { Flintlock::Util.relative_file('/path/to/foo', '/path').should == 'to/foo' }
      it { Flintlock::Util.relative_file('/path/to/foo', '/too/foo').should == '/path/to/foo' }

      it { Flintlock::Util.full_extname('foo.tar.gz').should == '.tar.gz' }
      it { Flintlock::Util.full_extname('foo-0.2.tar.gz').should == '.tar.gz' }
      it { Flintlock::Util.full_extname('blah.git').should == '.git' }

      it { Flintlock::Util.get_uri_scheme('git+ssh://foo').should == 'git' }
      it { Flintlock::Util.get_uri_scheme('ssh://foo').should == 'ssh' }
      it { Flintlock::Util.get_uri_scheme('http://foo').should == 'http' }
    end
  end
end
