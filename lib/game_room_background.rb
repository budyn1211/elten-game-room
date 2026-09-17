require "thread"

# One finite context-aware operation, no UI, pump, polling loop or modal task.
# The owner drains the result during its existing update and closes this object
# with the application. Network operations retain their own bounded timeouts.
module GameRoomBackground
  class Work
    def initialize(runtime: nil)
      @runtime = runtime
      @result = Queue.new
      @closed = false
    end

    def busy?; @thread&.alive? || !@result.empty?; end
    def closed?; @closed; end

    def start(&operation)
      return false if @closed || busy?
      @thread = Thread.new do
        Thread.current.report_on_exception = false
        begin
          work = -> { operation.call }
          value = if @runtime && defined?(Programs) && Programs.respond_to?(:with_runtime)
            Programs.with_runtime(@runtime) { work.call }
          else
            work.call
          end
          @result << [value, nil] unless @closed
        rescue StandardError => error
          @result << [nil, error] unless @closed
        end
      end
      true
    end

    def take
      @result.pop(true)
    rescue ThreadError
      nil
    end

    def close
      @closed = true
      @result.clear
      # Never kill a network write whose commit status could be uncertain.
      # The in-flight finite call may finish, but cannot schedule more work.
      nil
    end
  end
end
