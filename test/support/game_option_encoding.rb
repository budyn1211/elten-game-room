require_relative "binary_rules_load"

# Dictionary#find returns an untranslated source unchanged when its key is
# absent. In an installed app that source is ASCII-8BIT, not necessarily UTF-8.
# The host's checkbox role and state can still be translated (e.g. Russian).
$option_host_language = "ru"

def p_(_context, text)
  {
    "en" => { "Checkbox" => "Checkbox", "ticked" => "ticked", "unticked" => "unticked" },
    "pl" => { "Checkbox" => "Pole wyboru", "ticked" => "zaznaczone", "unticked" => "niezaznaczone" },
    "ru" => { "Checkbox" => "Флажок", "ticked" => "отмечено", "unticked" => "не отмечено" }
  }.fetch($option_host_language).fetch(text)
end

class CheckBox < FakeControl
  attr_accessor :label, :checked

  def initialize(label, checked: false)
    super()
    @label, @checked = label, checked
  end

  # Same concatenations as ELTEN src/ui/controls/check_box.rb#focus. Do not
  # repair encoding in this fake: doing that would hide the reported crash.
  def focus(*_arguments)
    text = @label + " ... "
    text += p_("EAPI_Form", "Checkbox") + " "
    text += p_("EAPI_Form", @checked ? "ticked" : "unticked")
    speak(text)
  end
end

class Static < FakeControl
  attr_reader :text
  def initialize(text)
    super()
    @text = text
  end
end

class EditBox
  module Flags
    Numbers = 8 unless const_defined?(:Numbers)
  end
  def select_all; end
end

class Form
  class << self
    attr_accessor :option_encoding_driver
  end
  def wait
    Form.option_encoding_driver.call(self)
  end
  def resume; end
end

module GameOptionEncodingFixture
  def self.driver(checks = {forms: 0, checkbox_states: 0, labels: 0})
    lambda do |form|
      form_labels = []
      form.fields.each do |field|
        next if form.hidden_controls.include?(field)
        labels = case field
        when CheckBox
          original = field.checked
          [true, false].each do |checked|
            field.checked = checked
            field.focus
            raise "Checkbox speech is not valid UTF-8" unless $spoken_messages.last.encoding == Encoding::UTF_8 && $spoken_messages.last.valid_encoding?
            checks[:checkbox_states] += 1
          end
          field.checked = original
          [field.label]
        when ListBox then [field.header] + field.options
        when EditBox then [field.header]
        else []
        end
        form_labels.concat(labels)
      end
      form_labels.each do |label|
        raise "Option label was not normalized: #{label.inspect}" unless label.encoding == Encoding::UTF_8 && label.valid_encoding?
        # Also exercise non-checkbox fields next to the host's translated text.
        label + " — выбранное поле"
        checks[:labels] += 1
      end
      checks[:forms] += 1
      form.accept_button.trigger(:press)
    end
  end
end

Form.option_encoding_driver = GameOptionEncodingFixture.driver
