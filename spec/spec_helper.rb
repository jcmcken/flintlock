require 'rspec'
require 'flintlock'
require 'fakefs/spec_helpers'

def capture_stdout(&block)
  orig_stdout = $stdout
  $stoud = fake = StringIO.new
  begin
    yield
  ensure
    $stdout = orig_stdout
  end
  fake.string
end
