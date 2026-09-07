module GameRoomInvitationShortcuts
  CTRL_I_KEY = 0x49
  CTRL_J_KEY = 0x4A

  module ShortcutFormEvents
    private

    def keyevents
      events = super
      if key_first_pressed?(GameRoomInvitationShortcuts::CTRL_I_KEY)
        events << [:game_room_invitation_i, :game_room_invitation_i]
      end
      if key_first_pressed?(GameRoomInvitationShortcuts::CTRL_J_KEY)
        events << [:game_room_invitation_j, :game_room_invitation_j]
      end
      events
    end
  end

  def self.bind(form, fields, invite_online: nil, invite_contacts: nil, accept: nil, reject: nil)
    form.extend(ShortcutFormEvents)
    fields.to_a.each do |field|
      next if !field.respond_to?(:add_tip)

      field.add_tip(_("Press Ctrl+I to invite an online Elten user.")) if invite_online != nil
      field.add_tip(_("Press Ctrl+Shift+I to invite someone from your contacts.")) if invite_contacts != nil
      field.add_tip(_("Press Ctrl+J to accept a game invitation.")) if accept != nil
      field.add_tip(_("Press Ctrl+Shift+J to reject a game invitation.")) if reject != nil
    end

    form.on(:game_room_invitation_i) do |parameters|
      shift, main_modifier, option = parameters.to_a
      next if main_modifier != true || option == true

      consume_key
      Log.debug("ELTEN Game Room Ctrl+I invitation shortcut") if defined?(Log)
      if shift == true
        invite_contacts&.call
      else
        invite_online&.call
      end
    end
    form.on(:game_room_invitation_j) do |parameters|
      shift, main_modifier, option = parameters.to_a
      next if main_modifier != true || option == true
      action = shift == true ? reject : accept
      next if action == nil

      consume_key
      shortcut = shift == true ? "Ctrl+Shift+J" : "Ctrl+J"
      Log.debug("ELTEN Game Room #{shortcut} invitation shortcut") if defined?(Log)
      action.call
    end
  end

  def self.consume_key
    EltenAPI::KeyboardState.clear_current_frame if defined?(EltenAPI::KeyboardState)
  end

  private_class_method :consume_key
end
