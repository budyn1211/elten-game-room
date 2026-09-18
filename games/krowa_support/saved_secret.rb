require_relative "../../lib/hidden_submissions"

module GameRoomGames
  module KrowaSavedSecret
    def saved_game_requires_private_data?; true; end
    def saved_private_data(replay, context:)
      secret = context.hidden_submissions.reveal(session_id: context.session_id,
        round_id: "krowa:#{replay.state[:round]}", user: replay.players.first,
        commitment: replay.state[:commitment])
      raise IOError, "The current secret could not be read" unless secret
      data = {"version" => 1, "round" => replay.state[:round], "payload" => secret.payload,
        "nonce" => secret.nonce, "commitment" => secret.commitment}
      validate_saved_private_data(replay, data)
      data
    end

    def validate_saved_private_data(replay, data)
      raise ArgumentError, "Invalid private Krowa archive" unless data.is_a?(Hash) &&
        data.keys.sort == %w[commitment nonce payload round version] &&
        data["version"] == 1 && data["round"] == replay.state[:round] &&
        data["commitment"] == replay.state[:commitment] &&
        data["nonce"].is_a?(String) && /\A[0-9a-f]{64}\z/.match?(data["nonce"]) &&
        data["payload"].is_a?(Hash) && data["payload"].keys.sort == %w[day word] &&
        data["payload"]["day"] == replay.state[:day] &&
        data["payload"]["word"].is_a?(String) &&
        data["payload"]["word"].length == replay.state[:length] &&
        @bank.include?(data["payload"]["word"]) &&
        HiddenSubmissions::Commitment.valid?(payload: data["payload"], nonce: data["nonce"],
          commitment: data["commitment"]) &&
        replay.state[:attempts].all? { |trial| @bank.matches(trial[:word], data["payload"]["word"]) == trial[:matches] }
      true
    end

    def restore_private_data(replay, data, context:)
      validate_saved_private_data(replay, data)
      context.hidden_submissions.prepare(session_id: context.session_id,
        round_id: "krowa:#{replay.state[:round]}", user: replay.players.first,
        payload: data.fetch("payload"), nonce: data.fetch("nonce"))
      restored = saved_private_data(replay, context: context)
      raise IOError, "Restored Krowa secret could not be verified" unless restored == data
      true
    end
  end
end
