# Uses the installed source of ELTEN's actual text control, without running
# an ELTEN process or accessing the clipboard/device. The app code is loaded
# unchanged into an isolated namespace with that native control as its base.
require_relative 'taboo_rules_dictionary_test'
native_source = ENV.fetch('ELTEN_EDIT_BOX_SOURCE', File.expand_path('../../work/elten-3.0.1-app-dev/src/ui/controls/edit_box.rb', __dir__))
module EltenAPI
  module Controls
    FormField = FakeControl unless const_defined?(:FormField, false)
  end
end
module EltenLink
  def self.legacy_line_to_text(text, eol:); text; end
end
module Clipboard
  class << self; attr_accessor :text; end
end
def p_(_context, text); text; end
def alert(*_args); end
load native_source
native = EltenAPI::Controls.const_get(:EditBox)
native_text_scope = Module.new
native_text_scope.const_set(:EditBox, native)
%w[game_room_ui game_surfaces/card_hand_cursor game_surfaces/card_sorting game_surfaces game_history_view].each do |name|
  path = File.join(BinaryRulesLoad::ROOT, 'lib', "#{name}.rb")
  native_text_scope.module_eval(BinaryRulesLoad.read(path), path, 1)
end
view = native_text_scope.const_get(:GameRoomHistory)::View.new(header: 'Historia żółta'.b)
view.replace_entries(["Łukasz: pierwszy\nwiersz drugi", 'Żaneta: drugi'])
raise 'Not a native text control' unless view.is_a?(native)
raise 'Native flags differ' unless view.flags == native::Flags::ReadOnly | native::Flags::MultiLine
view.entry_index = 0
view.index, view.check = 0, 6
view.copy
raise 'Native copy omitted Unicode selection' unless Clipboard.text == 'Łukasz'
view.replace_entries(["Łukasz: pierwszy\nwiersz drugi", 'Żaneta: drugi', 'Nowy ruch'])
raise 'Native refresh changed selection' unless [view.index, view.check] == [0, 6]
view.entry_index = 1
raise 'Native event cursor incorrect' unless view.text_range(view.index, view.text_len).start_with?('Żaneta')
view.set_text(view.text, false)
raise 'Native set_text lost cursor' unless view.entry_index == 1
view.restore_selection(index: 100_000, check: 100_000)
raise 'CRLF escaped native cursor bounds' unless view.index == view.text_len && view.check == view.text_len
help = native_text_scope.const_get(:GameRoomUI)::HelpText.new('Skróty'.b,
  type: native::Flags::ReadOnly | native::Flags::MultiLine, text: "Ctrl+przecinek: poprzedni wpis.\nF1: pomoc.")
raise 'Native help swallowed Enter' unless help.key_processed(:enter) == false && help.key_processed(:key_enter) == false
raise 'Native help flags/text' unless help.text.lines.length == 2 && help.flags == 3
puts 'PASS real ELTEN EditBox: read-only multiline flags, UTF-8, actual copy and selection, event offsets, refresh, help Enter'

# Drive native EditBox#focus and #read_text. Only the speech and Braille
# device boundaries are replaced; speech callbacks run as they would when
# reading finishes, exposing unintended cursor changes as well as speech.
module Configuration
  def self.controlspresentation; :voice_only; end
end
module SpeechCommands
  class CustomCommand
    def initialize(*args, &callback); @args, @callback = args, callback; end
    def call; @callback.call(*@args); end
  end
end
class SpeechSequence
  def initialize(commands); @commands = commands; end
  def run
    @commands.each { |command| command.is_a?(String) ? speak(command) : command.call }
  end
end
module NVDA
  class << self; attr_accessor :last_braille; end
  def self.check; true; end
  def self.braille(*args); self.last_braille = args; end
end

focus_failures = []
focus_entries = ["Żaneta: początek\nciąg dalszy", 'Łukasz: środek', 'Zofia: koniec']
%w[pl en fallback].each do |focus_language|
  $rules_english = focus_language != 'pl'
  view.replace_entries(focus_entries)
  focus_failures << 'History inserts a blank line between entries' unless view.text.delete("\r") == focus_entries.join("\n")
  focus_entries.each_index do |row|
    view.entry_index = row
    # Preserve both a character position inside an entry and its selection.
    view.index += 2
    view.check = view.index + 3
    selected = [view.index, view.check]
    $spoken_messages.clear
    view.focus(2, 5)
    body = $spoken_messages.join("\n")
    focus_failures << "Focus reads the wrong history entry #{row}" unless body.include?(focus_entries[row]) &&
      (focus_entries - [focus_entries[row]]).none? { |entry| body.include?(entry) }
    focus_failures << 'Focus moved history caret/selection' unless [view.index, view.check] == selected
    focus_failures << 'Focus lost the history heading' unless body.include?(view.header)
    focus_failures << 'Native Braille/caret changed' unless NVDA.last_braille[1] == view.header.length + 1 + selected[0]
    $spoken_messages.clear
    view.focus(nil, nil, false)
    focus_failures << 'Silent history focus spoke' unless $spoken_messages.empty?
    view.suppress_next_focus!
    view.focus
    focus_failures << 'Refresh suppression spoke' unless $spoken_messages.empty?
  end
end

# The short focus announcement must not replace the user's explicit Read all
# command or affect other text controls, including F1.
$spoken_messages.clear
view.read_text(0)
focus_failures << 'Explicit Read all no longer reads the history' unless focus_entries.all? do |entry|
  entry.lines.all? { |line| $spoken_messages.join("\n").include?(line.strip) }
end
$spoken_messages.clear
help.focus
focus_failures << 'History fix changed help focus' unless $spoken_messages.join("\n").include?('F1: pomoc.')
view.replace_entries([])
$spoken_messages.clear
view.focus
focus_failures << 'Empty history focus failed' unless $spoken_messages.join.include?(view.header) && [view.index, view.check] == [0, 0]
raise focus_failures.uniq.join("\n") unless focus_failures.empty?
puts 'PASS native history focus: current entry only, single separators, stable selection, Braille, silent refresh, explicit Read all and unchanged help'
