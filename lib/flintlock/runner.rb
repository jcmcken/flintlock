require 'open3'

module Flintlock
  class Runner
    def initialize(options={})
      @log = Util.load_logger(!!options[:debug])
    end

    def run(command, options={})
      @log.debug("running command: '#{command.inspect}'")

      options[:capture] = !!options[:capture]
      options[:env] = options.fetch(:env, ENV)

      rout, wout = IO.pipe
      rerr, werr = IO.pipe
      pid = Process.spawn(options[:env], Shellwords.join(command), :out => wout, :err => werr)

      Process.wait(pid)
      status = $?.exitstatus

      # capture stdout/stderr
      wout.close
      werr.close
      stdout = rout.read
      stderr = rerr.read

      @log.linewise(stdout)
      @log.linewise(stderr)

      return options[:capture] ? [stdout, stderr, status] : status 
    end
  end
end
