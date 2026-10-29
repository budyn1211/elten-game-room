require_relative '../../support/binary_rules_load'
require_relative '../../support/assertions'
include GameRoomTest::Assertions

GameRoomTestLocalization.use_language('pl')
game = EltenGameRoom::GAME_REGISTRY.build('tysiac')
assert_equal('Musisz dołożyć do koloru albo, gdy jest to wymagane, zagrać atutem.', game.move_error(:must_follow_suit))
puts 'PASS Tysiac binary Polish message: playing a trump is required by the rules, not merely possible'
