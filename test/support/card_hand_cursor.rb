require_relative "ui"
require_relative "../../lib/game_surfaces"
require_relative "../../lib/game_layout"
require_relative "../../games/uno"
require_relative "../../games/ninety_nine"
require_relative "../../games/spades"
require_relative "../../games/tysiac"
require_relative "../../games/makao"
require_relative "../../games/poker"

def assert(condition, message)
  raise message unless condition
end

def hand_spec(ids, packet: false, epoch: "1", duplicate_labels: false, choices: false)
  cards = ids.sort.map do |id|
    variants = choices ? [GameSurfaces::CardChoice.new(id: "x", label: "Choice", value: id + ":x")] : []
    GameSurfaces::Card.new(id: id, label: duplicate_labels ? "same card" : id, value: id,
      choices: variants, sort_keys: { "number" => [id], "none" => [ids.index(id)] })
  end
  if packet
    GameSurfaces::PacketCardSpec.new(id: "hand", header: "Cards", cards: cards, action_name: "play",
      hand_order: ids.dup, hand_epoch: epoch, empty_label: "Empty")
  else
    GameSurfaces::CardTableSpec.new(zones: [GameSurfaces::CardZoneSpec.new(id: "hand", header: "Cards",
      cards: cards, hand_order: ids.dup, hand_epoch: epoch, empty_label: "Empty")])
  end
end

def selected(surface)
  surface.fields.first.options[surface.fields.first.index]
end

def layout_spec(surface)
  GameRoomLayout::ViewSpec.new(surface: surface)
end
