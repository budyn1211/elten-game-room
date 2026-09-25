require_relative 'saved_game_archive'

# Historical local storage. Explicit tools/tests only; the app uses AccountSavedGames.
class SavedGames < GameRoomSavedGameArchive
  PATH = "saved_games.json".freeze

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

  def fetch(id)
    list.find { |row| row["id"] == id.to_s }
  end

  def persist(row)
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

end
