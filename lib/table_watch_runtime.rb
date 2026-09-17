require_relative "table_watch"

module GameRoomTableWatchRuntime
  def table_watch_repository
    GameRoomTableWatch::Preferences.new(
      EltenLink::Apps.table(EltenLink::Client.new, server_app_uuid, GameRoomTableWatch::TABLE), games: self::GAME_REGISTRY.ids)
  end

  def table_watch_receiver
    user = Session.name.to_s
    if !@table_watch_receiver || !@table_watch_receiver.user.casecmp?(user)
      @table_watch_sender&.close
      @table_watch_sender = nil
      @table_watch_loader&.close
      @table_watch_loader = nil
      @table_watch_pruned = {}
      @table_watch_clock = GameRoomTableWatch::Clock.new
      data = begin
        respond_to?(:read_json) ? read_json("table-notice-receipts.json", default: {}) : {}
      rescue StandardError => error
        Log.warning("Game Room table receipts could not be read: #{error.class}") if defined?(Log)
        {}
      end
      @table_watch_receiver = GameRoomTableWatch::Receiver.new(user: user, games: self::GAME_REGISTRY.ids,
        uuid: server_app_uuid, clock: @table_watch_clock,
        stored: data.is_a?(Hash) ? data[user.downcase] || {} : {}, persist: ->(value) {
          if respond_to?(:update_json)
            update_json("table-notice-receipts.json", default: {}) do |state|
              state = {} unless state.is_a?(Hash)
              state[user.downcase] = value
              state
            end
          end
        })
    end
    @table_watch_receiver
  end

  def table_watch_start
    receiver = table_watch_receiver
    return if @table_watch_loader || receiver.games != nil || receiver.user.empty?
    runtime = Programs.current_runtime if defined?(Programs) && Programs.respond_to?(:current_runtime)
    @table_watch_loader = GameRoomBackground::Work.new(runtime: runtime)
    user = receiver.user
    @table_watch_loader.start { table_watch_repository.load(user) }
  end

  def table_watch_set_games(games)
    @table_watch_loader&.close
    @table_watch_loader = nil
    table_watch_receiver.games = games
  end

  def table_watch_tick
    receiver = table_watch_receiver
    table_watch_start
    if @table_watch_loader && (result = @table_watch_loader.take)
      games, error = result
      receiver.games = games unless error
      # One attempt per startup, not a background preference poll. Opening
      # Settings retries explicitly; no failed read can overwrite the server.
      Log.warning("Game Room watched games could not be loaded: #{error.class}") if error && defined?(Log)
    end
    @table_watch_sender&.tick
    if defined?(EltenAPI::NotificationService) && EltenAPI::NotificationService.respond_to?(:active_notifications)
      ids = EltenAPI::NotificationService.active_notifications.filter_map do |row|
        next unless row.cat.to_s == "app" && row.app_uuid.to_s.casecmp?(server_app_uuid.to_s)
        notification = Programs.app_notification_from(row)
        next unless notification.type.to_s == GameRoomTableWatch::TYPE
        next if receiver.visible?(notification) || @table_watch_pruned[row.id.to_i]
        @table_watch_pruned[row.id.to_i] = true
        row.id.to_i
      end
      # Only this new type; never change the deferred invitation expiration.
      EltenAPI::NotificationService.revoke_active_notifications(ids) unless ids.empty?
      @table_watch_pruned = @table_watch_pruned.to_a.last(2048).to_h
    end
  rescue StandardError => error
    Log.warning("Game Room table notification update failed: #{error.class}") if defined?(Log)
  end

  def table_watch_stop
    @table_watch_sender&.close
    @table_watch_loader&.close
    @table_watch_sender = nil
    @table_watch_loader = nil
  end

  def announce_new_public_table(row)
    receiver = table_watch_receiver
    @table_watch_sender ||= begin
      client = EltenLink::Client.new
      GameRoomTableWatch::Sender.new(user: receiver.user, repository: table_watch_repository,
        clock: @table_watch_clock,
        online: -> { EltenLink::Users.online(client) }, send_notice: ->(user, metadata, expires) {
          EltenLink::Apps.notify(client, appid: server_app_uuid, user: user, type: GameRoomTableWatch::TYPE,
            metadata: metadata, expires_in: expires) if expires > 0
        })
    end
    @table_watch_sender.enqueue(row)
  rescue StandardError => error
    Log.warning("Game Room new table notice could not be queued: #{error.class}") if defined?(Log)
  end

  def cancel_new_table_notice(row)
    @table_watch_sender&.cancel(row.to_h["__live_session_id"])
  end

  def table_notice_visible?(notification)
    table_watch_receiver.visible?(notification)
  end
end
