module GameRoomParticipants
  BOT_PREFIX = "bot:".freeze
  BOT_PATTERN = /\Abot:(\d+):(\d+)\z/

  module_function

  def bot_id(table_id, number)
    table = table_id.to_i
    index = number.to_i
    raise ArgumentError, "a bot requires a table id" if table <= 0
    raise ArgumentError, "a bot number must be positive" if index <= 0

    "#{BOT_PREFIX}#{table}:#{index}"
  end

  def bots_for(table_id, count)
    Array.new([count.to_i, 0].max) { |index| bot_id(table_id, index + 1) }
  end

  def bot?(participant)
    BOT_PATTERN.match?(participant.to_s)
  end

  def human?(participant)
    !bot?(participant)
  end

  def bot_number(participant)
    match = BOT_PATTERN.match(participant.to_s)
    match == nil ? nil : match[2].to_i
  end

  def display_name(participant)
    number = bot_number(participant)
    return participant.to_s if number == nil

    _("Computer %{number}") % { number: number }
  end

  def same?(first, second)
    first.to_s.casecmp(second.to_s) == 0
  end

  def includes?(participants, participant)
    participants.to_a.any? { |candidate| same?(candidate, participant) }
  end

  def humans(participants)
    unique(participants).select { |participant| human?(participant) }
  end

  def unique(participants)
    result = []
    participants.to_a.each do |participant|
      value = participant.to_s
      next if value.empty? || includes?(result, value)

      result << value
    end
    result
  end
end
