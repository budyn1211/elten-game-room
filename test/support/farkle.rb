def _(text)
  text
end

module GameSurfaces
  CardChoice = Struct.new(:id, :label, :value, keyword_init: true)
  Card = Struct.new(:id, :label, :value, :choices, keyword_init: true)
  CardZoneSpec = Struct.new(:id, :header, :cards, :empty_label, :hand_order, :hand_epoch, keyword_init: true)
  CardTableSpec = Struct.new(:zones, keyword_init: true)
end

require "json"
require_relative "../../lib/game_random"
require_relative "../../games/base"
require_relative "../../games/farkle"

class FarkleRepository
  def initialize(players)
    @players = players
  end

  def players_for(_session)
    @players
  end

  def actor_of(event, _session = nil)
    event.fetch("actor")
  end

  def event_id(event)
    event.fetch("id")
  end
end

def assert(condition, message)
  raise message if !condition
end

def farkle_event(id, actor, action, value = "")
  { "id" => id, "actor" => actor, "action" => action, "value" => value.to_s }
end
