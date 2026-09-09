require_relative "game_bots"
require_relative "game_participants"
require_relative "game_layout"
require_relative "game_sync"
require_relative "game_simulation"
require_relative "game_rules"
require_relative "game_sounds"
require_relative "game_chat_commands"
require_relative "game_history_navigation"
require_relative "room_presentation"
require_relative "participant_menu"

class GameScreen
  TIMER_INTERVAL = 0.05

  def initialize(
    program:,
    repository:,
    game:,
    session:,
    table:,
    table_owner:,
    room_snapshot_provider:,
    synchronizer:,
    invite_online: nil,
    invite_contacts: nil,
    membership_tracker: nil,
    game_status_changed: nil,
    activity_repository: nil,
    game_name: nil,
    send_chat: nil,
    layout: nil,
    manage_computer: nil,
    transfer_master: nil,
    competitor_departed: nil
  )
    @layout = layout
    @manage_computer = manage_computer
    @transfer_master = transfer_master
    @competitor_departed = competitor_departed
    @program = program
    @repository = repository
    @game = game
    @session = session
    @table = table
    @table_owner = table_owner
    @room_snapshot_provider = room_snapshot_provider
    @synchronizer = synchronizer
    @invite_online = invite_online
    @invite_contacts = invite_contacts
    @membership_tracker = membership_tracker
    @game_status_changed = game_status_changed
    @activity_repository = activity_repository
    @game_name = game_name || ->(id) { id.to_s }
    @send_chat = send_chat
    @room_snapshot = nil
    @surface_state = {}
    @selected_surface_action = nil
    @history_index = 0
    @users_index = 0
    @form_index = 0
    @focus_location = [:game, 0]
    @surface_identity = nil
    @last_seen_event_id = nil
    @turn_history_entries = {}
    @pending_event_ids = []
    @history_follows_tail = true
    @new_session_id = nil
    @focus_new_game = false
    @pending_signal_received_at = nil
    @suppress_surface_focus = false
    @latest_wait_replay = nil
    @spoken_timer_announcements = {}
    @activity_entries = nil
    @last_seen_activity_id = nil
    @last_game_payload = nil
    @chat_text = ""
    @chat_index = 0
    @chat_check = 0
    @chat_control = nil
    if @layout != nil
      initial_view = @layout.snapshot
      @focus_location = initial_view.focus_location
      @chat_control = @layout.chat
      @chat_text = initial_view.chat_text
      @chat_index = initial_view.chat_index
      @chat_check = initial_view.chat_check
      if @layout.session_id == @repository.session_id(@session)
        @surface_state = initial_view.surface_state
        @surface_identity = initial_view.surface_identity
      else
        @focus_new_game = true
      end
    end
    @pending_chat_message = nil
    @clear_chat_after_action = false
    @history_navigator = GameRoomHistory::Navigator.new
    @hidden_submissions = HiddenSubmissions::Vault.new(
      HiddenSubmissions::ProgramStorage.new(@program)
    )
    @random_source = GameRoomRandom::LocalSecureSource.new
    @bot_coordinator = GameRoomBots::Coordinator.new
    @bot_turn_controller = @repository.bot_turn_controller(table_id)
  end

  def run
    loop do
      signal_received_at = @pending_signal_received_at
      confirmation_pending = @bot_turn_controller.waiting_for_confirmation?
      verification_forced = @bot_turn_controller.verification_due?
      using_cached_payload = false
      snapshot_started_at = monotonic_time
      log_signal_timing("snapshot_started", signal_received_at)
      payload = network_task(
        _("Updating game"),
        ui: refresh_input_ui,
        silent: confirmation_pending
      ) do
        @synchronizer.synchronize do
          room_snapshot = @room_snapshot || @room_snapshot_provider.call
          [
            @repository.snapshot_for(
              @session,
              force_events: signal_received_at != nil || verification_forced
            ),
            room_snapshot,
            @activity_entries || activity_entries_for(room_snapshot)
          ]
        end
      end
      log_signal_timing(
        "snapshot_finished",
        signal_received_at,
        stage_started_at: snapshot_started_at
      )
      if payload == nil || payload[0] == nil || payload[1] == nil
        return if !confirmation_pending || @last_game_payload == nil

        @bot_turn_controller.defer_verification
        verification_forced = false
        payload = @last_game_payload
        using_cached_payload = true
      else
        @last_game_payload = payload
      end

      snapshot, next_room_snapshot, next_activity_entries = payload
      if @membership_tracker != nil
        GameRoomSounds.play_all(@program, @membership_tracker.observe(next_room_snapshot.members))
      end
      @room_snapshot = next_room_snapshot
      @table = next_room_snapshot.table
      @table_owner = @table["owner"].to_s
      @activity_entries = next_activity_entries.to_a
      @session = snapshot.session
      replay_started_at = monotonic_time
      replay = @game.replay(@session, snapshot.events, @repository)
      departed = departed_active_competitor(replay)
      if departed != nil && @competitor_departed&.call(@table, @session, departed)
        stop_pending_speech
        return :cancelled
      end
      synchronize_table_status(replay)
      log_signal_timing(
        "replay_finished",
        signal_received_at,
        stage_started_at: replay_started_at
      )
      process_new_events(replay, signal_received_at: signal_received_at)
      process_new_table_activity(replay)
      @pending_signal_received_at = nil
      verify_pending_move(replay)
      confirmation = @bot_turn_controller.observe(
        session_id: @repository.session_id(@session),
        events: snapshot.events,
        confirmed_event_ids: @repository.confirmed_event_ids(@session),
        verified: verification_forced
      )
      log_bot_confirmation(confirmation) if ![:idle, :cooldown, :waiting_for_confirmation].include?(confirmation)

      if !replay.finished? && !using_cached_payload && perform_automatic_action(replay)
        @suppress_surface_focus = true
        next
      end
      revision = @repository.events_revision(snapshot.events)
      bot_actor = pending_bot_actor(replay)
      bot_lease = if bot_actor == nil
        nil
      else
        @bot_turn_controller.acquire(
          session_id: @repository.session_id(@session),
          actor: bot_actor,
          revision: revision
        )
      end
      action = wait_for_action(replay, revision, bot_actor: bot_actor, bot_lease: bot_lease)
      if @latest_wait_replay != nil
        replay = @latest_wait_replay
        @latest_wait_replay = nil
      end

      case action
      when :game_action
        submit_action(replay)
        clear_chat_draft if @clear_chat_after_action
        @clear_chat_after_action = false
        @suppress_surface_focus = true
      when :new_session
        switch_to_new_session
      when :rules
        options = @game.options_from_json(@session["options"])
        GameRoomScreens::GameRules.new(@game.rule_book(options: options)).wait
      when :invite_online
        @invite_online&.call(@table)
      when :invite_contacts
        @invite_contacts&.call(@table)
      when :add_bot, :remove_bot
        @manage_computer&.call(@table, action, @selected_participant)
        @room_snapshot = nil
        @activity_entries = nil
        @suppress_surface_focus = true
      when :transfer_master
        @transfer_master&.call(@table, @selected_participant)
        @room_snapshot = nil
        @activity_entries = nil
        @suppress_surface_focus = true
      when :restart
        return :restart
      when :game_cancelled
        stop_pending_speech
        return :cancelled
      when :participant_departed
        departed = @departed_participant
        @departed_participant = nil
        if departed != nil && @competitor_departed&.call(@table, @session, departed)
          stop_pending_speech
          return :cancelled
        end
      when :chat
        submit_chat
        @suppress_surface_focus = true
      when :back
        stop_pending_speech
        return :back
      when :refresh
        @suppress_surface_focus = true
        next
      end
    end
  end

  private

  def wait_for_action(replay, revision, bot_actor: nil, bot_lease: nil)
    action = nil
    bot_token = bot_lease == nil ? nil : EltenAPI::Tasks::CancellationToken.new
    history_items = combined_history_items(replay)
    user_items = room_user_items(replay)
    view_spec = @game.game_view_spec(replay, Session.name, context: action_context)
    phase = replay.finished? ? :finished : :active
    phase_changed = @layout != nil && (@layout.phase != phase || @focus_new_game == true)
    if @layout == nil
      @layout = GameRoomLayout::Screen.new(
        view_spec: view_spec, history_items: history_items, user_items: user_items,
        users_header: users_header, chat_control: @chat_control,
        phase: phase,
        own_table: same_user?(@table_owner, Session.name)
      )
    else
      @layout.update(
        view_spec: view_spec, history_items: history_items, user_items: user_items,
        users_header: users_header, phase: phase,
        own_table: same_user?(@table_owner, Session.name),
        surface_state: @surface_state, reset_surface: @surface_identity == nil,
        new_game: @focus_new_game == true
      )
    end
    @focus_new_game = false
    @layout.session_id = @repository.session_id(@session)
    layout = @layout
    layout.begin_bindings
    layout.back_button.label = _("Leave")
    layout.activity_cursor = @last_seen_activity_id
    @chat_control = layout.chat
    # Moving to Restart/Waiting after the final event must preserve the result
    # announcements, but the newly focused status should still be spoken after
    # them. speech_wait below queues that focus instead of letting it interrupt.
    announce_finished_focus = phase_changed && phase == :finished
    silent_entry = @suppress_surface_focus && !announce_finished_focus
    @suppress_surface_focus = false
    surface = layout.surface
    surface.sound_player = ->(name) { GameRoomSounds.play(@program, name) } if surface.respond_to?(:sound_player=)
    history = layout.history
    users = layout.users
    chat = layout.chat
    back_button = layout.back_button
    form = layout.form

    remember_position = lambda do
      snapshot = layout.snapshot
      @surface_state = snapshot.surface_state
      @history_index = snapshot.history_index
      @users_index = snapshot.users_index
      @history_follows_tail = snapshot.history_follows_tail
      @form_index = snapshot.form_index
      @focus_location = snapshot.focus_location
      @surface_identity = snapshot.surface_identity
      @chat_text = snapshot.chat_text
      @chat_index = snapshot.chat_index
      @chat_check = snapshot.chat_check
    end
    shortcuts = normalized_game_shortcuts(@game.game_shortcuts(replay, Session.name))
    handle_shortcut = lambda do |shortcut|
      if bot_actor != nil && ![:announcement, :browse, :surface].include?(shortcut.kind)
        next
      end

      active_shortcut = refreshed_announcement_shortcut(shortcut, replay, Session.name)
      selection = activate_game_shortcut(active_shortcut, surface)
      if selection == :surface_handled
        remember_position.call
        refresh_history_control(history, replay) if @game.history_presentation_depends_on_surface_state?
        next
      end
      next if selection == nil

      remember_position.call
      @selected_surface_action = selection
      action = :game_action
      form.resume
    end
    bind_game_shortcuts(
      form,
      layout.shortcut_fields,
      shortcuts,
      &handle_shortcut
    )
    bind_history_navigation(form) do |operation, value|
      entries = combined_history_entries(replay)
      message = case operation
      when :category
        @history_navigator.change_category(entries, value)
      when :move
        @history_navigator.move(entries, value)
      when :jump
        @history_navigator.jump(entries, value)
      end
      speak(message.to_s) if !message.to_s.empty?
    end
    GameRoomParticipantMenu.bind(layout, viewer: Session.name, available: -> do
      actions = [:rules, :leave]
      actions << :invite_online if @invite_online != nil
      actions << :invite_contacts if @invite_contacts != nil
      if @manage_computer != nil || @transfer_master != nil
        actions.concat(GameRoomParticipantMenu.management_actions(
          room: @room_snapshot, game: @game, active: !replay.finished?, viewer: Session.name, owner: @table_owner
        ))
      end
      actions
    end) do |requested, participant|
      next if action != nil

      remember_position.call
      @selected_participant = participant
      action = requested == :leave ? :back : requested
      cancel_bot_decision(bot_token, :participant_menu)
      form.resume
    end
    layout.restart_button.on(:press) do
      next if action != nil || !replay.finished? || !same_user?(@table_owner, Session.name)

      remember_position.call
      action = :restart
      form.resume
    end
    surface.on_action do |selection|
      next if bot_actor != nil

      if selection["_stay_open"] == true
        remember_position.call
        @selected_surface_action = selection
        action = :inline_game_action
        form.resume
      else
        remember_position.call
        @selected_surface_action = selection
        action = :game_action
        form.resume
      end
    end
    back_button.on(:press) do
      if surface.cancel_pending_action?
        surface.cancel_pending_action!
        remember_position.call
      else
        remember_position.call
        action = :back
        form.resume
      end
    end
    chat.on_submit do
      next if action != nil

      remember_position.call
      submission = GameRoomChatCommands.interpret(@chat_text, surface)
      if submission.kind == :empty
        alert(_("Type a chat message first."))
      elsif submission.kind == :error
        alert(submission.message.to_s)
        clear_chat_draft
      elsif submission.kind == :chat && @send_chat == nil
        alert(_("Chat is not available."))
      elsif submission.kind == :chat
        @pending_chat_message = submission.text
        action = :chat
        cancel_bot_decision(bot_token, :chat)
        form.resume
      elsif submission.kind == :movement
        @selected_surface_action = submission.action
        @clear_chat_after_action = true
        action = :game_action
        cancel_bot_decision(bot_token, :chat_command)
        form.resume
      end
    end
    form.add_timer(FormTimer.new(TIMER_INTERVAL, repeat: true) do
      next if action != nil

      announce_due_timers(replay)
      local_action = if replay.finished?
        nil
      else
        @game.automatic_surface_action(
          replay,
          Session.name,
          surface: surface,
          context: action_context
        )
      end
      if local_action != nil
        remember_position.call
        @selected_surface_action = local_action
        action = :game_action
        form.resume_for_refresh
        next
      end

      automatic_due = automatic_action_due?(replay)
      sync_event = @synchronizer.next_event(
        idle: form.keyboard_idle_frame?,
        allow_recovery: recovery_allowed?(automatic_due, bot_actor)
      )
      if sync_event&.kind == :game_started
        remember_position.call
        @new_session_id = sync_event.session_id
        action = :new_session
        cancel_bot_decision(bot_token, :new_session_signal)
        form.resume_for_refresh
      elsif sync_event&.kind == :game_changed
        remember_position.call
        received_at = sync_event.received_at
        @pending_signal_received_at = received_at.is_a?(Numeric) ? received_at.to_f : monotonic_time
        log_signal_timing("signal_consumed", @pending_signal_received_at)
        # A LiveSessions wake-up only says that something may have changed.
        # Confirm the event revision before rebuilding the form so duplicate
        # or already-applied notifications stay invisible to the user.
        action = :check_signal
        cancel_bot_decision(bot_token, :game_signal)
        form.resume_for_refresh
      elsif sync_event&.kind == :table_changed
        remember_position.call
        action = :room_refresh
        cancel_bot_decision(bot_token, :room_change_signal)
        form.resume_for_refresh
      elsif automatic_due
        remember_position.call
        action = :refresh
        form.resume_for_refresh
      elsif sync_event&.kind == :recovery
        remember_position.call
        action = :recovery_refresh
        cancel_bot_decision(bot_token, :connection_recovery)
        form.resume_for_refresh
      elsif bot_actor != nil && bot_lease == nil && @bot_turn_controller.verification_due?
        remember_position.call
        action = :bot_verification
        form.resume_for_refresh
      elsif bot_actor != nil && bot_lease == nil && @bot_turn_controller.ready?(
        session_id: @repository.session_id(@session),
        actor: bot_actor
      )
        remember_position.call
        action = :bot_ready
        form.resume_for_refresh
      end
    end)

    run_bot_turn = lambda do
      next :idle if bot_token == nil || bot_lease == nil

      bot_started_at = monotonic_time
      bot_phase = replay.state.is_a?(Hash) ? replay.state[:phase] : nil
      Log.debug(
        "ELTEN Game Room bot decision started " \
        "table=#{table_id} session=#{@repository.session_id(@session)} " \
        "game=#{@game.id} actor=#{bot_actor} phase=#{bot_phase || 'none'} " \
        "events=#{replay.accepted_events.length}"
      )
      decision = begin
        calculate_bot_decision(replay, form: form, cancellation_token: bot_token)
      rescue EltenAPI::Tasks::Cancelled => error
        Log.debug(
          "ELTEN Game Room bot decision cancelled " \
          "table=#{table_id} session=#{@repository.session_id(@session)} " \
          "actor=#{bot_actor} elapsed_ms=#{((monotonic_time - bot_started_at) * 1_000).round(1)} " \
          "reason=#{error.message}"
        )
        nil
      end
      Log.debug(
        "ELTEN Game Room bot decision finished " \
        "table=#{table_id} session=#{@repository.session_id(@session)} " \
        "actor=#{bot_actor} elapsed_ms=#{((monotonic_time - bot_started_at) * 1_000).round(1)} " \
        "decision=#{decision == nil ? 'none' : 'ready'}"
      )
      if decision == nil || action != nil
        @bot_turn_controller.cancel(bot_lease)
        bot_lease = nil
        bot_token = nil
        next action == nil ? :idle : :interrupted
      end

      remember_position.call
      changed = perform_bot_turn(replay, decision, lease: bot_lease, form: form)
      # The form remains interactive while the network task submits the bot's
      # move. Preserve anything typed during that task before deciding whether
      # the screen needs to be rebuilt.
      remember_position.call
      waiting_for_confirmation = @bot_turn_controller.waiting_for_confirmation?
      @bot_turn_controller.cancel(bot_lease) if !waiting_for_confirmation
      bot_lease = nil
      bot_token = nil
      changed ? :changed : :unchanged
    end

    waited_once = false
    background_work = false
    pending_game_refresh = false
    loop do
      if bot_token != nil
        background_work = true
        bot_result = run_bot_turn.call
        if bot_result == :changed
          @latest_wait_replay = replay
          return action if action != nil && !maintenance_action?(action)
          return :refresh if action == nil

          pending_game_refresh = true
        end
        return action if action != nil && !maintenance_action?(action)
      end

      if action == nil
        if !waited_once && announce_finished_focus && !background_work
          speech_wait
          form.wait
        elsif !waited_once && !silent_entry && !background_work
          form.wait
        else
          layout.wait_without_announcement
        end
        waited_once = true
      end

      restart_bot = false
      loop do
        cancelled_bot = bot_token != nil && bot_token.cancelled?
        case action
        when :inline_game_action
          selection = @selected_surface_action
          @selected_surface_action = nil
          inline_result = submit_inline_action(replay, selection)
          if inline_result != nil
            replay, inserted = inline_result
            newest_id = inserted.map { |event| @repository.event_id(event) }.max.to_i
            revision = [revision[0].to_i + inserted.length, [revision[1].to_i, newest_id].max]
          end
        when :check_signal
          remote_action, remote_session_id = synchronized_network_task(
            _("Checking for game updates"),
            ui: refresh_input_ui
          ) do
            remote_game_update(revision)
          end || [nil, nil]
          if remote_action == :new_session
            @new_session_id = remote_session_id
            action = :new_session
            break
          elsif remote_action == :game_cancelled
            action = :game_cancelled
            break
          elsif remote_action == :refresh
            action = :refresh
            break
          end
          @pending_signal_received_at = nil
        when :room_refresh
          room_status, snapshot, activity_entries = synchronized_network_task(
            _("Updating table"),
            ui: refresh_input_ui
          ) do
            fetch_room_snapshot
          end || [:failed, nil, []]
          if room_status == :closed
            action = :back
            break
          elsif room_status == :updated
            apply_room_snapshot(users, history, replay, snapshot, activity_entries)
            departed = departed_active_competitor(replay)
            if departed != nil
              @departed_participant = departed
              action = :participant_departed
              break
            end
          end
        when :recovery_refresh
          recovery_started_at = monotonic_time
          payload = synchronized_network_task(_("Updating game"), ui: refresh_input_ui) do
            room_status, snapshot, activity_entries = fetch_room_snapshot
            remote_action, remote_session_id = remote_game_update(revision)
            [room_status, snapshot, activity_entries, remote_action, remote_session_id]
          end
          room_status, snapshot, activity_entries, remote_action, remote_session_id = payload || [:failed, nil, [], nil, nil]
          Log.debug(
            "ELTEN Game Room connection recovery " \
            "table=#{table_id} session=#{@repository.session_id(@session)} " \
            "elapsed_ms=#{((monotonic_time - recovery_started_at) * 1_000).round(1)} " \
            "room_status=#{room_status} remote_action=#{remote_action || 'none'}"
          )
          if room_status == :closed
            action = :back
            break
          end
          apply_room_snapshot(users, history, replay, snapshot, activity_entries) if room_status == :updated
          if room_status == :updated && (departed = departed_active_competitor(replay)) != nil
            @departed_participant = departed
            action = :participant_departed
            break
          end
          if remote_action == :new_session
            @new_session_id = remote_session_id
            action = :new_session
            break
          elsif remote_action == :game_cancelled
            action = :game_cancelled
            break
          elsif remote_action == :refresh
            action = :refresh
            break
          end
        when :bot_verification
          background_work = true
          verified_snapshot = network_task(_("Checking computer move"), ui: form, silent: true) do
            @synchronizer.synchronize do
              @repository.snapshot_for(@session, force_events: true)
            end
          end
          remember_position.call
          if verified_snapshot == nil
            @bot_turn_controller.defer_verification
          else
            @session = verified_snapshot.session
            verified_revision = @repository.events_revision(verified_snapshot.events)
            confirmation = @bot_turn_controller.observe(
              session_id: @repository.session_id(@session),
              events: verified_snapshot.events,
              confirmed_event_ids: @repository.confirmed_event_ids(@session),
              verified: true
            )
            log_bot_confirmation(confirmation) if ![:idle, :cooldown, :waiting_for_confirmation].include?(confirmation)
            if @last_game_payload != nil
              @last_game_payload = [verified_snapshot, @last_game_payload[1], @last_game_payload[2]]
            end
            if verified_revision != revision
              action = :refresh
              break
            end
          end
          if @bot_turn_controller.ready?(
            session_id: @repository.session_id(@session),
            actor: bot_actor
          )
            action = :bot_ready
            next
          end
        when :bot_ready
          bot_lease = @bot_turn_controller.acquire(
            session_id: @repository.session_id(@session),
            actor: bot_actor,
            revision: revision
          )
          if bot_lease != nil
            bot_token = EltenAPI::Tasks::CancellationToken.new
            action = nil
            restart_bot = true
            break
          end
        else
          break
        end

        if pending_game_refresh
          action = :refresh
          break
        end

        if cancelled_bot
          @bot_turn_controller.cancel(bot_lease)
          bot_lease = nil
          bot_token = nil
          if bot_actor != nil && @bot_turn_controller.ready?(
            session_id: @repository.session_id(@session),
            actor: bot_actor
          )
            action = :bot_ready
            next
          end
        end

        action = nil
        layout.wait_without_announcement
      end
      next if restart_bot

      @latest_wait_replay = replay
      return action
    end
  ensure
    @bot_turn_controller.cancel(bot_lease)
    @layout&.begin_bindings
  end

  def maintenance_action?(action)
    [
      :inline_game_action,
      :check_signal,
      :room_refresh,
      :recovery_refresh,
      :bot_verification,
      :bot_ready
    ].include?(action)
  end

  # Recovery waits until no automatic action or bot calculation is active, so
  # reconnecting cannot interrupt a valid move and strand the current turn.
  def recovery_allowed?(automatic_due, bot_actor)
    !automatic_due && bot_actor == nil
  end

  def normalized_game_shortcuts(shortcuts)
    result = shortcuts.to_a
    if result.any? { |shortcut| !shortcut.is_a?(GameRoomGames::GameShortcut) }
      raise ArgumentError, "a game shortcut must be a GameShortcut"
    end
    keys = result.map { |shortcut| [shortcut.key, shortcut.modifiers.to_a] }
    raise ArgumentError, "game shortcut keys must be unique" if keys.uniq.length != keys.length

    result
  end

  def bind_game_shortcuts(form, fields, shortcuts, &handler)
    shortcut_by_key = shortcuts.group_by(&:key)
    shortcut_signatures = shortcuts.map { |shortcut| [shortcut.key, shortcut.modifiers.to_a] }
    shortcut_keys = shortcut_by_key.keys
    if shortcut_signatures.uniq.length != shortcut_signatures.length
      raise ArgumentError, "game shortcut combinations must be unique"
    end
    fields.each do |field|
      if field.respond_to?(:game_shortcut_signatures=)
        field.game_shortcut_signatures = shortcut_signatures
      elsif field.respond_to?(:game_shortcut_keys=)
        field.game_shortcut_keys = shortcut_keys
      end
      shortcuts.each do |shortcut|
        field.add_tip(
          _("Press %{key} for %{action}.") % {
            key: shortcut_key_label(shortcut),
            action: shortcut.label
          }
        )
      end
    end
    if form.respond_to?(:game_shortcut_signatures=)
      form.game_shortcut_signatures = shortcut_signatures
    elsif form.respond_to?(:game_shortcut_keys=)
      form.game_shortcut_keys = shortcut_keys
    end
    shortcut_by_key.each do |key, candidates|
      form.on(("key_" + key).to_sym) do |parameters|
        shortcut = candidates.find { |candidate| shortcut_modifiers_match?(candidate, parameters) }
        next if shortcut == nil

        consume_game_shortcut_key(key)
        handler.call(shortcut)
      end
    end
  end

  def bind_history_navigation(form, &handler)
    signatures = [
      ["left", [:shift]],
      ["right", [:shift]],
      ["left", [:control]],
      ["right", [:control]],
      ["left", [:control, :shift]],
      ["right", [:control, :shift]]
    ]
    form.history_navigation_signatures = signatures if form.respond_to?(:history_navigation_signatures=)
    {
      left: -1,
      right: 1
    }.each do |key, direction|
      form.on(("key_" + key.to_s).to_sym) do |parameters|
        shift, control, alt = parameters.to_a
        next if alt == true

        operation, value = if shift == true && control == true
          [:jump, direction < 0 ? :first : :last]
        elsif shift == true && control != true
          [:category, direction]
        elsif control == true && shift != true
          [:move, direction]
        end
        next if operation == nil

        consume_game_shortcut_key(key)
        handler.call(operation, value)
      end
    end
  end

  def consume_game_shortcut_key(key)
    getkeychar if key.to_s.length == 1 || key.to_s == "space"
    EltenAPI::KeyboardState.clear_current_frame if defined?(EltenAPI::KeyboardState)
  end

  def activate_game_shortcut(shortcut, surface = nil)
    case shortcut.kind
    when :announcement
      speak(shortcut.message) if !shortcut.message.to_s.empty?
      nil
    when :browse
      browse_shortcut_choices(shortcut)
      nil
    when :number_input
      number_shortcut_action(shortcut)
    when :choice
      choice_shortcut_action(shortcut)
    when :action
      GameSurfaces::Action.new(
        kind: shortcut.action_kind,
        name: shortcut.action_name,
        payload: shortcut.payload,
        source: "shortcut:#{shortcut.key}"
      )
    when :surface
      if surface != nil && surface.respond_to?(:handle_command) &&
          surface.handle_command(shortcut.action_name, shortcut.payload)
        :surface_handled
      end
    else
      raise ArgumentError, "unsupported game shortcut kind: #{shortcut.kind}"
    end
  end

  def refreshed_announcement_shortcut(shortcut, replay, viewer)
    return shortcut if shortcut.kind != :announcement

    normalized_game_shortcuts(@game.game_shortcuts(replay, viewer)).find do |candidate|
      candidate.key == shortcut.key && candidate.modifiers.to_a == shortcut.modifiers.to_a
    end || shortcut
  end

  def shortcut_key_label(shortcut)
    key = shortcut.key.to_s == "space" ? _("Space") : shortcut.key.to_s.upcase
    prefixes = []
    prefixes << _("Ctrl") if shortcut.modifiers.to_a.include?(:control)
    prefixes << _("Alt") if shortcut.modifiers.to_a.include?(:alt)
    prefixes << _("Shift") if shortcut.modifiers.to_a.include?(:shift)
    (prefixes + [key]).join("+")
  end

  def shortcut_modifiers_match?(shortcut, parameters)
    shift, control, alt = parameters.to_a
    active = []
    active << :shift if shift == true
    active << :control if control == true
    active << :alt if alt == true
    active.sort == shortcut.modifiers.to_a.sort
  end

  def number_shortcut_action(shortcut)
    value_text = shortcut.default_value == nil ? "" : shortcut.default_value.to_i.to_s
    loop do
      entered = input_text(
        shortcut.prompt,
        flags: EditBox::Flags::Numbers,
        text: value_text,
        escapable: true,
        select_all: !value_text.empty?
      )
      if entered == nil
        EltenAPI::KeyboardState.clear_current_frame if defined?(EltenAPI::KeyboardState)
        return nil
      end

      value_text = entered.to_s.strip
      value = Integer(value_text, 10) rescue nil
      if value != nil && shortcut.allowed_value?(value)
        return GameSurfaces::Action.new(
          kind: shortcut.action_kind,
          name: shortcut.action_name,
          payload: { shortcut.value_key => value },
          source: "shortcut:#{shortcut.key}"
        )
      end

      allowed = allowed_values_text(shortcut.allowed_values)
      message = shortcut.invalid_message.to_s
      message = _("This value is not allowed.") if message.empty?
      alert(
        _("%{message} Allowed values: %{values}.") % {
          message: message,
          values: allowed
        }
      )
    end
  end

  def choice_shortcut_action(shortcut)
    selected_index = 0
    result = nil
    choices = shortcut.choices.to_a
    list = ListBox.new(
      choices.map(&:label),
      header: shortcut.prompt,
      index: selected_index,
      quiet: true
    )
    select_button = Button.new(_("Select"))
    cancel_button = Button.new(_("Cancel"))
    form = Form.new([list, select_button, cancel_button], quiet: true)
    form.accept_button = select_button
    form.cancel_button = cancel_button
    form.hide(select_button)
    form.hide(cancel_button)
    select_button.on(:press) do
      selected_index = list.index.to_i
      result = choices[selected_index]
      form.resume
    end
    cancel_button.on(:press) { form.resume }
    form.wait
    EltenAPI::KeyboardState.clear_current_frame if defined?(EltenAPI::KeyboardState)
    return nil if result == nil

    GameSurfaces::Action.new(
      kind: shortcut.action_kind,
      name: shortcut.action_name,
      payload: { shortcut.value_key => result.value },
      source: "shortcut:#{shortcut.key}"
    )
  end

  def browse_shortcut_choices(shortcut)
    choices = shortcut.choices.to_a
    list = ListBox.new(
      choices.map(&:label),
      header: shortcut.prompt,
      index: 0,
      quiet: true
    )
    back_button = Button.new(_("Back"))
    form = Form.new([list, back_button], quiet: true)
    form.cancel_button = back_button
    form.hide(back_button)
    back_button.on(:press) { form.resume }
    form.wait
    EltenAPI::KeyboardState.clear_current_frame if defined?(EltenAPI::KeyboardState)
  end

  def allowed_values_text(values)
    normalized = values.to_a.map(&:to_i).uniq.sort
    return normalized.first.to_s if normalized.length == 1

    continuous = normalized == (normalized.first..normalized.last).to_a
    return _("%{minimum} to %{maximum}") % {
      minimum: normalized.first,
      maximum: normalized.last
    } if continuous

    normalized.join(", ")
  end

  def submit_action(replay)
    selection = @selected_surface_action
    @selected_surface_action = nil
    status, plan = @game.action_for(
      selection,
      replay,
      Session.name,
      context: action_context
    )
    if status != :ok
      alert(@game.move_error_for(status, selection: selection, replay: replay, actor: Session.name))
      return false
    end

    recipients = game_recipients
    validate_action_plan!(plan)
    inserted = network_task(_("Sending action")) do
      @repository.append_events(
        session: @session,
        sequence: @repository.next_sequence(@session, replay.accepted_events),
        events: plan.events,
        recipients: recipients,
        actor: Session.name,
        authority: plan.authority
      )
    end
    return false if inserted == nil

    @pending_event_ids = inserted.map { |event| @repository.event_id(event) }
    true
  end

  def submit_inline_action(replay, selection)
    status, plan = @game.action_for(
      selection,
      replay,
      Session.name,
      context: action_context
    )
    if status != :ok
      alert(@game.move_error_for(status, selection: selection, replay: replay, actor: Session.name))
      return nil
    end

    validate_action_plan!(plan)
    inserted = network_task(_("Sending assessment")) do
      @repository.append_events(
        session: @session,
        sequence: @repository.next_sequence(@session, replay.accepted_events),
        events: plan.events,
        recipients: game_recipients,
        actor: Session.name,
        authority: plan.authority
      )
    end
    return nil if inserted == nil

    updated = @game.replay(@session, replay.accepted_events + inserted, @repository)
    accepted_ids = updated.accepted_events.map { |event| @repository.event_id(event) }
    if inserted.any? { |event| !accepted_ids.include?(@repository.event_id(event)) }
      alert(_("The game changed before your action was accepted. Please choose again."))
      return nil
    end
    [updated, inserted]
  end

  def switch_to_new_session
    requested_id = @new_session_id
    @new_session_id = nil
    session = network_task(_("Opening the new game")) do
      @repository.session_by_id(requested_id, table: @table)
    end
    return if session == nil

    @session = session
    @focus_new_game = true
    @bot_turn_controller.switch_session(@repository.session_id(session))
    @synchronizer.update_session(@repository.session_id(session), discard_pending: true).synchronized!
    @surface_state = {}
    @selected_surface_action = nil
    @history_index = 0
    @users_index = 0
    @form_index = 0
    @focus_location = [:game, 0]
    @surface_identity = nil
    @last_seen_event_id = nil
    @turn_history_entries = {}
    @pending_event_ids = []
    @history_follows_tail = true
    @suppress_surface_focus = false
    @latest_wait_replay = nil
    @spoken_timer_announcements = {}
    @last_game_payload = nil
    @clear_chat_after_action = false
    @history_navigator = GameRoomHistory::Navigator.new
  end

  def fetch_room_snapshot
    snapshot = @room_snapshot_provider.call
    return [:closed, nil, []] if snapshot == nil

    [:updated, snapshot, activity_entries_for(snapshot)]
  end

  def apply_room_snapshot(users, history, replay, snapshot, activity_entries)
    if @membership_tracker != nil
      GameRoomSounds.play_all(@program, @membership_tracker.observe(snapshot.members))
    end
    @room_snapshot = snapshot
    @table = snapshot.table
    @table_owner = @table["owner"].to_s
    @activity_entries = activity_entries.to_a
    process_new_table_activity(replay)
    @layout.update_users(room_user_items(replay), header: users_header)
    @layout.update_history(combined_history_items(replay))
    @users_index = users.index.to_i
    @history_index = history.index.to_i
  end

  def remote_game_update(revision)
    latest = @repository.session_for_table(@table)
    latest_id = @repository.session_id(latest)
    current_id = @repository.session_id(@session)
    return [:new_session, latest_id] if latest_id > 0 && latest_id != current_id
    return [:game_cancelled, nil] if @repository.cancelled?(latest || @session)
    return [:refresh, nil] if @repository.event_revision(@session, known_revision: revision) != revision

    [nil, nil]
  end

  def room_user_items(replay)
    return [] if @room_snapshot == nil

    RoomPresentation.game_users(
      room: @room_snapshot, game: @game, replay: replay,
      players: @repository.players_for(@session), owner: @table_owner,
      options: @game.options_from_json(@session["options"])
    )
  end

  def departed_active_competitor(replay)
    return nil if replay == nil || replay.finished? || @room_snapshot == nil
    return nil if !same_user?(@table_owner, Session.name)

    @repository.players_for(@session).find do |participant|
      GameRoomParticipants.human?(participant) &&
        @game.active_competitor?(replay, participant) &&
        !GameRoomParticipants.includes?(@room_snapshot.members, participant)
    end
  end

  def activity_entries_for(snapshot)
    return [] if snapshot == nil || @activity_repository == nil

    @activity_repository.entries_for(snapshot.table, viewer: Session.name)
  end

  def combined_history_entries(replay)
    game_entries = @game.history_entries_for_display(
      replay,
      Session.name,
      surface_state: @surface_state
    )
    if @activity_repository == nil
      return game_entries.map do |entry|
        GameRoomHistory::Entry.new(text: entry.text.to_s, category: :game)
      end
    end

    @activity_repository.merged_history_entries(
      game_entries: game_entries,
      game_events: replay.accepted_events,
      activity_entries: @activity_entries.to_a,
      game_name: @game_name
    )
  end

  def combined_history_items(replay)
    combined_history_entries(replay).map(&:text)
  end

  def refresh_history_control(history, replay)
    @layout.update_history(combined_history_items(replay))
    @history_index = history.index.to_i
  end

  def process_new_table_activity(replay)
    @last_seen_activity_id = @layout.activity_cursor if @last_seen_activity_id == nil && @layout != nil
    newest_id = @activity_entries.to_a.map(&:id).max.to_i
    if @last_seen_activity_id == nil
      @last_seen_activity_id = newest_id
      @layout.activity_cursor = newest_id if @layout != nil
      return
    end

    new_entries = @activity_entries.to_a.select { |entry| entry.id.to_i > @last_seen_activity_id.to_i }
    new_entries.each do |entry|
      next if entry.kind == "chat" && same_user?(entry.actor, Session.name)

      GameRoomSounds.play(@program, "chatmsg") if entry.kind == "chat"
      text = @activity_repository&.text_for(entry, game_name: @game_name, global: false)
      speak(text, stop: false, break_sequence: false) if !text.to_s.empty?
    end
    if !new_entries.empty? && @history_follows_tail
      @history_index = [combined_history_items(replay).length - 1, 0].max
    end
    @last_seen_activity_id = [@last_seen_activity_id.to_i, newest_id].max
    @layout.activity_cursor = @last_seen_activity_id if @layout != nil
  end

  def submit_chat
    pending_message = @pending_chat_message
    @pending_chat_message = nil
    message = (pending_message == nil ? @chat_text : pending_message).to_s.strip
    return if message.empty? || @send_chat == nil

    entry = network_task(_("Sending chat message"), ui: :none) do
      @synchronizer.synchronize do
        @send_chat.call(@table, message, @room_snapshot&.members.to_a)
      end
    end
    return if entry == nil

    @activity_entries ||= []
    @activity_entries << entry if !@activity_entries.any? { |candidate| candidate.id.to_i == entry.id.to_i }
    @activity_entries.sort_by! { |candidate| [candidate.created_at.to_i, candidate.id.to_i] }
    GameRoomSounds.play(@program, "chatmsg")
    text = @activity_repository&.text_for(entry, game_name: @game_name, global: false)
    speak(text, stop: false, break_sequence: false) if !text.to_s.empty?
    clear_chat_draft
  end

  def clear_chat_draft
    @chat_text = ""
    @chat_index = 0
    @chat_check = 0
    if @chat_control != nil
      @chat_control.set_text("")
      @chat_control.index = 0
      @chat_control.check = 0
    end
  end

  def stop_pending_speech
    send(:speech_stop) if respond_to?(:speech_stop, true)
  end

  def synchronize_table_status(replay)
    return if @game_status_changed == nil || !same_user?(@table_owner, Session.name)

    desired = replay.finished? ? "waiting" : "playing"
    return if @table["status"].to_s == desired

    updated = network_task(_("Updating table status"), ui: :none, silent: true) do
      @game_status_changed.call(@table, !replay.finished?)
    end
    return if !updated.is_a?(Hash)

    @table = updated
    @room_snapshot.table = updated if @room_snapshot != nil
  end

  def users_header
    count = @room_snapshot == nil ? 0 : @room_snapshot.participants.length
    _("Users at the table (%{count})") % { count: count }
  end

  def pending_bot_actor(replay)
    return nil if !same_user?(@table_owner, Session.name)

    @bot_coordinator.pending_bot(@game, replay)
  end

  def calculate_bot_decision(replay, form:, cancellation_token:)
    context = action_context
    players = @repository.players_for(@session)
    seed = bot_search_seed(replay)
    bot_task(form: form, cancellation_token: cancellation_token) do
      simulation = GameRoomSimulation::Environment.from_snapshot(
        game: @game,
        session: @session,
        events: replay.accepted_events,
        players: players,
        seed: seed
      )
      @bot_coordinator.decide_next(
        game: @game,
        replay: replay,
        context: context,
        simulation: simulation
      )
    end
  end

  def perform_bot_turn(replay, decision, lease:, form:)
    return false if !same_user?(@table_owner, Session.name)
    return false if decision == nil

    context = action_context
    status, plan = @game.action_for(
      decision.action,
      replay,
      decision.actor,
      context: context
    )
    if status != :ok
      Log.warning("ELTEN Game Room bot chose a rejected action: #{@game.id}, #{status}")
      return false
    end
    validate_action_plan!(plan)
    return false if !@bot_turn_controller.submitting(lease, events: plan.events)

    submission_started_at = monotonic_time
    Log.debug(
      "ELTEN Game Room bot submission started " \
      "table=#{table_id} session=#{@repository.session_id(@session)} " \
      "game=#{@game.id} actor=#{decision.actor} events=#{plan.events.length}"
    )
    inserted = begin
      network_task(_("Computer is moving"), ui: form, silent: true) do
        @repository.append_events(
          session: @session,
          sequence: @repository.next_sequence(@session, replay.accepted_events),
          events: plan.events,
          recipients: game_recipients,
          actor: decision.actor,
          authority: plan.authority
        )
      end
    rescue Exception
      @bot_turn_controller.submission_failed(lease)
      raise
    end
    Log.debug(
      "ELTEN Game Room bot submission finished " \
      "table=#{table_id} session=#{@repository.session_id(@session)} " \
      "actor=#{decision.actor} elapsed_ms=#{((monotonic_time - submission_started_at) * 1_000).round(1)} " \
      "inserted=#{inserted == nil ? 0 : inserted.length}"
    )
    if inserted == nil
      @bot_turn_controller.submission_failed(lease)
      Log.warning(
        "ELTEN Game Room bot submission is uncertain; waiting for server state " \
        "table=#{table_id} session=#{@repository.session_id(@session)} actor=#{decision.actor}"
      )
      return false
    end

    event_ids = inserted.map { |event| @repository.event_id(event) }
    @pending_event_ids = event_ids
    @bot_turn_controller.submitted(lease, event_ids: event_ids)
    true
  end

  def log_bot_confirmation(result)
    Log.debug(
      "ELTEN Game Room bot confirmation " \
      "table=#{table_id} session=#{@repository.session_id(@session)} result=#{result}"
    )
  end

  def perform_automatic_action(replay)
    return false if !@game.automatic_action_allowed?(
      replay,
      Session.name,
      table_owner: @table_owner
    )

    context = action_context
    selection = @game.automatic_action(replay, Session.name, context: context)
    return false if selection == nil

    status, plan = @game.action_for(
      selection,
      replay,
      Session.name,
      context: context
    )
    if status != :ok
      Log.warning("ELTEN Game Room automatic action was rejected: #{@game.id}, #{status}")
      return false
    end
    validate_action_plan!(plan)

    inserted = network_task(_("Preparing the next round")) do
      @repository.append_events(
        session: @session,
        sequence: @repository.next_sequence(@session, replay.accepted_events),
        events: plan.events,
        recipients: game_recipients,
        actor: Session.name,
        authority: plan.authority
      )
    end
    return false if inserted == nil

    @pending_event_ids = inserted.map { |event| @repository.event_id(event) }
    true
  end

  def automatic_action_due?(replay)
    return false if !@game.automatic_action_allowed?(
      replay,
      Session.name,
      table_owner: @table_owner
    )

    @game.automatic_action_due?(replay, Session.name, context: action_context)
  rescue StandardError => error
    Log.warning("ELTEN Game Room automatic-action deadline check failed: #{error.class}: #{error.message}")
    false
  end

  def action_context
    GameRoomGames::ActionContext.new(
      session_id: @repository.session_id(@session),
      table_id: table_id,
      hidden_submissions: @hidden_submissions,
      random_source: @random_source,
      now: Time.now.to_i,
      table_owner: @table_owner
    )
  end

  def bot_search_seed(replay)
    session = @repository.session_id(@session).to_i
    latest_event = replay.accepted_events.map { |event| @repository.event_id(event) }.max.to_i
    session * 1_000_003 + latest_event * 97 + replay.accepted_events.length
  end

  def game_recipients
    participants = if @room_snapshot == nil
      @repository.players_for(@session)
    else
      @room_snapshot.members
    end
    GameRoomParticipants.humans(participants)
  end

  def validate_action_plan!(plan)
    if !plan.is_a?(GameRoomGames::ActionPlan) || plan.events.to_a.empty?
      raise ArgumentError, "a successful game action must return an ActionPlan"
    end
  end

  def same_user?(first, second)
    GameRoomParticipants.same?(first, second)
  end

  def table_id
    (@table["__id"] || @table["id"]).to_i
  end

  def process_new_events(replay, signal_received_at: nil)
    newest_id = replay.accepted_events.map { |event| @repository.event_id(event) }.max.to_i
    if @last_seen_event_id == nil
      @last_seen_event_id = newest_id
      @history_index = [combined_history_items(replay).length - 1, 0].max
      return
    end

    new_events = replay.accepted_events.select do |event|
      @repository.event_id(event) > @last_seen_event_id
    end
    event_replays = event_replays_for(replay, new_events)
    new_events.each do |event|
      event_id = @repository.event_id(event)

      before_replay, after_replay = event_replays.fetch(event_id, [nil, replay])
      turn_entry = remember_turn_transition(before_replay, after_replay, event_id)
      GameRoomSounds.play_event(
        @program,
        game: @game,
        event: event,
        before_replay: before_replay,
        after_replay: after_replay,
        repository: @repository,
        viewer: Session.name
      )

      descriptions = normalize_event_descriptions(
        @game.describe_event_for_display(
          event,
          @repository,
          replay,
          Session.name,
          surface_state: @surface_state
        )
      )
      descriptions.each_with_index do |description, index|
        log_signal_timing(
          "speech_queued",
          signal_received_at,
          details: "event_id=#{event_id} item=#{index + 1}/#{descriptions.length}"
        )
        speak(description, stop: false, break_sequence: false)
      end
      if turn_entry != nil
        turn_message = @game.turn_announcement(after_replay, Session.name)
        speak(turn_message, stop: false, break_sequence: false) if !turn_message.to_s.empty?
      end
    end
    merge_turn_history!(replay)
    if newest_id > @last_seen_event_id
      result = @game.result_text(replay)
      if result != nil
        log_signal_timing("result_speech_queued", signal_received_at)
        speak(result, stop: false, break_sequence: false)
      end
      @history_index = [combined_history_items(replay).length - 1, 0].max if @history_follows_tail
    end
    @last_seen_event_id = [@last_seen_event_id, newest_id].max
  end

  def event_replays_for(replay, new_events)
    return {} if new_events.empty?

    first_event = new_events.first
    first_index = replay.accepted_events.index(first_event).to_i
    prefix = replay.accepted_events[0...first_index]
    before = @game.replay(@session, prefix, @repository)
    new_events.each_with_object({}) do |event, result|
      prefix << event
      after = incremental_event_replay(before, event)
      after ||= @game.replay(@session, prefix, @repository)
      result[@repository.event_id(event)] = [before, after]
      before = after
    end
  rescue Exception => error
    Log.warning("ELTEN Game Room could not reconstruct sound events: #{error.class}: #{error.message}") if defined?(Log)
    {}
  end

  def incremental_event_replay(before_replay, event)
    implementation = @game.method(:incremental_replay)
    return nil if implementation.owner == GameRoomGames::Base

    # Planner-oriented incremental replay mutates its argument. Preserve the
    # before state because turn detection and sound selection need both sides
    # of the transition.
    copy = Marshal.load(Marshal.dump(before_replay))
    @game.incremental_replay(copy, @session, [event], @repository)
  rescue StandardError
    nil
  end

  def remember_turn_transition(before_replay, after_replay, event_id)
    entry = @game.turn_transition_history_entry(
      before_replay,
      after_replay,
      event_id: event_id
    )
    @turn_history_entries[entry.event_id.to_i] = entry if entry != nil
    entry
  rescue StandardError => error
    Log.warning("ELTEN Game Room turn transition failed: #{error.class}: #{error.message}") if defined?(Log)
    nil
  end

  def merge_turn_history!(replay)
    return replay if replay == nil || @turn_history_entries.empty?

    source = replay.history.reject { |entry| entry.kind == :turn }
    pending = @turn_history_entries.dup
    pending_ids = pending.keys.sort
    pending_index = 0
    merged = []
    source.each_with_index do |entry, index|
      event_id = entry.event_id.to_i
      while pending_index < pending_ids.length && pending_ids[pending_index] < event_id
        pending_id = pending_ids[pending_index]
        merged << pending.delete(pending_id) if pending.key?(pending_id)
        pending_index += 1
      end

      merged << entry
      next_event_id = source[index + 1]&.event_id&.to_i
      if next_event_id != event_id && pending.key?(event_id)
        merged << pending.delete(event_id)
        pending_index += 1 if pending_ids[pending_index] == event_id
      end
    end
    while pending_index < pending_ids.length
      pending_id = pending_ids[pending_index]
      merged << pending[pending_id] if pending.key?(pending_id)
      pending_index += 1
    end
    replay.history = merged
    replay
  end

  def normalize_event_descriptions(description)
    Array(description).compact.map(&:to_s).reject(&:empty?)
  end

  def announce_due_timers(replay)
    @game.timer_announcements(replay, Session.name, now: Time.now.to_i).to_a.each do |announcement|
      key, message = announcement.to_a
      next if key.to_s.empty? || message.to_s.empty? || @spoken_timer_announcements[key.to_s]

      @spoken_timer_announcements[key.to_s] = true
      speak(message.to_s, stop: false, break_sequence: false)
    end
  rescue StandardError => error
    Log.warning("ELTEN Game Room timer announcement failed: #{error.class}: #{error.message}") if defined?(Log)
  end

  def verify_pending_move(replay)
    return if @pending_event_ids.empty?

    accepted_ids = replay.accepted_events.map { |event| @repository.event_id(event) }
    accepted = @pending_event_ids.all? { |event_id| accepted_ids.include?(event_id) }
    alert(_("The game changed before your action was accepted. Please choose again.")) if !accepted
    @pending_event_ids = []
  end

  def network_task(title, ui: nil, silent: false, &operation)
    options = { title: title, cancellable: true, show_after: 5.0 }
    options[:ui] = ui if ui != nil
    EltenAPI::Tasks.run(**options) do |progress, token|
      token.raise_if_cancelled!
      operation.call
    end
  rescue EltenAPI::Tasks::Cancelled
    nil
  rescue EltenLink::Error => error
    Log.warning("ELTEN Game Room network operation failed: #{error.class}: #{error.message}")
    alert(_("The operation could not be completed. Please try again.")) if !silent
    nil
  end

  def synchronized_network_task(title, ui: :none, &operation)
    network_task(title, ui: ui, silent: true) do
      @synchronizer.synchronize(&operation)
    end
  end

  def refresh_input_ui
    return :none if @chat_control == nil
    return :none if @focus_location.to_a[0]&.to_sym != :chat

    @chat_control
  end

  # Bot policies may perform a complete-round search. The worker calculates the
  # decision while Tasks.run keeps the owned game form active, so navigation,
  # informational shortcuts, speech and audio continue during the search.
  def bot_task(form:, cancellation_token:, &operation)
    EltenAPI::Tasks.run(
      title: _("Computer is thinking"),
      ui: form,
      cancellable: false,
      cancellation_token: cancellation_token,
      &operation
    )
  end

  def cancel_bot_decision(token, reason)
    return false if token == nil

    Log.debug(
      "ELTEN Game Room bot cancellation requested " \
      "table=#{table_id} session=#{@repository.session_id(@session)} reason=#{reason}"
    )
    token.cancel
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  rescue Exception
    Time.now.to_f
  end

  def log_signal_timing(stage, signal_received_at, stage_started_at: nil, details: nil)
    return if signal_received_at == nil

    now = monotonic_time
    fields = [
      "ELTEN Game Room timing",
      "stage=#{stage}",
      "signal_to_stage_ms=#{((now - signal_received_at.to_f) * 1_000).round(1)}"
    ]
    if stage_started_at != nil
      fields << "stage_ms=#{((now - stage_started_at.to_f) * 1_000).round(1)}"
    end
    fields << details.to_s if details != nil && !details.to_s.empty?
    Log.debug(fields.join(" "))
  end

  def bounded_index(index, items)
    return 0 if items.empty?

    [[index.to_i, 0].max, items.length - 1].min
  end
end
