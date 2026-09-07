require_relative "game_participants"

module GameRoomLifecycle
  class State
    PHASES = [:waiting, :active, :finished, :unavailable].freeze

    attr_reader :room, :game_snapshot, :game, :replay, :players, :activity_entries

    def initialize(room:, game_snapshot:, game:, replay:, players: [], activity_entries: [])
      raise ArgumentError, "a lifecycle state requires a room snapshot" if room == nil

      @room = room
      @game_snapshot = game_snapshot
      @game = game
      @replay = replay
      @players = GameRoomParticipants.unique(players)
      @activity_entries = activity_entries.to_a
    end

    def phase
      return :waiting if @game_snapshot == nil
      return :unavailable if @game == nil || @replay == nil

      @replay.finished? ? :finished : :active
    end

    def waiting?
      phase == :waiting
    end

    def active?
      phase == :active
    end

    def finished?
      phase == :finished
    end

    def available?
      phase != :unavailable
    end

    def session
      @game_snapshot == nil ? nil : @game_snapshot.session
    end

    def session_id(repository)
      repository.session_id(session)
    end

    def history
      @replay == nil ? [] : @replay.history.to_a
    end

    def player?(user)
      @players.any? { |player| GameRoomParticipants.same?(player, user) }
    end

    def role_for(user)
      return player?(user) ? :player : :observer if active?

      :waiting
    end

    def startable_by?(user, owner:)
      available? && !active? && GameRoomParticipants.same?(user, owner)
    end
  end
end
