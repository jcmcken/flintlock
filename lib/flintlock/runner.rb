require 'open3'

module Flintlock
  class Runner
    def initialize(options={})
      @log = Util.load_logger(!!options[:debug])
    end

    def run(command, options={})
      options[:capture] = !!options[:capture]
      options[:env] = options.fetch(:env, {})
      @log.debug("running command: '#{command.inspect}'")
      stdout, stderr, status = Open3.capture3(options[:env], Shellwords.join(command))
      @log.linewise(stdout)
      @log.linewise(stderr)
      return options[:capture] ? [stdout, stderr, status.exitstatus] : status.exitstatus
    end
  end
end
