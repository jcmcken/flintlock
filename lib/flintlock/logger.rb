require 'logger'

module Flintlock
  class Logger < ::Logger
    def silence!
      @saved_logdev, @logdev = @logdev, nil
    end

    def unsilence!
      @logdev, @saved_logdev = @saved_logdev, nil if @saved_logdev
    end
  end
end
