class InvitationNotifications
  NOTIFICATION_TYPE = "game_room.invitation".freeze

  def initialize(client:, app_uuid:, gateway: nil)
    @client = client
    @app_uuid = app_uuid.to_s
    @gateway = gateway || EltenLink::Notifications
  end

  def revoke(invitation_id, notification_id: nil)
    direct_id = notification_id.to_i
    if direct_id > 0
      @gateway.revoke(@client, direct_id)
      return 1
    end

    wanted = invitation_id.to_i
    return 0 if wanted <= 0

    ids = @gateway
      .list(@client, all: false, app_uuids: [@app_uuid])
      .to_a
      .filter_map { |notification| matching_notification_id(notification, wanted) }
      .uniq
    return 0 if ids.empty?

    @gateway.revoke_many(@client, ids)
    ids.length
  end

  def revoke_for_table(table_id)
    wanted = table_id.to_i
    return 0 if wanted <= 0

    ids = @gateway
      .list(@client, all: false, app_uuids: [@app_uuid])
      .to_a
      .filter_map { |notification| matching_table_notification_id(notification, wanted) }
      .uniq
    return 0 if ids.empty?

    @gateway.revoke_many(@client, ids)
    ids.length
  end

  private

  def matching_notification_id(notification, invitation_id)
    metadata = invitation_metadata(notification)
    return nil if metadata == nil
    return nil if hash_value(metadata, "invitation_id").to_i != invitation_id

    notification_id(notification)
  end

  def matching_table_notification_id(notification, table_id)
    metadata = invitation_metadata(notification)
    return nil if metadata == nil
    return nil if hash_value(metadata, "table_id").to_i != table_id

    notification_id(notification)
  end

  def invitation_metadata(notification)
    return nil if notification.respond_to?(:revoked) && notification.revoked == true
    return nil if !same_app?(notification)

    type = notification.respond_to?(:type) ? notification.type.to_s : ""
    metadata = notification.respond_to?(:metadata) ? notification.metadata : nil
    if type.empty? || !metadata.is_a?(Hash)
      payload = notification.respond_to?(:payload) ? notification.payload : nil
      return nil if !payload.is_a?(Hash)
      type = hash_value(payload, "type").to_s
      metadata = hash_value(payload, "metadata")
    end
    return nil if type != NOTIFICATION_TYPE || !metadata.is_a?(Hash)

    metadata
  end

  def notification_id(notification)
    id = notification.respond_to?(:id) ? notification.id.to_i : 0
    id > 0 ? id : nil
  end

  def same_app?(notification)
    uuid = notification.respond_to?(:app_uuid) ? notification.app_uuid.to_s : ""
    !uuid.empty? && uuid.casecmp(@app_uuid) == 0
  end

  def hash_value(hash, key)
    hash[key] || hash[key.to_sym]
  end
end
