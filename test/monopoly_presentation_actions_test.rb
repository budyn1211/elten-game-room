require_relative 'support/new_games_fixture'

game = GameRoomGames::Monopoly.new
players = %w[Alice Bob Carol Dave]
state = game.send(:initial_state, players, game.default_options)
state[:board].select { |square| square[:price] }.each_with_index { |square, i| state[:owners][square[:index]] = players[i % players.size] }
replay = GameRoomGames::Replay.new(players: players, current_player: players.first, state: state, history: [], accepted_events: [])
original = game.method(:legal_actions)
full = original.call(replay, 'Alice')
assert(full.any? { |action| action['action'] == 'trade_offer' }, 'fixture has no strategic trade candidates')
assert(original.call(replay, 'Alice', include_trade_offers: false) == full.reject { |action| action['action'] == 'trade_offer' }, 'non-trade actions changed')
game.define_singleton_method(:trade_actions) { |*_args| raise 'UI enumerated bot trade candidates' }
game.surface_spec(replay, 'Alice')
shortcuts = game.custom_game_shortcuts(replay, 'Alice')
assert(shortcuts.any? { |shortcut| shortcut.key == 'e' && shortcut.kind == :staged_form }, 'manual trade editor disappeared')
puts 'PASS Monopoly UI skips candidate enumeration; normal bot actions and manual trade editor preserved'
