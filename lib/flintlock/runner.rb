require 'open3'

module Flintlock
  class Runner
    def self.run(*args)
      Runner.new.run(*args)
    end

    def run(command, options={})
      LOG.debug("running command: '#{command.inspect}'")

      options[:capture] = !!options[:capture]
      options[:env] = options.fetch(:env, ENV)
      options[:raise_on_fail] = !!options[:raise_on_fail]

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

      LOG.linewise(stdout, :level => :info)
      LOG.linewise(stderr)

      if status != 0 && options[:raise_on_fail]
        raise RunFailure 
      end

      return options[:capture] ? [stdout, stderr, status] : status 
    end
  end

  class EnvRunner
    def initialize(defaults_script)
      @runner = Runner.new
      @defaults_script = defaults_script
      @env = File.file?(@defaults_script) ? load_env(defaults_script) : current_env
    end

    def run(script, *args)
      return if skip_script?(script)
      command = [*Util.detect_runtime(script), script, *args].compact
      status = @runner.run(command, :env => @env, :raise_on_fail => true)
    end

    def defaults
      Hash[@env.to_a - ENV.to_a]
    end

    private

    def skip_script?(script)
      skip = ! File.file?(script) || Util.empty_script?(script)
      LOG.debug("skipping '#{script}'") if skip
      skip
    end

    def load_env(script)
      env = Util.load_script_env(script)
      LOG.debug("defaults script is #{script}")
      LOG.debug("defaults env is #{env.inspect}")
      env = env.merge(current_env)
      LOG.debug("merged env is #{env.inspect}")
      env
    end

    def current_env
      Hash[ENV.to_a] # get rid of ENV obj
    end
  end
end
