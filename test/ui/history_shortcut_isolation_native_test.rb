require_relative '../support/duck_challenge_native'
require_relative '../../lib/game_layout'
require_relative '../../lib/game_shortcut_bindings'
require_relative '../../games/base'

module Clipboard
  class << self; attr_accessor :text; end
end
module SpeechOutput
  def self.list; []; end
end

class HistoryTextMenu
  attr_reader :commands
  def initialize; @commands = []; end
  def option(label, value = nil, shortcut = '', &action)
    @commands << [label, shortcut, action]
  end
  def submenu(_label); yield self if block_given?; end
end

driver = DuckChallengeNativeDriver.new
spec = GameSurfaces::PawnTrackSpec.new(id: 'cards', header: 'Hand',
  items: [GameSurfaces::PawnTrackItem.new(id: 'card', label: 'King of hearts')])
layout = GameRoomLayout::Screen.new(view_spec: GameRoomLayout::ViewSpec.new(surface: spec),
  history_items: ['Żaneta: król kier'], user_items: %w[Alice Bob])
form = layout.form
form.game_room_background_help_enabled = true
form.focus
observed = []
shortcuts = [GameRoomGames::GameShortcut.new(key: 'c', modifiers: [:control],
  label: 'Browse table cards', kind: :announcement, message: 'cards'),
  GameRoomGames::GameShortcut.new(key: 'r', label: 'Round rules', kind: :announcement, message: 'round')]
bind = -> { GameRoomShortcutBindings.bind(form, layout.shortcut_fields, shortcuts,
  consume: ->(_key) {}) { |shortcut| observed << shortcut.key } }
bind.call
copy_key = lambda do
  driver.frame(form, [[0x11, true], [0x43, true, driver.raw([0x11, 0x43])]], held: [0x11, 0x43])
  driver.frame(form, [[0x43, false], [0x11, false]])
end

form.index = form.fields.index(layout.history)
layout.history.index, layout.history.check = 0, 6
before = [layout.history.text, layout.history.index, layout.history.check]
copy_key.call
assert(observed.empty?, 'History Ctrl+C invoked the game command')
menu = HistoryTextMenu.new
layout.history.context(menu, false)
copy = menu.commands.find { |label, _key, _action| label == 'Copy' }
assert(copy && copy[1] == 'c', 'History lost the native Copy shortcut')
copy.last.call
assert(Clipboard.text == 'Żaneta', 'Native Copy did not retain the Unicode selection')
driver.frame(form, driver.tap(0x52), characters: 'r')
assert(observed.empty?, 'History invoked an unmodified game shortcut')
assert([layout.history.text, layout.history.index, layout.history.check] == before,
  'Game shortcuts changed history text or selection')

form.index = form.fields.index(layout.surface.fields.first)
copy_key.call
driver.frame(form, driver.tap(0x52), characters: 'r')
assert(observed == %w[c r], "The same commands stopped working on the playfield: #{observed.inspect}")

# Existing text-entry and modified report shortcuts in chat stay available.
form.index = form.fields.index(layout.chat)
driver.frame(form, driver.tap(0x52), characters: 'r')
assert(observed == %w[c r] && layout.chat.text.include?('r'), 'Chat lost ordinary typing')

layout.begin_bindings
bind.call
form.index = form.fields.index(layout.history)
copy_key.call
assert(observed == %w[c r], 'A refresh reinstalled game shortcuts over history')
assert(GameRoomContextHelp.field_tips(layout.history).none? { |tip| tip.include?('Browse table cards') },
  'History advertises a game command as its own help')
$activecontrols = []
puts 'PASS native history shortcut boundary: Ctrl+C copy, Unicode selection, R isolation, playfield commands, chat and rebind'
