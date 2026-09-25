def _(text)
  text
end

module GameSurfaces
  Action = Struct.new(:kind, :name, :payload, :source, keyword_init: true) do
    def initialize(kind:, name:, payload: {}, source: nil)
      super(kind: kind.to_s, name: name.to_s, payload: payload, source: source)
    end

    def [](key)
      return kind if key.to_s == "kind"
      return name if ["action", "name"].include?(key.to_s)

      payload[key.to_s]
    end
  end
  AnswerField = Struct.new(:id, :label, :value, :required, :max_length, :multiline, keyword_init: true)
  AnswerSheetSpec = Struct.new(:id, :title, :fields, :submit_label, :read_only, keyword_init: true)
  ReviewItem = Struct.new(:id, :author, :category, :answer, :status, :decision, :decision_ids, keyword_init: true)
  ReviewDecision = Struct.new(:id, :label, keyword_init: true)
  ReviewSpec = Struct.new(:id, :header, :items, :decisions, :empty_label, :submit_label, :read_only, keyword_init: true)
  QuestionSpec = Struct.new(:id, :prompt, :mode, :options, :value, :submit_label, :required, :read_only, :max_length, :submit_on_select, keyword_init: true)
  Command = Struct.new(:id, :label, :enabled, :payload, keyword_init: true)
  CommandPanelSpec = Struct.new(:commands, keyword_init: true)
  SurfacePart = Struct.new(:id, :surface, keyword_init: true)
  CompositeSpec = Struct.new(:parts, keyword_init: true)
end

require "json"
require_relative "../../lib/game_random"
require_relative "../../lib/hidden_submissions"
require_relative "../../games/categories"

class CategoriesRepository
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

def surface_action(kind, name, payload = {})
  GameSurfaces::Action.new(kind: kind, name: name, payload: payload)
end

def append_plan(events, plan, actor, now: 100)
  plan.events.each do |command|
    events << {
      "id" => events.length + 1,
      "actor" => actor,
      "action" => command.action,
      "value" => command.value,
      "created_at" => now
    }
  end
end

def play_unique_round(game, session, repository, events, context, owner:, judge:, answerer:)
  replay = game.replay(session, events, repository)
  action = game.automatic_action(replay, owner, context: context)
  status, plan = game.action_for(action, replay, owner, context: context)
  raise "round start failed" if status != :ok
  append_plan(events, plan, owner)
  replay = game.replay(session, events, repository)

  answers = { "country" => "Austria", "city" => "", "name" => "", "animal" => "", "plant" => "", "thing" => "" }
  status, plan = game.action_for(surface_action("answer_sheet", "submit", "answers" => answers), replay, answerer, context: context)
  raise "submission failed" if status != :ok
  append_plan(events, plan, answerer)
  replay = game.replay(session, events, repository)

  action = game.automatic_action(replay, owner, context: context)
  status, plan = game.action_for(action, replay, owner, context: context)
  raise "answer closing failed" if status != :ok
  append_plan(events, plan, owner)
  replay = game.replay(session, events, repository)

  action = game.automatic_action(replay, answerer, context: context)
  status, plan = game.action_for(action, replay, answerer, context: context)
  raise "reveal failed" if status != :ok
  append_plan(events, plan, answerer)
  replay = game.replay(session, events, repository)

  action = game.automatic_action(replay, owner, context: context)
  status, plan = game.action_for(action, replay, owner, context: context)
  raise "review start failed" if status != :ok
  append_plan(events, plan, owner)
  replay = game.replay(session, events, repository)

  item = replay.state[:active_players].empty? ? nil : game.surface_spec(replay, judge)
  item = item.parts.first.surface if item.is_a?(GameSurfaces::CompositeSpec)
  review_item = item.items.first
  decisions = { review_item.id => "unique" }
  status, plan = game.action_for(
    surface_action("review", "change", "item_id" => review_item.id, "decision" => "unique"),
    replay,
    judge,
    context: context
  )
  raise "review decision failed" if status != :ok
  append_plan(events, plan, judge)
  replay = game.replay(session, events, repository)

  status, plan = game.action_for(
    surface_action("review", "finish", "decisions" => decisions),
    replay,
    judge,
    context: context
  )
  raise "review finish failed" if status != :ok
  append_plan(events, plan, judge)
  replay = game.replay(session, events, repository)

  action = game.automatic_action(replay, owner, context: context)
  status, plan = game.action_for(action, replay, owner, context: context)
  raise "round scoring failed" if status != :ok
  append_plan(events, plan, owner)
  game.replay(session, events, repository)
end
