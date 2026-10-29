require_relative '../support/binary_rules_load'
require_relative '../support/assertions'
include GameRoomTest::Assertions

expected = JSON.parse(File.read(File.join(BinaryRulesLoad::ROOT, 'test/fixtures/game_descriptions_pl.json'), encoding: 'UTF-8'))
registry = EltenGameRoom::GAME_REGISTRY
app = EltenGameRoom.allocate
variant_labels = {
  'en' => ['Classic', 'All or nothing', 'Without all or nothing'],
  'pl' => ['Klasyczny', 'Wszystko albo nic', 'Bez wariantu „wszystko albo nic”'],
  'cs' => ['Klasická', 'Všechno, nebo nic', 'Bez varianty „všechno, nebo nic“'],
  'es' => ['Clásica', 'Todo o nada', 'Sin todo o nada'],
  'ru' => ['Классическая', 'Всё или ничего', 'Без варианта «всё или ничего»']
}
%w[pl en cs es ru].each do |language|
  GameRoomTestLocalization.use_language(language)
  registry.ids.each do |id|
    game = registry.build(id)
    label = app.send(:game_lobby_label, id)
    assert(label.encoding == Encoding::UTF_8 && label.valid_encoding?, "#{language}/#{id}: binary label encoding")
    assert(label == "#{game.name}. #{game.short_description}", "#{language}/#{id}: binary label differs from description")
    assert(game.short_description == expected.fetch(id), "#{id}: binary load changed approved Polish text") if language == 'pl'
  end
  classic, enabled, disabled = variant_labels.fetch(language)
  scopa = registry.build('scopa')
  variant = GameRoomTableVariant.text(scopa, GameRoomTableVariant.payload(scopa, scopa.default_options))
  assert(variant.start_with?(classic + ', ') && variant.include?('11'), "#{language}: classic Scopa or points missing")
  assert((variant + ' — справка').valid_encoding?, "#{language}: Scopa variant is not UI-safe UTF-8")
  bouillabaisse = registry.build('bouillabaisse')
  {true => enabled, false => disabled}.each do |flag, label|
    actual = GameRoomTableVariant.text(bouillabaisse,
      GameRoomTableVariant.payload(bouillabaisse, {'all_or_nothing' => flag}))
    assert(actual == label, "#{language}: Bouillabaisse short variant differs")
  end
end
puts "PASS binary-source descriptions: all #{registry.ids.size} games in PL/EN/CS/ES/RU"
