require_relative "../lib/invitation_shortcuts"

def assert(condition, message)
  raise message if !condition
end

class FakeInvitationShortcutForm
  def initialize
    @handlers = {}
    @pressed = []
  end

  def on(event, &block)
    @handlers[event] = block
  end

  def press(key)
    @pressed = [key]
    send(:keyevents)
  ensure
    @pressed = []
  end

  def trigger(event, parameters)
    @handlers.fetch(event).call(parameters)
  end

  private

  def keyevents
    []
  end

  def key_first_pressed?(key)
    @pressed.include?(key)
  end
end

form = FakeInvitationShortcutForm.new
actions = []
GameRoomInvitationShortcuts.bind(
  form,
  [],
  invite_online: -> { actions << :online },
  invite_contacts: -> { actions << :contacts },
  accept: -> { actions << :accept },
  reject: -> { actions << :reject }
)

i_events = form.press(GameRoomInvitationShortcuts::CTRL_I_KEY)
j_events = form.press(GameRoomInvitationShortcuts::CTRL_J_KEY)
assert(i_events == [[:game_room_invitation_i, :game_room_invitation_i]], "Ctrl+I event was filtered as a list letter")
assert(j_events == [[:game_room_invitation_j, :game_room_invitation_j]], "Ctrl+J event was filtered as a list letter")

form.trigger(:game_room_invitation_i, [false, true, false])
form.trigger(:game_room_invitation_i, [true, true, false])
form.trigger(:game_room_invitation_j, [false, true, false])
form.trigger(:game_room_invitation_j, [true, true, false])
form.trigger(:game_room_invitation_i, [false, false, false])
form.trigger(:game_room_invitation_j, [false, false, false])
assert(actions == [:online, :contacts, :accept, :reject], "invitation shortcuts accepted invalid modifiers or lost a valid action")

puts "Invitation shortcut tests passed"
