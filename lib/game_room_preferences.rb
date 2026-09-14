module GameRoomPreferences
  INVITATION_POLICIES = %w[contacts nobody everyone].freeze
  ROOM_SOUND_NAMES = %w[connect disconnect].freeze

  module_function

  def defaults(game_ids)
    games = normalized_game_ids(game_ids)
    {
      "announce_lobby_changes" => true,
      "announce_table_created" => true,
      "announce_player_joined" => true,
      "announce_player_left" => true,
      "announce_computer_changes" => true,
      "lobby_games" => games,
      "invitation_notifications" => "everyone",
      "game_sounds" => true,
      "room_membership_sounds" => true,
      "chat_sounds" => true,
      "invitation_sounds" => true,
      "widget_enabled" => true,
      "widget_games" => games.dup,
      "widget_show_unavailable" => false
    }
  end

  def normalize(values, game_ids)
    source = values.is_a?(Hash) ? values : {}
    result = defaults(game_ids)
    source.each { |key, value| result[key.to_s] = duplicate(value) }

    legacy = source["announce_lobby_changes"] != false
    %w[
      announce_table_created
      announce_player_joined
      announce_player_left
      announce_computer_changes
    ].each do |key|
      result[key] = legacy if !source.key?(key)
      result[key] = result[key] != false
    end
    result["announce_lobby_changes"] = %w[
      announce_table_created
      announce_player_joined
      announce_player_left
      announce_computer_changes
    ].any? { |key| result[key] }

    allowed_games = normalized_game_ids(game_ids)
    result["lobby_games"] = selected_games(source, "lobby_games", allowed_games)
    result["widget_games"] = selected_games(source, "widget_games", allowed_games)
    result["invitation_notifications"] = normalized_invitation_policy(result["invitation_notifications"])
    %w[
      game_sounds
      room_membership_sounds
      chat_sounds
      invitation_sounds
      widget_enabled
      widget_show_unavailable
    ].each { |key| result[key] = result[key] != false }
    result
  end

  def lobby_announcement_enabled?(values, kind, game_id, game_ids)
    settings = normalize(values, game_ids)
    key = case kind.to_s
    when "created" then "announce_table_created"
    when "joined" then "announce_player_joined"
    when "left" then "announce_player_left"
    when "bot_added", "bot_removed" then "announce_computer_changes"
    end
    return false if key == nil || !settings[key]

    settings["lobby_games"].include?(game_id.to_s)
  end

  def sound_enabled?(values, name, game_ids = [])
    settings = normalize(values, game_ids)
    sound = name.to_s
    return settings["chat_sounds"] if sound == "chatmsg"
    return settings["room_membership_sounds"] if ROOM_SOUND_NAMES.include?(sound)

    settings["game_sounds"]
  end

  def widget_enabled?(values, game_ids)
    normalize(values, game_ids)["widget_enabled"]
  end

  def widget_game_enabled?(values, game_id, game_ids)
    normalize(values, game_ids)["widget_games"].include?(game_id.to_s)
  end

  def normalized_invitation_policy(value)
    policy = value.to_s
    INVITATION_POLICIES.include?(policy) ? policy : "everyone"
  end

  def normalized_game_ids(game_ids)
    game_ids.to_a.map(&:to_s).reject(&:empty?).uniq
  end

  def selected_games(source, key, allowed)
    return allowed.dup if !source.key?(key)

    requested = source[key].to_a.map(&:to_s)
    allowed.select { |game_id| requested.include?(game_id) }
  end
  private_class_method :selected_games

  def duplicate(value)
    value.is_a?(Array) || value.is_a?(Hash) ? value.dup : value
  end
  private_class_method :duplicate
end
