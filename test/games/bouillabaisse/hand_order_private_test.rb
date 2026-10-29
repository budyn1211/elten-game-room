require_relative '../../support/private_card_games'
require_relative '../../../games/bouillabaisse'
require_relative '../../../games/spades'

game = GameRoomGames::Bouillabaisse.new
h, runners = PrivateCardGamesTest.create(game, users: %w[Alice Bob])
begin
  PrivateCardGamesTest.assert_private(h)
  spades = GameRoomGames::Spades.new
  %w[Alice Bob].each do |viewer|
    replay = h.replay(viewer)
    before = Marshal.dump(replay)
    hand = game.send(:hand_for, replay.state, viewer)
    expected = hand.sort_by { |card| spades.send(:card_sort_key, card) }
    zone = game.surface_spec(replay, viewer).zones.first
    assert(zone.cards.map(&:id) == expected, 'Private hand differs from Spades order')
    assert(zone.hand_order == hand, 'Private received order was changed')
    reminder = game.shortcut_feature_data(:hand, replay, viewer).fetch(:message)
    assert(reminder == "Your hand: #{game.send(:cards_text, expected)}.", 'Private H order differs from the displayed hand')
    assert(Marshal.dump(replay) == before, 'Private sorting changed authoritative cards or audit data')
  end
  assert(game.surface_spec(h.replay('Alice'), 'Observer').is_a?(GameSurfaces::QuestionSpec), 'Observer received a private hand surface')
ensure
  runners.each_value(&:close)
end
puts 'PASS private Bouillabaisse hand display/H: both authenticated recipients, Spades parity, unchanged raw hand/audit and no observer hand surface'
