require_relative '../../support/binary_rules_load'
require_relative '../../support/assertions'
include GameRoomTest::Assertions

%w[en pl cs es ru].each do |language|
  GameRoomTestLocalization.use_language(language)
  scopa=EltenGameRoom::GAME_REGISTRY.build('scopa')
  definitions=scopa.option_definitions.to_h { |definition| [definition.key,definition] }
  %w[escoba scopone muerto two_point_lead].each do |key|
    label=definitions.fetch(key).label
    assert(label.valid_encoding? && label.encoding==Encoding::UTF_8 && label.length>25,"#{language}/#{key}: missing readable description")
    assert(label!='Escoba' && label!='Scopone' && label!='Muerto','variant name without explanation')
  end
  assert(definitions['escoba'].label.include?('15'),'Escoba description omits sum')
  assert(scopa.default_options.values_at('escoba','scopone','muerto')==[false,false,false],'non-default variants enabled')
  assert(scopa.default_options['two_point_lead'] && scopa.default_options['score_limit']==11,'wrong standard game')
  assert(!definitions.keys.any? { |key| key.include?('manual') },'manual capture option exposed')
  %w[scopa bouillabaisse].each do |id|
    game=EltenGameRoom::GAME_REGISTRY.build(id)
    assert(game.short_description.encoding==Encoding::UTF_8 && !game.short_description.empty?,"#{language}: missing description")
    text=game.rule_book.documents.first.sections.flat_map(&:paragraphs).join("\n")
    assert(text.valid_encoding? && (text.include?('Enter') || language=='es' && text.include?('Intro')),'missing main control')
  end
end
puts 'PASS new card binary labels: explained variant controls, default settings, five complete language editions'
