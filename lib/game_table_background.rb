require "thread"
require_relative "game_sync"
require_relative "game_background_presentation"
require_relative "game_room_localization"

# Covers the gap BEFORE GameScreen exists. The worker reads the ordinary room
# projection on existing feed notifications; the active UI presents copied data.
# On game start it hands over to the same GameScreen/SessionRunner used normally.
# Neither worker nor presenter updates the covered waiting-room form.
class GameRoomTableBackground
  using GameRoomLocalization::Translations
  def activity_cursor
    [@activity_cursor.to_i, @game_screen&.table_activity_cursor.to_i].max
  end

  def initialize(program:, transport:, repository:, lobby:, activity_repository:,
    table:, session_id:, activity_cursor:, screen_builder:, covered: nil)
    @program, @transport, @repository, @lobby = program, transport, repository, lobby
    @activity_repository, @table = activity_repository, table.dup
    @viewer = Session.name.to_s
    @table_id = lobby.table_id(table)
    @activity_cursor, @screen_builder = activity_cursor, screen_builder
    @ui_thread = Thread.current
    @covered = covered || -> { defined?($currentthread) && $currentthread && $currentthread != @ui_thread }
    @lock, @wake = Mutex.new, ConditionVariable.new
    @closed, @dirty, @handed_over = false, true, false
    @feed = transport.subscribe_game_session(@table_id)
    @sync = GameRoomSync::Controller.new(transport: @feed, table_id: @table_id, session_id: session_id)
    @baseline_session_id = session_id.to_i
  end

  def start
    @presentation = GameRoomBackgroundPresentation.attach(self, program: @program, runner: self,
      key: [@program.class, @table_id, @viewer.downcase])
    @program.class.manage(self) if @program.class.respond_to?(:manage)
    runtime = @program.class.app_runtime if @program.class.respond_to?(:app_runtime)
    @thread = Thread.new do
      Thread.current.report_on_exception = false
      work = -> do
        until closed? || @lock.synchronize { @handed_over }
          step
          @lock.synchronize { @wake.wait(@lock, 0.05) unless @closed || @handed_over }
        end
      end
      if runtime && defined?(Programs) && Programs.respond_to?(:with_runtime)
        Programs.with_runtime(runtime, &work)
      else
        work.call
      end
    ensure
      @feed.close
    end
    self
  rescue Exception
    close
    raise
  end

  def covered?; !!@covered.call; end
  def closed?; @lock.synchronize { @closed }; end
  def alive?; @thread&.alive?; end
  def join; @thread&.join; end
  def presentation_snapshot; @lock.synchronize { @packet }; end

  def step
    return if closed? || !covered? || @lock.synchronize { @handed_over }
    @transport.dispatch_pending_events
    event = @sync.next_event
    if event&.kind == :closed
      @lock.synchronize { @packet = {closed: true}; @handed_over = true }
      @dirty = false
      return
    end
    @dirty = true if event
    return if @sync.waiting? || !@dirty
    packet = @sync.synchronize do
      room = @lobby.snapshot_for(@table)
      if room
        session = @repository.session_for_table(room.table)
        {room: room, session: session,
          activity: @activity_repository.entries_for(room.table, viewer: @viewer)}
      else
        {closed: true}
      end
    end
    @sync.update_session(@repository.session_id(packet[:session]))
    packet = Marshal.load(Marshal.dump(packet))
    @lock.synchronize do
      unless @closed
        @packet = packet
        @handed_over = true if packet[:closed]
      end
    end
    @dirty = false
  rescue StandardError => error
    @dirty = true
    @sync.failed!(error)
    Log.warning("ELTEN Game Room waiting-room refresh failed: #{error.class}: #{error.message}") if defined?(Log)
  end

  # The host bridge calls this on the active UI thread, never on the worker.
  def present_background_session(_runner)
    packet = presentation_snapshot
    return if !packet || packet.equal?(@presented_packet)
    @presented_packet = packet
    if packet[:closed]
      @program.send(:speak, _("This table is no longer available."), stop: false, break_sequence: false)
      return
    end
    data = Marshal.load(Marshal.dump(packet))
    table = data[:room].table
    tracker = @program.send(:room_membership_tracker, table)
    @program.send(:play_game_sounds, tracker.observe(data[:room].members))
    @activity_cursor = @program.send(:announce_new_table_activity, data[:activity], after_id: @activity_cursor)
    session = data[:session]
    id = @repository.session_id(session)
    return if id <= 0 || id == @baseline_session_id || session["__aborted"]
    @baseline_session_id = id
    players = @repository.players_for(session).map { |player| GameRoomParticipants.display_name(player) }
    @program.send(:speak, _("Game started: %{players}.") % {players: players.join(", ")}, stop: false, break_sequence: false)
    game = @program.send(:game_definition, session["game"])
    # Realtime clients have their own UI/Communications lifecycle. Announce
    # their start, but do not create them inside another application's scene.
    return unless game&.session_runner? && game.validation_error(game.options_from_json(session["options"])) == nil
    screen = @screen_builder.call(session, game, table)
    @game_screen = screen
    screen.start_covered_session(covered: @covered, activity_cursor: @activity_cursor)
    @presentation&.close
    @lock.synchronize { @handed_over = true; @wake.broadcast }
  end

  # Foreground-only ownership transfer. The screen keeps its event cursors,
  # audio queue and executor, rather than replaying announcements on return.
  def take_game_screen
    screen, @game_screen = @game_screen, nil
    screen
  end

  def close
    @lock.synchronize { @closed = true; @wake.broadcast }
    @presentation&.close
    @feed.close
    @game_screen&.close_covered_session
    @game_screen = nil
    @program.class.release(self) if @program.class.respond_to?(:release)
  end
end
