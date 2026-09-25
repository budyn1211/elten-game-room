# Exact pre-cleanup installers, retained only to test an already-prepended
# app-scoped wrapper during native host namespace replacement.
module GameRoomUI
  module_function
  def install_hotkeys
    return unless defined?(EltenAPI::QuickActions)

    target = EltenAPI::QuickActions.singleton_class
    return if target.instance_variable_get(:@game_room_dispatch_bridge_version).to_i >= 2

    bridge = Module.new do
      define_method(:hotkey_actions) do |key|
        form = $activecontrols.to_a.reverse.find do |control|
          control.respond_to?(:game_room_hotkeys_active?) && control.game_room_hotkeys_active?
        end
        # The host singleton survives app updates. Do not freeze the set of
        # supported keys here: the current control owns that decision.
        if form != nil && form.respond_to?(:game_room_hotkey_action)
          action = form.game_room_hotkey_action(key)
          return [action] if action != nil
        end
        super(key)
      end
    end
    target.prepend(bridge)
    target.instance_variable_set(:@game_room_dispatch_bridge, true)
    target.instance_variable_set(:@game_room_dispatch_bridge_version, 2)
  end

end
module GameRoomInvitationReceipts
  module_function
  def install(program)
    return unless defined?(NotificationGroups) && program.respond_to?(:server_app_uuid)

    uuid = program.server_app_uuid.to_s.downcase
    return if uuid.empty?

    registry = NotificationGroups.instance_variable_get(:@game_room_receipt_programs) || {}
    registry[uuid] = program
    NotificationGroups.instance_variable_set(:@game_room_receipt_programs, registry)
    return if NotificationGroups.instance_variable_get(:@game_room_receipt_bridge)

    bridge = Module.new do
      def build_notification_groups(notifications, **options)
        registry = NotificationGroups.instance_variable_get(:@game_room_receipt_programs) || {}
        visible = notifications.reject do |row|
          program = row.cat.to_s == "app" ? registry[row.app_uuid.to_s.downcase] : nil
          payload = row.payload.is_a?(Hash) ? row.payload : {}
          type = (payload["type"] || payload[:type]).to_s
          hidden = program != nil && %w[game_room.invitation_resolved game_room.invitation_rejected].include?(type)
          if hidden && row.revoked != true
            program.receive_invitation_receipt(Programs.app_notification_from(row))
          end
          if program != nil && type == "game_room.table_created" && program.respond_to?(:table_notice_visible?)
            hidden ||= !program.table_notice_visible?(Programs.app_notification_from(row))
          end
          if program != nil && type == "game_room.invitation" && program.respond_to?(:contact_notification_allowed?)
            hidden ||= program.contact_notification_allowed?(Programs.app_notification_from(row)) != true
          end
          hidden
        end
        super(visible, **options)
      end
    end
    NotificationGroups.prepend(bridge)
    NotificationGroups.instance_variable_set(:@game_room_receipt_bridge, true)
  end

end
