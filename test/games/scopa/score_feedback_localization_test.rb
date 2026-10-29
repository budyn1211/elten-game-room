require_relative '../../support/binary_rules_load'
require_relative '../../support/assertions'
include GameRoomTest::Assertions

expected = {
  'en' => ['Alice: 1 point for the most cards, 1 point for the seven of diamonds.',
    'Most sevens: tied, no point.', 'Bob receives 1 point.', 'Bob, Carol receive 1 point each.', 'Alice wins the trick.', 'Final deal.'],
  'pl' => ['Alice: 1 punkt za najwięcej kart, 1 punkt za siódemkę karo.',
    'Najwięcej siódemek: remis, bez punktu.', 'Bob dostaje 1 punkt.', 'Bob, Carol dostają po 1 punkcie.', 'Alice wygrywa lewę.', 'Ostatnie rozdanie.'],
  'cs' => ['Alice: 1 bod za nejvíc karet, 1 bod za károvou sedmu.',
    'Nejvíc sedmiček: remíza, bod se neuděluje.', 'Bob získává 1 bod.', 'Bob, Carol získávají po 1 bodu.', 'Alice získává zdvih.', 'Poslední rozdání.'],
  'es' => ['Alice: 1 punto por tener más cartas, 1 punto por el siete de diamantes.',
    'Mayor número de sietes: empate, sin punto.', 'Bob recibe 1 punto.', 'Bob, Carol reciben 1 punto cada uno.', 'Alice gana la baza.', 'Último reparto.'],
  'ru' => ['Alice: 1 очко за наибольшее число карт, 1 очко за бубновую семёрку.',
    'Больше всего семёрок: ничья, очко не начисляется.', 'Bob получает 1 очко.', 'Bob, Carol получают по 1 очку.', 'Alice выигрывает взятку.', 'Последняя раздача.']
}
repository = Object.new
def repository.event_id(event); event.fetch('id'); end
expected.each do |language, messages|
  GameRoomTestLocalization.use_language(language)
  game = EltenGameRoom::GAME_REGISTRY.build('scopa')
  state = game.send(:initial_state, %w[Alice Bob], game.default_options)
  taken = {'Alice' => %w[7D 2C 3C 4C 5C 6C], 'Bob' => %w[7C 2D 3D 4D 5D]}
  lines = game.send(:round_award_lines, state, game.class.round_awards(taken))
  assert_equal(messages[0], lines.first, "#{language}: ordinary awards are untranslated or incomplete")
  assert_equal(messages[1], lines.last, "#{language}: tie message is untranslated")
  [2, 3].each do |count|
    players = %w[Alice Bob Carol].first(count)
    state = game.send(:initial_state, players, game.normalize_options('muerto' => true))
    taken = players.to_h { |player| [player, player == 'Alice' ? %w[7D 7C 2D] : []] }
    lines += muerto = game.send(:round_award_lines, state, game.class.round_awards(taken))
    assert_equal(4, muerto.size, "#{language}: Muerto did not explain all four awards")
    assert(muerto.all? { |line| line.end_with?(messages[count]) }, "#{language}: wrong recipient names/plural form")
  end
  assert(lines.all? { |line| line.encoding == Encoding::UTF_8 && line.valid_encoding? }, "#{language}: binary score text lost UTF-8")
  assert(lines.none? { |line| line.downcase.include?('scopa') }, 'Scopas were announced twice')
  state = game.send(:initial_state, %w[Alice Bob], game.default_options)
  state[:round] = 1
  state[:dealer] = 0
  history = []
  game.send(:deal_round, state, '7', {'id' => 1}, repository, history)
  assert(history.none? { |entry| entry.kind == :last_deal }, 'Initial packet is announced as the final deal')
  state[:table], state[:stock] = [], %w[2C 3C 4C 5C 6C 7C]
  state[:hands].each_value(&:clear)
  history = []
  game.send(:play_card, state, 'Alice', 'AC', {'id' => 2}, repository, history)
  assert_equal(messages[5], history.first.text, "#{language}: final packet is not announced")
  assert_equal(:redeal, history[1].kind, 'The final deal warning follows the actual deal')

  bouillabaisse = EltenGameRoom::GAME_REGISTRY.build('bouillabaisse')
  state = bouillabaisse.send(:initial_state, %w[Alice Bob], bouillabaisse.default_options)
  state[:round] = 1
  state[:dealer] = 0
  bouillabaisse.send(:deal_round, state, '7', {'id' => 1}, repository, [])
  state[:trick] = [['Alice', 'AC']]
  history = []
  bouillabaisse.send(:play_card, state, 'Bob', '2C', {'id' => 2}, repository, history)
  assert_equal(messages[4], history.find { |entry| entry.kind == :trick }.text, "#{language}: incorrect trick announcement")
end

puts 'PASS binary Scopa/Bouillabaisse feedback: five languages, ordinary awards, ties, Muerto recipient plurals and natural trick message'
