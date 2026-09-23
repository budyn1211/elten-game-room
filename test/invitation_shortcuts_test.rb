require_relative "support/ui"
require_relative "../lib/game_surfaces"
require_relative "../lib/game_layout"
require_relative "../lib/game_history_navigation"
require_relative "../lib/game_room_screens"

def assert(condition, message)
  raise message if !condition
end

class Form
  class << self
    attr_accessor :driver
  end

  def wait
    Form.driver.call(self)
  end

  def resume; end
end

# Accept/reject shortcuts belong to the main options list, not its history
# or the whole form. Native menu keys also advertise the shortcuts.
[["j", :invitations], ["J", :reject_invitation]].each do |key, expected|
  Form.driver = lambda do |form|
    options = form.fields.first
    options.index = 2
    assert_invitation_menu_scope(form, list: options, keys: %w[j J])
    menu = FakeMenu.new
    options.context(menu, false)
    menu.options.find { |option| option[2] == key }[3].call
  end
  result = GameRoomScreens::MainMenu.new(options: %w[Create Join Invitations], invitations: true).wait
  assert(result.action == expected && result.index == 2, "main-menu invitation action or list position was lost")
end

# The visible Invitations item keeps the ordinary Open path.
Form.driver = lambda do |form|
  form.fields.first.index = 2
  form.accept_button.trigger(:press)
end
result = GameRoomScreens::MainMenu.new(options: %w[Create Join Invitations], invitations: true).wait
assert(result.action == :open && result.index == 2, "the Invitations item no longer opens normally")

Form.driver = lambda do |form|
  assert_invitation_menu_scope(form, list: form.fields.first, keys: [])
  form.cancel_button.trigger(:press)
end
assert(GameRoomScreens::MainMenu.new(options: ["Exit"]).wait.action == :exit, "disabled invitations retained their shortcuts")
Form.driver = nil
puts "Native invitation menu shortcut tests passed"
