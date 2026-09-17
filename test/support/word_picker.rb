# encoding: UTF-8
# A scripted modal driver: exercises the real picker and its accept/cancel
# handlers, without opening a native window.
module WordPickerTest
  class << self
    attr_accessor :answers, :dialogs
  end
  self.answers = []
  self.dialogs = []
  module FormDriver
    def wait
      raise "Unscripted tile picker" if WordPickerTest.answers.empty?
      WordPickerTest.dialogs << { header: fields.first.header, labels: fields.first.options.dup }
      answer = WordPickerTest.answers.shift
      if answer.respond_to?(:call)
        answer.call(self)
      elsif answer.nil?
        cancel_button.trigger(:press)
      else
        if answer.is_a?(Array)
          fields.first.select_multiselection_indices(answer)
        else
          fields.first.index = answer
        end
        accept_button.trigger(:press)
      end
    end
    def resume; end
  end
end
Form.prepend(WordPickerTest::FormDriver)

def pick_word_tile(surface, tile, position, blank: nil)
  surface.fields.first.set_logical_position(position % 15, position / 15)
  available = surface.state["order"] - surface.state["draft"].map(&:first)
  index = available.index(tile)
  raise "Tile unavailable in test" unless index
  WordPickerTest.answers << index
  WordPickerTest.answers << blank if blank
  surface.fields.first.trigger(:select)
end
