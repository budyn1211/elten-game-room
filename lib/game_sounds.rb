require_relative "game_participants"

module GameRoomSounds
  ASSET_NAMES = %w[
    connect
    disconnect
    chatmsg
    ding
    shuffle
    draw
    draw2
    farkle
    lose1
    lose3
    play
    play2
    replay
    reverse
    reverse3
    roll
    win1
    win2
  ].freeze

  class MembershipTracker
    def initialize
      @members = nil
    end

    def observe(members)
      current = normalized_members(members)
      if @members == nil
        @members = current
        return []
      end

      joined = current.keys - @members.keys
      left = @members.keys - current.keys
      @members = current
      Array.new(joined.length, "connect") + Array.new(left.length, "disconnect")
    end

    private

    def normalized_members(members)
      GameRoomParticipants.humans(members).each_with_object({}) do |member, result|
        result[member.to_s.downcase] = member.to_s
      end
    end
  end

  module_function

  def play(program, name)
    return nil if name == nil || !ASSET_NAMES.include?(name.to_s)

    program.play_sound_from_asset(name.to_s)
  rescue Exception => error
    Log.warning("ELTEN Game Room sound #{name} failed: #{error.class}: #{error.message}") if defined?(Log)
    nil
  end

  def play_all(program, names)
    names.to_a.each { |name| play(program, name) }
  end

  def play_event(program, **event_data)
    play_all(program, Array(event_cue(**event_data)))
  rescue Exception => error
    Log.warning("ELTEN Game Room event sound failed: #{error.class}: #{error.message}") if defined?(Log)
    nil
  end

  # One event receives one primary sound. A special sound replaces the generic
  # card or piece sound, which prevents overlapping effects for the same move.
  def event_cue(game:, event:, before_replay:, after_replay:, repository:, viewer:)
    result = result_cue(game, before_replay, after_replay, viewer)
    return result if result != nil

    action = event["action"].to_s
    case game.id.to_s
    when "spades"
      return "shuffle" if action == "deal"
      return nil if action != "play"

      event["value"].to_s.end_with?("S") ? "draw2" : "play"
    when "tysiac"
      return "shuffle" if action == "deal"
      return nil if action != "play"

      _mode, card = event["value"].to_s.split("|", 2)
      trump = after_replay&.state.to_h[:trump].to_s
      !trump.empty? && card.to_s.end_with?(trump) ? "draw2" : "play"
    when "ninety_nine"
      ninety_nine_cue(event, before_replay, after_replay, viewer)
    when "farkle"
      farkle_cue(event, before_replay, after_replay, repository)
    when "four_in_a_row"
      action == "drop" ? "play2" : nil
    when "tic_tac_toe"
      action == "place" ? "play2" : nil
    when "chess", "checkers"
      action == "move" ? "play2" : nil
    when "reversi"
      action == "place" ? "play2" : nil
    when "ludo"
      if action == "roll"
        moved_automatically = history_for_event(after_replay, event, repository).any? { |entry| entry.kind == :move }
        return moved_automatically ? ["roll", "play2"] : "roll"
      end

      ["move", "move_pawn"].include?(action) ? "play2" : nil
    end
  end

  def result_cue(game, before_replay, after_replay, viewer)
    return nil if after_replay == nil || !after_replay.finished?
    return nil if before_replay != nil && before_replay.finished?
    return nil if after_replay.winner == nil
    return nil if !GameRoomParticipants.includes?(after_replay.players, viewer)

    game.bot_reward(after_replay, viewer).to_f > 0 ? "win2" : "lose3"
  rescue StandardError
    GameRoomParticipants.same?(after_replay.winner, viewer) ? "win2" : "lose3"
  end

  def ninety_nine_cue(event, before_replay, after_replay, viewer)
    action = event["action"].to_s
    return "shuffle" if action == "deal"
    return "draw" if action == "draw"
    return nil if !["play", "play_draw"].include?(action)

    previous_total = before_replay&.state.to_h.fetch(:total, 0).to_i
    current_total = after_replay&.state.to_h.fetch(:total, previous_total).to_i
    viewer_played = GameRoomParticipants.same?(event["actor"], viewer)
    primary = if current_total == 99
      viewer_played ? "win1" : "lose1"
    elsif current_total > 99
      viewer_played ? "lose1" : "win1"
    elsif [33, 66].any? { |limit| previous_total < limit && current_total > limit }
      "draw2"
    else
      card, _mode = event["value"].to_s.split("|", 2)
      rank = card.to_s[1]
      if rank == "J"
        "reverse"
      elsif rank == "4" && before_replay&.state.to_h.fetch(:eliminated, {}).count { |_player, eliminated| !eliminated } >= 3
        "reverse3"
      else
        "play"
      end
    end

    action == "play_draw" ? [primary, "draw"] : primary
  end

  def farkle_cue(event, before_replay, after_replay, repository)
    action = event["action"].to_s
    if action == "roll"
      return "farkle" if history_for_event(after_replay, event, repository).any? { |entry| entry.kind == :farkle }

      return "roll"
    end
    return nil if action != "keep"

    kept_count = event["value"].to_s.split(",").reject(&:empty?).length
    dice_before = before_replay&.state.to_h.fetch(:dice_to_roll, 0).to_i
    kept_count > 0 && kept_count == dice_before ? "replay" : nil
  end

  def history_for_event(replay, event, repository)
    event_id = repository.event_id(event).to_i
    replay.to_h.fetch(:history, []).to_a.select { |entry| entry.event_id.to_i == event_id }
  end
end
