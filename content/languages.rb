require_relative "../lib/game_room_localization"
require_relative "../lib/game_content"

GameRoomContent.registry.register_language(
  GameRoomContent::LanguageProfile.new(
    id: "en",
    label: GameRoomLocalization.translate("English"),
    alphabet: ("a".."z").to_a,
    normalizer: ->(text) { text.downcase }
  )
)

GameRoomContent.registry.register_language(
  GameRoomContent::LanguageProfile.new(
    id: "pl-PL",
    label: GameRoomLocalization.translate("Polish"),
    alphabet: %w[a ą b c ć d e ę f g h i j k l ł m n ń o ó p r s ś t u w y z ź ż],
    normalizer: ->(text) { text.downcase }
  )
)
