require_relative "ui"

class Program
  def self.server_app(**_options); end
end

class Static < FakeControl
  def initialize(text)
    super()
    @header = text
  end
end

class CheckBox < FakeControl
  attr_accessor :checked
  def initialize(label, checked: false)
    super()
    @header, @checked = label, checked
  end
end

class EditBox
  module Flags
    Numbers = 4
  end

  def select_all
    @index, @check = 0, text.length
  end
end

class Form
  class << self
    attr_accessor :driver
  end

  def wait
    raise "Unexpected form" unless Form.driver
    Form.driver.call(self)
  end

  def resume; end
end

require_relative "../../__app"

def assert(condition, message)
  raise message unless condition
end
