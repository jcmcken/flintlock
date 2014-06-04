require 'spec_helper'
require 'flintlock/completer'
require 'flintlock/cli'

describe "command completer" do
  it "should complete a command" do
    ENV['COMP_LINE'] = 'flintlock dep'
    Flintlock::Completer.matching_commands.should == ["deploy"]
  end

  it "should display all commands if no subcommand" do
    ENV['COMP_LINE'] = 'flintlock '
    Flintlock::Completer.matching_commands.should == Flintlock::Cli.all_commands.keys
  end

  it "should not display commands if previously completed" do
    ENV['COMP_LINE'] = 'flintlock deploy '
    capture_stdout { Flintlock::Completer.complete }.should == ""
  end
end
