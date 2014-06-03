require 'spec_helper'

describe 'fake filesystem' do
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
    File.open('foo', 'w') { |f| f.write("") }
    Flintlock::Util.detect_runtime('foo').should == ['/bin/sh'] 
  end
end

describe 'real filesystem' do
  # some sanity checking on the mime parser
  it "should detect dir mime-type" do
    Flintlock::Util.mime_type('/etc').should == 'application/x-directory'
  end

  it "should detect file mime-type" do
    Flintlock::Util.mime_type('/etc/hosts').should == 'text/plain'
  end
end
