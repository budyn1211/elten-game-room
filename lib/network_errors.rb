# Native LiveSessions failures do not inherit from EltenLink::Error. Keep the
# expected network boundary shared, without swallowing programming errors.
module GameRoomNetworkErrors
  def self.expected?(error)
    (defined?(EltenLink::Error) && error.is_a?(EltenLink::Error)) ||
      (defined?(EltenAPI::LiveSessions::Error) && error.is_a?(EltenAPI::LiveSessions::Error))
  end
end
