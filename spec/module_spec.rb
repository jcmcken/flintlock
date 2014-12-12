require 'spec_helper'

describe Flintlock::Module do
  before(:each) do
    @uri = 'foobar'
    @module = Module.new(@uri) 
  end
end
