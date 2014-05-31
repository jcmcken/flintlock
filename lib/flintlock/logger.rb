require 'logger'

module Flintlock
  class Logger < ::Logger
    def silence!
      @saved_logdev, @logdev = @logdev, nil
    end

    def unsilence!
      @logdev, @saved_logdev = @saved_logdev, nil if @saved_logdev
    end

    def linewise(output, options={})
      options[:level] ||= :debug
      output.lines.each { |x| send(options[:level], x) }
    end
  end
end
