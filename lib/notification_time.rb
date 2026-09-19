# Notification envelope dates are stamped by the server. Metadata dates in
# older Game Room clients were stamped by the sender and can be hours off.
module GameRoomNotificationTime
  module_function

  def created_at(notification)
    value = if notification.respond_to?(:date)
      notification.date.to_i
    elsif notification.respond_to?(:created_at)
      notification.created_at.to_i
    else
      0
    end
    value > 0 ? value : nil
  end

  def expires_at(notification, metadata = nil)
    metadata ||= notification.respond_to?(:metadata) ? notification.metadata.to_h : {}
    metadata = metadata.to_h.transform_keys(&:to_s)
    created = created_at(notification)
    # Compatibility with old/offline adapters that have no server envelope.
    return metadata["expires_at"].to_i unless created
    ttl = notification.respond_to?(:expiration) ? notification.expiration.to_i : 0
    ttl = metadata["expires_in"].to_i if ttl <= 0
    ttl = 300 if ttl <= 0
    deadline = created + [ttl, 300].min
    native = metadata["native_expires_at"].to_i
    native > 0 ? [deadline, native].min : deadline
  end
end
