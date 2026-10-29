require_relative '../../support/binary_rules_load'
require_relative '../../support/assertions'
include GameRoomTest::Assertions

rank_rules = {
  'en' => ['Each jack you take costs 50 points.', 'Each queen you take costs 50 points.', 'Each king you take costs 50 points.'],
  'pl' => ['Każdy zabrany walet kosztuje 50 punktów.', 'Każda zabrana dama kosztuje 50 punktów.', 'Każdy zabrany król kosztuje 50 punktów.'],
  'cs' => ['Za každého získaného kluka dostaneš 50 trestných bodů.', 'Za každou získanou dámu dostaneš 50 trestných bodů.', 'Za každého získaného krále dostaneš 50 trestných bodů.'],
  'es' => ['Cada jota que te lleves suma 50 puntos.', 'Cada reina que te lleves suma 50 puntos.', 'Cada rey que te lleves suma 50 puntos.'],
  'ru' => ['Каждый взятый валет приносит 50 штрафных очков.', 'Каждая взятая дама приносит 50 штрафных очков.', 'Каждый взятый король приносит 50 штрафных очков.']
}
rank_rules.each do |language, expected|
  GameRoomTestLocalization.use_language(language)
  game = EltenGameRoom::GAME_REGISTRY.build('bouillabaisse')
  state = game.send(:initial_state, %w[Alice Bob], game.default_options)
  state[:penalties] = {'suit' => 'H', 'rank' => 'K', 'card' => 'QH'}
  replay = GameRoomGames::Replay.new(players: state[:players], state: state, accepted_events: [], history: [])
  1.upto(6) do |round|
    state[:round] = round
    keys = game.game_shortcuts(replay, 'Alice')
    r = keys.find { |key| key.key == 'r' && key.modifiers.empty? }
    v = keys.find { |key| key.key == 'v' && key.modifiers.empty? }
    assert(r && v && r.message == v.message, "#{language}/#{round}: R and V differ")
    assert(r.message.encoding == Encoding::UTF_8 && r.message.valid_encoding?, 'Binary round text is not UTF-8')
    if round >= 5
      [5, 10, 50, 200].each do |points|
        assert(r.message.match?(/\b#{points}\b/), "#{language}/#{round}: omitted #{points} points")
      end
      assert(r.message.lines.size == 4, 'Combined-round rules lost their separate lines')
    end
    assert(!r.message.include?('Each ') && !r.message.include?('Taking '), "#{language}: untranslated round rule") unless language == 'en'
  end
  state[:round] = 3
  %w[J Q K].each_with_index do |rank, index|
    state[:penalties]['rank'] = rank
    text = game.game_shortcuts(replay, 'Alice').find { |key| key.key == 'r' }.message
    assert(text.include?(expected[index]), "#{language}/#{rank}: missing natural, complete rank rule")
  end
  text = game.rule_book.documents.find { |document| document.id == :controls }.paragraphs.join("\n")
  assert(text.include?('R / V:'), "#{language}: updated round shortcut missing from rules")
  raw = %w[AS 2H AC TC 2S AH AD 2C 2D]
  state[:hands] = {'Alice' => raw.dup, 'Bob' => []}
  ordered = %w[2H AH 2S AS 2D AD 2C TC AC]
  zone = game.surface_spec(replay, 'Alice').zones.first
  assert_equal(ordered, zone.cards.map(&:id), "#{language}: binary hand order differs from Spades")
  assert_equal(raw, zone.hand_order, 'Binary presentation changed received order')
  h = game.game_shortcuts(replay, 'Alice').find { |shortcut| shortcut.key == 'h' && shortcut.modifiers.empty? }
  labels = ordered.map { |card| game.send(:playing_card_label, card) }
  assert(h.message.include?(labels.join(', ')), "#{language}: H order differs from displayed order")
  assert(h.message.encoding == Encoding::UTF_8 && h.message.valid_encoding?, 'Binary H reminder lost UTF-8')
  assert_equal(raw, state[:hands]['Alice'], 'Binary H reminder reordered the deal')
end
puts 'PASS binary Bouillabaisse round text: five languages, actual ranks and costs, final subtraction, R/V parity and rulebook help'
