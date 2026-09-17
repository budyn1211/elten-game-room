require_relative "ui"
require_relative "log"
require_relative "../../lib/game_room_widget"

WidgetSnapshot = Struct.new(:table, keyword_init: true)
class WidgetManualWorker
  def start(&operation); return false if busy?; @operation = operation; true; end
  def busy?; @operation != nil || @result != nil; end
  def closed?; @closed == true; end
  def finish
    @result = [@operation.call, nil]
    @operation = nil
  rescue StandardError => error
    @result = [nil, error]
    @operation = nil
  end
  def take; value = @result; @result = nil; value; end
  def close; @closed = true; end
end

# Native ListBox reads on focus too, not only when sayoption is called.
module WidgetHostReadProbe
  attr_reader :focus_texts, :sayoption_count
  def focus(*arguments)
    (@focus_texts ||= []) << (options.empty? ? empty_label : options[index.to_i])
    super
  end
  def sayoption
    @sayoption_count = @sayoption_count.to_i + 1 unless options.empty?
  end
  def update
    focus if $game_room_widget_arrow
    super
  end
end
ListBox.prepend(WidgetHostReadProbe)

def key_pressed?(key); key == 0x52 && $game_room_widget_r; end
def assert(value, message); raise message unless value; end
