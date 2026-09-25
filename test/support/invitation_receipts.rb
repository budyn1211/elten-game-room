require_relative "invitation_fresh_endpoint"

Receipt = Struct.new(:id, :app_uuid, :type, :sender, :metadata, keyword_init: true)
class ReceiptGateway
  attr_accessor :error
  attr_reader :revoked
  def initialize; @revoked = []; end
  def revoke(_client, id)
    raise error if error
    @revoked << id
  end
end
