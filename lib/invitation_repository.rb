require_relative "game_room_clock"
require "securerandom"
require_relative "invitation_response_outbox"

class InvitationRepository
  SENT_LOCK = Mutex.new
  SENT = {}

  def self.resolve_sent(id, table_id:, recipient:)
    SENT_LOCK.synchronize do
      SENT.delete_if do |_key, row|
        (row["__id"] || row["id"]).to_i == id.to_i && row["table_id"].to_i == table_id.to_i &&
          row["recipient"].to_s.casecmp(recipient.to_s) == 0
      end
    end
  end

  def self.sent_for_receipt(id, table_id:, recipient:, sender:, live_session_id: nil)
    return nil if id.to_i <= 0 || table_id.to_i <= 0 || recipient.to_s.empty? || sender.to_s.empty?

    SENT_LOCK.synchronize do
      SENT.values.find do |row|
        row["__id"].to_i == id.to_i && row["table_id"].to_i == table_id.to_i &&
          row["sender"].to_s.casecmp(sender.to_s) == 0 && row["recipient"].to_s.casecmp(recipient.to_s) == 0 &&
          (live_session_id.to_s.empty? || row["live_session_id"].to_s == live_session_id.to_s)
      end
    end
  end
  InvitationResult = Struct.new(:invitation, :created, keyword_init: true) do
    def created?
      created == true
    end
  end

  PendingInvitation = Struct.new(:invitation, :table, keyword_init: true) do
    def id
      (invitation["__id"] || invitation["id"]).to_i
    end

    def table_id
      invitation["table_id"].to_i
    end

    def sender
      invitation["sender"].to_s
    end

    def recipient
      invitation["recipient"].to_s
    end

    def created_at
      invitation["created_at"].to_i
    end

    def expires_at
      invitation["expires_at"].to_i
    end
  end

  DEFAULT_TTL = 5 * 60
  INVITATION_LIMIT = 200
  RESPONSE_LIMIT = 500
  RESPONSES = ["accepted", "rejected", "expired"].freeze

  def initialize(server_tables: nil, transport: nil, notification_source: nil, response_sender: nil, response_outbox: nil)
    @server_tables = server_tables
    @transport = transport
    @notification_source = notification_source
    @response_sender = response_sender
    @response_outbox = response_outbox
    @sent_invitations = SENT
    @responses = {}
  end

  # Reserve a duplicate key only for an invitation that was actually sent.
  # Notification delivery is separate and must not turn a failed native
  # invitation into a success message or a long local lockout.
  def deliver(table:, sender:, recipient:)
    result = create(table: table, sender: sender, recipient: recipient)
    return result if !result.created?

    delivered = false
    begin
      delivered = yield(result.invitation)
      delivered ? result : nil
    ensure
      if !delivered && native_live_sessions?
        SENT_LOCK.synchronize { @sent_invitations.delete_if { |_key, row| row.equal?(result.invitation) } }
      end
    end
  end

  def create(table:, sender:, recipient:, now: GameRoomClock.now.to_i, ttl: DEFAULT_TTL)
    table_id = row_id(table)
    clean_sender = sender.to_s.strip
    clean_recipient = recipient.to_s.strip
    raise ArgumentError, "Invalid invitation table" if table_id <= 0
    raise ArgumentError, "Invitation sender is required" if clean_sender.empty?
    raise ArgumentError, "Invitation recipient is required" if clean_recipient.empty?
    raise ArgumentError, "You cannot invite yourself" if same_user?(clean_sender, clean_recipient)

    if native_live_sessions?
      return SENT_LOCK.synchronize do
        @sent_invitations.delete_if { |_key, row| row["expires_at"].to_i <= now.to_i }
        key = [table_id, table["__live_session_id"].to_s, clean_sender.downcase, clean_recipient.downcase]
        existing = @sent_invitations[key]
        if existing != nil && existing["expires_at"].to_i > now.to_i
          next InvitationResult.new(invitation: existing, created: false)
        end

        id = SecureRandom.random_number(2_000_000_000) + 1
        row = {
          "__id" => id,
          "id" => id,
          "table_id" => table_id,
          "live_session_id" => table["__live_session_id"].to_s,
          "sender" => clean_sender,
          "recipient" => clean_recipient,
          "status" => "pending",
          "created_at" => now.to_i,
          "expires_at" => now.to_i + [ttl.to_i, 1].max,
          "updated_at" => now.to_i,
          "__insertion_user" => clean_sender
        }
        @sent_invitations[key] = row
        InvitationResult.new(invitation: row, created: true)
      end
    end

    existing = pending_rows(clean_recipient, now: now).find do |row|
      row["table_id"].to_i == table_id && same_user?(invitation_sender(row), clean_sender)
    end
    return InvitationResult.new(invitation: existing, created: false) if existing != nil

    timestamp = now.to_i
    inserted = invitations_table.insert(
      "table_id" => table_id,
      "sender" => clean_sender,
      "recipient" => clean_recipient,
      "status" => "pending",
      "created_at" => timestamp,
      "expires_at" => timestamp + [ttl.to_i, 1].max,
      "updated_at" => timestamp
    )
    InvitationResult.new(invitation: inserted, created: true)
  end

  def pending_for(recipient, tables:, now: GameRoomClock.now.to_i)
    table_by_id = tables.to_a.each_with_object({}) do |table, result|
      id = row_id(table)
      result[id] = table if id > 0 && %w[waiting playing].include?(table["status"].to_s)
    end

    if native_live_sessions?
      rows = (@notification_source == nil ? [] : @notification_source.call(recipient, now)) + @transport.pending_invitations
      return rows.uniq { |row| row_id(row) }.filter_map do |row|
        next if !same_user?(row["recipient"], recipient)
        next if row["expires_at"].to_i.positive? && row["expires_at"].to_i <= now.to_i
        next if @responses.key?([row_id(row), recipient.to_s.downcase])

        table = table_by_id[row["table_id"].to_i]
        next if table != nil && !row["live_session_id"].to_s.empty? && row["live_session_id"].to_s != table["__live_session_id"].to_s
        table == nil ? nil : PendingInvitation.new(invitation: row, table: table)
      end
    end

    pending_rows(recipient, now: now).filter_map do |row|
      table = table_by_id[row["table_id"].to_i]
      table == nil ? nil : PendingInvitation.new(invitation: row, table: table)
    end
  end

  def pending_by_id(id, recipient, tables:, now: GameRoomClock.now.to_i)
    wanted = id.to_i
    return nil if wanted <= 0

    pending_for(recipient, tables: tables, now: now).find { |pending| pending.id == wanted }
  end

  def respond(invitation, recipient:, response:, now: GameRoomClock.now.to_i)
    row = invitation.respond_to?(:invitation) ? invitation.invitation : invitation
    invitation_id = row_id(row)
    clean_recipient = recipient.to_s.strip
    clean_response = response.to_s
    raise ArgumentError, "Invalid invitation" if invitation_id <= 0
    raise ArgumentError, "Invitation belongs to another user" if !same_user?(row["recipient"], clean_recipient)
    raise ArgumentError, "Invalid invitation response" if !RESPONSES.include?(clean_response)

    if native_live_sessions?
      key = [invitation_id, clean_recipient.downcase]
      return @responses[key] if @responses.key?(key)

      decision = {
        "__id" => invitation_id,
        "invitation_id" => invitation_id,
        "table_id" => row["table_id"].to_i,
        "recipient" => clean_recipient,
        "response" => clean_response,
        "created_at" => now.to_i
      }
      if @response_sender
        outbox = @response_outbox ||= InvitationResponseOutbox.default
        decision["response"] = outbox.submit(row, clean_response, &@response_sender)
      end
      return @responses[key] = decision
    end

    existing = response_rows(clean_recipient).find do |candidate|
      candidate["invitation_id"].to_i == invitation_id
    end
    return existing if existing != nil

    responses_table.insert(
      "invitation_id" => invitation_id,
      "table_id" => row["table_id"].to_i,
      "recipient" => clean_recipient,
      "response" => clean_response,
      "created_at" => now.to_i
    )
  end

  private

  def native_live_sessions?
    @transport.respond_to?(:live_store?) && @transport.live_store?
  end

  def invitations_table
    @invitations_table ||= @server_tables.fetch("invitations")
  end

  def responses_table
    @responses_table ||= @server_tables.fetch("invitation_responses")
  end

  def pending_rows(recipient, now:)
    clean_recipient = recipient.to_s.strip
    return [] if clean_recipient.empty?

    resolved_ids = response_rows(clean_recipient).map { |row| row["invitation_id"].to_i }
    invitations_table
      .select(
        where: { "recipient" => clean_recipient },
        order: [["created_at", "desc"]],
        limit: INVITATION_LIMIT
      )
      .to_a
      .select do |row|
        row_id(row) > 0 &&
          row["status"].to_s == "pending" &&
          row["expires_at"].to_i > now.to_i &&
          !resolved_ids.include?(row_id(row)) &&
          valid_sender?(row)
      end
  end

  def response_rows(recipient)
    responses_table
      .select(
        where: { "recipient" => recipient.to_s.strip },
        order: [["created_at", "desc"]],
        limit: RESPONSE_LIMIT
      )
      .to_a
      .select do |row|
        author = row["__insertion_user"].to_s
        author.empty? || same_user?(author, recipient)
      end
  end

  def valid_sender?(row)
    sender = row["sender"].to_s
    author = row["__insertion_user"].to_s
    !sender.empty? && (author.empty? || same_user?(sender, author))
  end

  def invitation_sender(row)
    author = row["__insertion_user"].to_s
    author.empty? ? row["sender"].to_s : author
  end

  def row_id(row)
    return 0 if row == nil

    (row["__id"] || row["id"]).to_i
  end

  def same_user?(first, second)
    !first.to_s.empty? && first.to_s.casecmp(second.to_s) == 0
  end
end
