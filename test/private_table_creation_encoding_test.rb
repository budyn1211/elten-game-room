require_relative "game_option_encoding_test"

# Actual host checkbox speech, in addition to the binary-loaded form and the
# existing faithful control doubles. This does not launch an ELTEN client.
module Configuration
  def self.controlspresentation; :voice_only; end
end
module EltenAPI
  module Controls
    class FormField; end
  end
end
host = ENV.fetch("ELTEN_HOST_SOURCE", File.expand_path("../../work/elten-3.0.1-app-dev", __dir__))
load File.join(host, "src/ui/controls/check_box.rb")
native_checkbox = EltenAPI::Controls.const_get(:CheckBox)
app = EltenGameRoom.allocate
app.define_singleton_method(:read_json) { |_, default:| default }
app.define_singleton_method(:remember_multiple_choice_options) { |*| }
app.define_singleton_method(:alert) { |message| raise message }
base_driver = Form.option_encoding_driver
forms, native_states = 0, 0

Form.option_encoding_driver = lambda do |form|
  label = GameRoomLocalization.translate("Private table")
  fields = form.fields.select { |field| field.is_a?(CheckBox) && field.label == label }
  raise "Private table checkbox missing/duplicated" unless fields.length == 1
  field = fields.first
  raise "Creation did not focus its opening instructions" unless form.index == 0 && form.fields.first.is_a?(Static)
  raise "First Tab no longer leads to privacy" unless form.fields[1].equal?(field)
  instruction = form.fields.first.text
  raise "Opening instructions have incompatible encoding" unless (instruction + " Флажок").valid_encoding?
  raise "Privacy default changed" unless field.checked == false
  [false, true].each do |checked|
    native_checkbox.new(field.label, checked: checked).focus
    message = $spoken_messages.last
    raise "Native privacy speech is not UTF-8" unless message.encoding == Encoding::UTF_8 && message.valid_encoding?
    raise "Native privacy speech lost the label" unless message.start_with?(label)
    native_states += 1
  end
  field.checked = true
  base_driver.call(form)
  forms += 1
end

%w[ru en pl].each do |language|
  $option_host_language = language
  GameRoomTestLocalization.use_language(language)
  EltenGameRoom::GAME_REGISTRY.ids.each do |id|
    game = EltenGameRoom::GAME_REGISTRY.build(id)
    result = app.send(:configure_game_options, game, creating_table: true)
    raise "Creation changed #{id} rules/privacy" unless result == { game_options: game.default_options, private_table: true }
  end
end
puts "PASS binary privacy creation: #{forms} forms, #{native_states} native checkbox states; EN/PL and untranslated EN beside RU host"
