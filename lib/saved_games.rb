require "json"
require "digest"
require "securerandom"
require_relative "game_participants"
require_relative "live_session_store"

# Local archives contain JSON and the confirmed event log, never executable
# Ruby/Marshal data or the UI's private controls. Replay remains the rule engine.
class SavedGames
  FORMAT = 1
  PATH = "saved_games.json".freeze
  MAX_EVENTS = GameRoomLiveSessionStore::MAX_ARCHIVE_EVENTS

  class ReplayRepository
    def players_for(session); session["__players"]; end
    def event_id(event); event["id"]; end
    def actor_of(event, _session = nil); event["actor"]; end
  end

  def initialize(program, owner:)
    @program, @owner = program, owner.to_s
  end

  def list
    state = @program.read_json(PATH, default: {})
    raise ArgumentError, "Invalid saved game storage" unless state.is_a?(Hash)
    games = state.fetch("games", {})
    raise ArgumentError, "Invalid saved game storage" unless games.is_a?(Hash) && games.values.all? { |row| row.is_a?(Hash) }
    rows = games.values.select { |row| GameRoomParticipants.same?(row["owner"], @owner) }
    raise ArgumentError, "Invalid saved game storage" unless rows.all? do |row|
      row["id"].is_a?(String) && row["game"].is_a?(String) && row["saved_at"].is_a?(Integer) && row["saved_at"] > 0 &&
        row["players"].is_a?(Array) && row["players"].all? { |player| player.is_a?(String) }
    end
    rows.sort_by { |row| -row["saved_at"] }
  end

  def put(game:, table:, snapshot:, repository:, now: Time.now.to_i)
    raise ArgumentError, "Unsupported saved game" unless game.supports_saved_games?
    raise ArgumentError, "Only the founder may save the game" unless GameRoomParticipants.same?(table["owner"], @owner)
    replay = game.replay(snapshot.session, snapshot.events, repository)
    error = game.save_game_error(replay)
    raise ArgumentError, error if error != nil
    row = {
      "format" => FORMAT, "game_schema" => game.saved_game_schema_version,
      "id" => SecureRandom.uuid, "owner" => @owner, "saved_at" => now.to_i,
      "game" => game.id, "table_name" => table["name"].to_s, "private" => table["private"] == true,
      "players" => repository.players_for(snapshot.session), "options" => snapshot.session["options"].to_s,
      "game_time" => now.to_i - snapshot.session["__clock_offset"].to_i,
      "events" => replay.accepted_events.map do |event|
        { "id" => repository.event_id(event), "sequence" => event["sequence"].to_i,
          "actor" => repository.actor_of(event, snapshot.session), "action" => event["action"].to_s,
          "value" => event["value"].to_s, "created_at" => event["created_at"].to_i }
      end
    }
    row["checksum"] = checksum(row)
    validate(row, game: game)
    @program.update_json(PATH, default: {}) do |root|
      raise ArgumentError, "Invalid saved game storage" unless root.is_a?(Hash) && (!root.key?("games") || root["games"].is_a?(Hash))
      root["games"] ||= {}
      root["games"][row["id"]] = row
    end
    persisted = list.find { |saved| saved["id"] == row["id"] }
    raise IOError, "The saved game could not be verified on disk" unless persisted == row
    row
  end

  def delete(id)
    @program.update_json(PATH, default: {}) do |root|
      raise ArgumentError, "Invalid saved game storage" unless root.is_a?(Hash) && (!root.key?("games") || root["games"].is_a?(Hash))
      row = root.fetch("games", {})[id.to_s]
      root["games"].delete(id.to_s) if row && GameRoomParticipants.same?(row["owner"], @owner)
    end
  end

  def validate(row, game:)
    raise ArgumentError, "Unsupported saved game" if game == nil || !game.supports_saved_games?
    raise ArgumentError, "Incompatible saved game" unless row.is_a?(Hash) && row["format"] == FORMAT &&
      row["game"] == game.id && row["game_schema"] == game.saved_game_schema_version &&
      GameRoomParticipants.same?(row["owner"], @owner) && row["checksum"] == checksum(row)
    players = row["players"]
    raise ArgumentError, "Invalid saved seats" unless players.is_a?(Array) && players.length.between?(game.minimum_players, game.maximum_players) &&
      players.all? { |player| player.is_a?(String) && player.length.between?(1, 64) } && GameRoomParticipants.unique(players).length == players.length &&
      GameRoomParticipants.same?(players.first, @owner)
    raise ArgumentError, "Invalid saved game time" unless row["saved_at"].is_a?(Integer) && row["saved_at"] > 0 && row["game_time"].is_a?(Integer) && row["game_time"] > 0
    options = JSON.parse(row.fetch("options"))
    raise ArgumentError, "Invalid saved rules" unless options.is_a?(Hash) && game.validation_error(options, player_count: players.length) == nil
    events = row["events"]
    raise ArgumentError, "Invalid saved events" unless events.is_a?(Array)
    raise ArgumentError, "The saved game is too large to restore safely" if events.length > MAX_EVENTS
    last_id = 0
    events.each do |event|
      raise ArgumentError, "Invalid saved event" unless event.is_a?(Hash) && event["id"].is_a?(Integer) && event["id"] > last_id &&
        event["sequence"].is_a?(Integer) && event["sequence"] >= 0 && GameRoomParticipants.includes?(players, event["actor"]) &&
        event["action"].is_a?(String) && event["action"].length.between?(1, 32) && event["value"].is_a?(String) && event["value"].length <= 64 &&
        event["created_at"].is_a?(Integer) && event["created_at"] >= 0
      last_id = event["id"]
    end
    replay = game.replay({ "__players" => players, "options" => row["options"] }, events, ReplayRepository.new)
    raise ArgumentError, "Incompatible saved game events" unless replay.accepted_events.length == events.length
    error = game.save_game_error(replay)
    raise ArgumentError, error if error != nil
    row
  rescue JSON::ParserError, KeyError, TypeError
    raise ArgumentError, "Invalid saved game data"
  end

  def restored_data(row, game:, table_id:, now: Time.now.to_i)
    bot_number = 0
    mapping = row["players"].to_h do |player|
      replacement = if GameRoomParticipants.bot?(player)
        bot_number += 1
        GameRoomParticipants.bot_id(table_id, bot_number, name_token: GameRoomParticipants.bot_name_token(player))
      else
        player
      end
      [player.downcase, replacement]
    end
    restored = {
      players: row["players"].map { |player| mapping.fetch(player.downcase) },
      events: row["events"].map { |event| event.merge("actor" => mapping.fetch(event["actor"].downcase), "value" => game.restored_event_value(event, mapping)) },
      clock_offset: now.to_i - row["game_time"].to_i, game_time: row["game_time"].to_i
    }
    replay = game.replay({ "__players" => restored[:players], "options" => row["options"] }, restored[:events], ReplayRepository.new)
    raise ArgumentError, "Incompatible saved game seats" unless replay.accepted_events.length == row["events"].length
    restored
  end

  private

  def checksum(row)
    Digest::SHA256.hexdigest(JSON.generate(row.reject { |key, _value| key == "checksum" }))
  end
end
