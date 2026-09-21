require_relative '../game_room_background'

module GameRoomRealtime
  # A cancelled native call may finish late. Never kill it or let its result
  # replace a new connection. At most one abandoned worker and one current
  # worker can exist in this lane, even if the native API stops returning.
  class Operation
    TIMEOUT = 8.0
    attr_reader :kind

    def initialize(clock:, work: nil, factory: nil)
      @clock = clock
      @factory = factory || -> { GameRoomBackground::Work.new }
      @work = work || @factory.call
      @generation = 0
    end

    def start(kind, &block)
      return false if busy? || @closed
      generation = @generation
      started = @work.start do
        begin
          [generation, block.call, nil]
        rescue StandardError => error
          [generation, nil, error]
        end
      end
      @kind, @started_at = kind, @clock.call if started
      started
    end

    def take
      prepare
      return if @blocked || @closed
      result = @work.take
      return unless result
      value, worker_error = result
      kind = @kind
      @kind = @started_at = nil
      return [nil, worker_error, kind] if worker_error
      return unless value && value[0] == @generation
      [value[1], value[2], kind]
    end

    def busy?
      prepare
      @blocked || @work.busy?
    end

    def expired?
      @started_at && @clock.call - @started_at >= TIMEOUT
    end

    def cancel
      @generation += 1
      @kind = @started_at = nil
      @work.take # Discard an already completed result without retiring a thread.
      if @work.busy?
        @work.close
        @blocked = true
      end
      prepare
    end

    def close
      @closed = true
      @work.close
      @retired&.close
    end

    private

    def prepare
      return if @closed
      @retired = nil if @retired && !@retired.busy?
      return unless @blocked
      if !@work.busy?
        @work = @factory.call
        @blocked = false
      elsif !@retired
        @retired = @work
        @work = @factory.call
        @blocked = false
      end
    end
  end
end
