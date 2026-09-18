require_relative "game_participants"
require_relative "live_session_store"
require "json"
require "securerandom"

class GameRoomTransport
  PROTOCOL_VERSION = 1
  LIVE_SESSION_KIND = "elten_game_room_table".freeze
  LIVE_SESSION_PROTOCOL = 1
  LIVE_SESSION_MAX_CAPACITY = 8
  MAX_IDENTIFIER = (2**63) - 1
  MAX_USERNAME_LENGTH = 64
  MAX_SEEN_PACKETS = 512
  SEEN_PACKET_TTL = 300.0
  PACKET_ID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
  GAME_CHANGES = ["action", "started"].freeze

  DeliveryResult = Struct.new(:status, :recipients, :error, keyword_init: true) do
    STATUSES = [:sent, :no_session, :no_recipient, :failed].freeze

    def initialize(status:, recipients: [], error: nil)
      normalized_status = status.to_sym
      raise ArgumentError, "unsupported delivery status" if !STATUSES.include?(normalized_status)

      super(status: normalized_status, recipients: recipients.to_a.map(&:to_s).freeze, error: error)
    end

    def sent?
      status == :sent
    end
  end

  # LiveSessions cannot discover a user who manually joined a public table:
  # only the session owner may invite that user. Keep one transient Signal for
  # that membership handshake, but never use Signals for table or game events.
  class MembershipBootstrapBackend
    def initialize(program)
      @program = program
      @client = EltenLink::Client.new
    end

    def request(owner:, packet:)
      EltenLink::Apps.signal(
        @client,
        appid: @program.class.app_uuid,
        user: owner.to_s,
        packet: packet
      )
      true
    rescue EltenLink::Error => error
      Log.warning("ELTEN Game Room membership bootstrap failed for #{owner}: #{error.class}: #{error.message}")
      false
    end
  end

  class HybridBackend
    def initialize(bootstrap:, live:)
      @bootstrap = bootstrap
      @live = live
    end

    def start
      @live.start
    end

    def activate_table(table_id:, owner:, capacity:)
      @live.activate_table(table_id: table_id, owner: owner, capacity: capacity)
    end

    def deactivate_table(table_id:)
      @live.deactivate_table(table_id: table_id)
    end

    def invite_user(table_id:, user:, metadata:)
      @live.invite_user(table_id: table_id, user: user, metadata: metadata)
    end

    def accept_invitation(table_id:, invitation_id:, participant_metadata:)
      @live.accept_invitation(
        table_id: table_id,
        invitation_id: invitation_id,
        participant_metadata: participant_metadata
      )
    end

    def reject_invitation(table_id:, invitation_id:)
      @live.reject_invitation(table_id: table_id, invitation_id: invitation_id)
    end

    def request_membership(table_id:, owner:, packet:)
      connected = @live.connected_users(table_id)
      return true if connected.any? { |user| user.casecmp(owner.to_s) == 0 }

      Log.debug("ELTEN Game Room requested LiveSessions membership for table #{table_id}") if defined?(Log)
      @bootstrap.request(owner: owner, packet: packet)
    end

    def wait_for_membership(table_id:, timeout:)
      @live.wait_for_membership(table_id: table_id, timeout: timeout)
    end

    def connected_users(table_id)
      @live.connected_users(table_id)
    end

    def participant_announced(table_id:, user:)
      @live.invite_participant(table_id: table_id, user: user)
    end

    def table_joined(users:, packet:)
      publish(users: users, packet: packet)
    end

    def publish(users:, packet:)
      @live.publish(users: users, packet: packet)
    end
  end

  class LiveSessionBackend
    class InvitationExchange
      ENTRY_TTL = 300
      RESOLVED_TTL = 300

      def initialize
        @invitations = {}
        @resolutions = {}
        @resolved = {}
        @mutex = Mutex.new
      end

      def take_or_defer(recipient:, table_id:, invitation_id:, resolution:)
        key = exchange_key(recipient, table_id, invitation_id)
        @mutex.synchronize do
          prune
          return [:resolved, nil, key] if @resolved.key?(key)

          stored = @invitations.delete(key)
          if stored == nil
            @resolutions[key] = { value: resolution, expires_at: Time.now.to_i + ENTRY_TTL }
            [:deferred, nil, key]
          else
            [:ready, stored[:invitation], key]
          end
        end
      end

      def receive(recipient:, table_id:, invitation_id:, invitation:)
        key = exchange_key(recipient, table_id, invitation_id)
        @mutex.synchronize do
          prune
          return [:ignored, nil, key] if @resolved.key?(key) || @invitations.key?(key)

          stored_resolution = @resolutions.delete(key)
          if stored_resolution == nil
            @invitations[key] = { invitation: invitation, expires_at: Time.now.to_i + ENTRY_TTL }
            [:stored, nil, key]
          else
            [:resolve, stored_resolution[:value], key]
          end
        end
      end

      def mark_resolved(key)
        @mutex.synchronize do
          @invitations.delete(key)
          @resolutions.delete(key)
          @resolved[key] = Time.now.to_i + RESOLVED_TTL
        end
      end

      def clear(recipient:, table_id:)
        prefix = [recipient.to_s.downcase, table_id.to_i]
        @mutex.synchronize do
          [@invitations, @resolutions, @resolved].each do |collection|
            collection.delete_if { |key, _value| key[0, 2] == prefix }
          end
        end
      end

      private

      def exchange_key(recipient, table_id, invitation_id)
        [recipient.to_s.downcase, table_id.to_i, invitation_id.to_i]
      end

      def prune
        now = Time.now.to_i
        @invitations.delete_if do |_key, stored|
          stored[:expires_at].to_i <= now || !stored[:invitation].pending?
        end
        @resolutions.delete_if { |_key, stored| stored[:expires_at].to_i <= now }
        @resolved.delete_if { |_key, expires_at| expires_at.to_i <= now }
      end
    end

    def self.supported?
      defined?(EltenAPI::LiveSessions::Endpoint) && EltenAPI::LiveSessions::Endpoint != nil
    end

    def self.invitation_exchange
      @invitation_exchange ||= InvitationExchange.new
    end

    def initialize(
      program,
      receiver:,
      membership_receiver: nil,
      gap_receiver: nil,
      endpoint_provider: nil
    )
      @program = program
      @receiver = receiver
      @membership_receiver = membership_receiver
      @gap_receiver = gap_receiver
      @endpoint_provider = endpoint_provider || -> { @program.live_sessions }
      @sessions = {}
      @active_tables = {}
      @membership_invitations = Hash.new { |hash, key| hash[key] = {} }
      @endpoint = nil
      @mutex = Mutex.new
      @session_condition = ConditionVariable.new
    end

    def start
      endpoint = endpoint()
      register_invitation_callback(endpoint)
      true
    rescue StandardError => error
      log_warning("startup", nil, error)
      false
    end

    def activate_table(table_id:, owner:, capacity:)
      id = positive_identifier(table_id)
      return false if id == nil

      endpoint = endpoint()
      @program_user = endpoint.user.to_s
      @mutex.synchronize do
        @active_tables[id] = { owner: owner.to_s, capacity: session_capacity(capacity) }
      end
      return true if active_session(id) != nil
      return false if endpoint.user.to_s.casecmp(owner.to_s) != 0

      session = endpoint.create(
        metadata: session_metadata(id, owner),
        participant_metadata: participant_metadata(id),
        capacity: session_capacity(capacity)
      )
      attach_session(id, session)
      log_debug("created live session", id)
      true
    rescue StandardError => error
      log_warning("activation", table_id, error)
      false
    end

    def invite_user(table_id:, user:, metadata:)
      id = positive_identifier(table_id)
      session = id == nil ? nil : active_session(id)
      return false if session == nil

      session.invite(user.to_s, metadata: metadata.to_h.merge("purpose" => "game_invitation"))
      true
    rescue StandardError => error
      log_warning("invitation", table_id, error)
      false
    end

    def accept_invitation(table_id:, invitation_id:, participant_metadata:)
      id = positive_identifier(table_id)
      wanted = positive_identifier(invitation_id)
      return false if id == nil || wanted == nil

      resolution = {
        backend: self,
        action: :accept,
        participant_metadata: participant_metadata.to_h.dup
      }
      status, invitation, key = self.class.invitation_exchange.take_or_defer(
        recipient: endpoint().user,
        table_id: id,
        invitation_id: wanted,
        resolution: resolution
      )
      return true if status == :deferred || status == :resolved

      complete_invitation_resolution(id, invitation, resolution)
      self.class.invitation_exchange.mark_resolved(key)
      true
    rescue StandardError => error
      log_warning("invitation acceptance", table_id, error)
      false
    end

    def reject_invitation(table_id:, invitation_id:)
      id = positive_identifier(table_id)
      wanted = positive_identifier(invitation_id)
      return false if id == nil || wanted == nil

      resolution = { backend: self, action: :reject }
      status, invitation, key = self.class.invitation_exchange.take_or_defer(
        recipient: endpoint().user,
        table_id: id,
        invitation_id: wanted,
        resolution: resolution
      )
      return true if status == :deferred || status == :resolved

      complete_invitation_resolution(id, invitation, resolution)
      self.class.invitation_exchange.mark_resolved(key)
      true
    rescue StandardError => error
      log_warning("invitation rejection", table_id, error)
      false
    end

    def connected_users(table_id)
      id = positive_identifier(table_id)
      session = id == nil ? nil : active_session(id)
      return [] if session == nil

      session.participants.map { |participant| participant.user.to_s }.reject(&:empty?)
    rescue StandardError => error
      log_warning("participant lookup", table_id, error)
      []
    end

    def wait_for_membership(table_id:, timeout:)
      id = positive_identifier(table_id)
      return false if id == nil

      deadline = monotonic + [timeout.to_f, 0.0].max
      @mutex.synchronize do
        loop do
          session = @sessions[id]
          return true if session != nil && !session.closed?

          remaining = deadline - monotonic
          return false if remaining <= 0

          @session_condition.wait(@mutex, remaining)
        end
      end
    rescue StandardError => error
      log_warning("membership wait", table_id, error)
      false
    end

    def deactivate_table(table_id:)
      id = positive_identifier(table_id)
      return false if id == nil

      session = @mutex.synchronize { @sessions.delete(id) }
      @mutex.synchronize do
        @active_tables.delete(id)
        @membership_invitations.delete(id)
        @session_condition.broadcast
      end
      self.class.invitation_exchange.clear(recipient: endpoint().user, table_id: id)
      return false if session == nil

      if session.owner?
        session.close
      else
        session.leave
      end
      log_debug("left live session", id)
      true
    rescue StandardError => error
      log_warning("deactivation", table_id, error)
      false
    end

    def publish(users:, packet:)
      id = positive_identifier(packet["table_id"])
      return DeliveryResult.new(status: :failed) if id == nil

      session = active_session(id)
      if session == nil
        log_debug("could not publish #{packet["type"]}: no live session", id)
        return DeliveryResult.new(status: :no_session)
      end

      connected = connected_recipients(session, users)
      if connected.empty?
        log_debug("could not publish #{packet["type"]}: no requested recipient is connected", id)
        return DeliveryResult.new(status: :no_recipient)
      end

      session.send(packet)
      log_debug("published #{packet["type"]} through live session to #{connected.size} recipient(s)", id)
      DeliveryResult.new(status: :sent, recipients: connected)
    rescue StandardError => error
      log_warning("publish", packet["table_id"], error)
      DeliveryResult.new(status: :failed, error: error)
    end

    def invite_participant(table_id:, user:)
      id = positive_identifier(table_id)
      session = id == nil ? nil : active_session(id)
      target = user.to_s
      return false if session == nil || target.empty? || !session.owner?
      return true if session.participants.any? { |participant| participant.user.to_s.casecmp(target) == 0 }

      should_invite = @mutex.synchronize do
        last = @membership_invitations[id][target.downcase]
        next false if last != nil && monotonic - last < 10.0

        @membership_invitations[id][target.downcase] = monotonic
        true
      end
      return true if !should_invite

      session.invite(
        target,
        metadata: {
          "purpose" => "table_membership",
          "table_id" => id
        }
      )
      log_debug("invited #{target} to live session", id)
      true
    rescue StandardError => error
      log_warning("membership invitation", table_id, error)
      false
    end

    private

    def endpoint
      current = @endpoint_provider.call
      changed = @mutex.synchronize do
        different = !@endpoint.equal?(current)
        @endpoint = current
        different
      end
      register_invitation_callback(current) if changed
      @program_user = current.user.to_s
      current
    end

    def register_invitation_callback(endpoint)
      register = @mutex.synchronize do
        next false if @invitation_endpoint.equal?(endpoint)

        @invitation_endpoint = endpoint
        true
      end
      return if !register

      endpoint.on_invitation { |invitation| receive_invitation(invitation) }
      drain_pending_invitations(endpoint)
    end

    def drain_pending_invitations(endpoint)
      return if !endpoint.respond_to?(:next_invitation)

      loop do
        invitation = endpoint.next_invitation(timeout: 0)
        break if invitation == nil

        receive_invitation(invitation)
      end
    rescue StandardError => error
      log_warning("pending invitation recovery", nil, error)
    end

    def receive_invitation(invitation)
      return if invitation.respond_to?(:pending?) && !invitation.pending?

      metadata = invitation.metadata.to_h
      return if metadata["kind"].to_s != LIVE_SESSION_KIND
      return if metadata["protocol"].to_i != LIVE_SESSION_PROTOCOL

      table_id = positive_identifier(metadata["table_id"])
      return if table_id == nil

      invitation_metadata = invitation.invitation_metadata.to_h
      if invitation_metadata["purpose"].to_s == "table_membership"
        if active_table?(table_id, metadata["owner"])
          session = invitation.accept(participant_metadata: participant_metadata(table_id))
          attach_session(table_id, session)
          log_debug("accepted live session membership", table_id)
        else
          invitation.reject
          log_debug("rejected late live session membership", table_id)
        end
        return
      end

      wanted = positive_identifier(invitation_metadata["invitation_id"])
      return if invitation_metadata["purpose"].to_s != "game_invitation" || wanted == nil

      status, resolution, key = self.class.invitation_exchange.receive(
        recipient: recipient_identity,
        table_id: table_id,
        invitation_id: wanted,
        invitation: invitation
      )
      if status == :resolve
        backend = resolution[:backend]
        backend.send(:complete_invitation_resolution, table_id, invitation, resolution)
        self.class.invitation_exchange.mark_resolved(key)
        log_debug("resolved shared live session invitation", table_id)
      elsif status == :stored
        log_debug("received live session invitation", table_id)
      end
    rescue StandardError => error
      log_warning("incoming invitation", nil, error)
    end

    def complete_invitation_resolution(table_id, invitation, resolution)
      if resolution[:action] == :reject
        invitation.reject
      else
        session = invitation.accept(participant_metadata: resolution[:participant_metadata].to_h)
        attach_session(table_id, session)
      end
      true
    end

    def recipient_identity
      value = @program_user.to_s
      value = @endpoint.user.to_s if value.empty? && @endpoint != nil
      value
    end

    def session_metadata(table_id, owner)
      {
        "kind" => LIVE_SESSION_KIND,
        "protocol" => LIVE_SESSION_PROTOCOL,
        "table_id" => table_id,
        "owner" => owner.to_s
      }
    end

    def participant_metadata(table_id)
      { "table_id" => table_id }
    end

    def session_capacity(requested)
      [[requested.to_i, 2].max, LIVE_SESSION_MAX_CAPACITY].min
    end

    def attach_session(table_id, session)
      session.on_message do |sender, packet|
        receive_message(table_id, sender, packet)
      end
      session.on_closed do |_reason|
        @mutex.synchronize do
          @sessions.delete(table_id) if @sessions[table_id].equal?(session)
          @session_condition.broadcast
        end
        @membership_receiver&.call(table_id, @program_user.to_s, :closed)
      end
      session.on_gap do |from, to|
        log_debug("detected live session gap #{from}-#{to}", table_id)
        @gap_receiver&.call(table_id, from, to)
      end
      session.on_participant_joined do |participant|
        participant_changed(table_id, participant, :joined)
      end
      session.on_participant_left do |participant, _reason = nil|
        participant_changed(table_id, participant, :left)
      end
      previous = @mutex.synchronize do
        replaced = @sessions[table_id]
        @sessions[table_id] = session
        @session_condition.broadcast
        replaced
      end
      close_replaced_session(previous, session)
      session
    end

    def participant_changed(table_id, participant, change)
      user = participant.respond_to?(:user) ? participant.user.to_s : ""
      @mutex.synchronize { @membership_invitations[table_id].delete(user.downcase) }
      log_debug("participant #{change}: #{user}", table_id)
      @membership_receiver&.call(table_id, user, change)
    rescue StandardError => error
      log_warning("participant callback", table_id, error)
    end

    def close_replaced_session(previous, current)
      return if previous == nil || previous.equal?(current)

      previous.owner? ? previous.close : previous.leave
    rescue StandardError
      nil
    end

    def receive_message(table_id, sender, packet)
      return if !packet.is_a?(Hash)

      log_debug("received #{packet["type"]} through live session", table_id)
      @receiver.call(sender.user.to_s, packet)
    rescue StandardError => error
      log_warning("receive", table_id, error)
    end

    def connected_recipients(session, requested)
      session.participants.each_with_object([]) do |participant, result|
        user = participant.user.to_s
        next if user.empty?
        next if !requested.any? { |candidate| candidate.to_s.casecmp(user) == 0 }

        result << user
      end
    end

    def active_session(table_id)
      @mutex.synchronize do
        session = @sessions[table_id]
        if session != nil && session.closed?
          @sessions.delete(table_id)
          session = nil
        end
        session
      end
    end

    def active_table?(table_id, owner)
      @mutex.synchronize do
        table = @active_tables[table_id]
        table != nil && table[:owner].to_s.casecmp(owner.to_s) == 0
      end
    end

    def positive_identifier(value)
      id = Integer(value.to_s, 10)
      id if id > 0
    rescue ArgumentError, TypeError
      nil
    end

    def log_warning(stage, table_id, error)
      return if !defined?(Log)

      suffix = table_id == nil ? "" : " for table #{table_id}"
      Log.warning("ELTEN Game Room live session #{stage} failed#{suffix}: #{error.class}: #{error.message}")
    end

    def log_debug(message, table_id)
      return if !defined?(Log)

      suffix = table_id == nil ? "" : " for table #{table_id}"
      Log.debug("ELTEN Game Room #{message}#{suffix}")
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    rescue Exception
      Time.now.to_f
    end
  end

  def initialize(program, backend: nil)
    @program = program
    @live_store = backend == nil ? GameRoomLiveSessionStore.new(program, changed: method(:live_store_changed)) : nil
    @backend = backend
    @pending_table_changes = {}
    @pending_game_changes = {}
    @pending_game_starts = {}
    @pending_recoveries = {}
    @newly_joined = {}
    @seen_packets = {}
    @mutex = Mutex.new
  end

  def start
    return @live_store.start if live_store?
    return true if !@backend.respond_to?(:start)

    @backend.start
  end

  def live_store?
    @live_store != nil
  end

  def reconcile(table_id)
    @live_store.reconcile(table_id) if live_store?
  end

  def pending_move_error(table_id)
    @live_store.pending_move_error(table_id) if live_store?
  end

  def consume_recovered_game_events(session)
    live_store? ? @live_store.consume_recovered_game_events(session) : []
  end

  def send_private_game(**arguments)
    raise IOError, "Private game messages require LiveSessions" unless live_store?
    @live_store.send_private_game(**arguments)
  end

  def private_game_messages_pending?(table_id, session_id)
    live_store? && @live_store.private_game_messages_pending?(table_id, session_id)
  end

  def take_private_game_messages(table_id, session_id)
    live_store? ? @live_store.take_private_game_messages(table_id, session_id) : []
  end

  def create_room(**arguments)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.create_room(**arguments)
  end

  def discover_rooms(game: nil, include_private: false)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.discover_rooms(game: game, include_private: include_private)
  end

  def current_room(user)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.current_room(user)
  end

  def room_snapshot(table_or_id, force: false)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.room_snapshot(table_or_id, force: force)
  end

  def set_observer(table_or_id, observing, actor:)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.set_observer(table_or_id, observing, actor: actor)
  end

  def join_room(table, user)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.join_room(table, user)
  end

  def update_room(table_or_id, changes, actor:)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.update_room(table_or_id, changes, actor: actor)
  end

  def change_game_options(**arguments)
    raise "The native LiveSessions store is unavailable" if !live_store?
    @live_store.change_game_options(**arguments)
  end

  def abort_game(session)
    raise "The native LiveSessions store is unavailable" if !live_store?
    @live_store.abort_game(session)
  end

  def append_activity(**arguments)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.append_activity(**arguments)
  end

  def activity_records(table_or_id)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.activity_records(table_or_id)
  end

  def start_game(**arguments)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.start_game(**arguments)
  end

  def game_sessions(table_or_id = nil, force: false)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.game_sessions(table_or_id, force: force)
  end

  def game_session(session_id, table: nil)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.game_session(session_id, table: table)
  end

  def append_game_action(**arguments)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.append_game_action(**arguments)
  end

  def game_events(session, force: false)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.game_events(session, force: force)
  end

  def freeze_game(session, frozen: true)
    raise "The native LiveSessions store is unavailable" if !live_store?

    @live_store.freeze_game(session, frozen: frozen)
  end

  def pending_invitations
    return [] if !live_store?

    @live_store.pending_invitations
  end

  def reject_discovered_invitation(table)
    raise "The native LiveSessions store is unavailable" if !live_store?
    @live_store.reject_discovered_invitation(table)
  end

  def activate_table(table_id:, owner:, capacity:, user: nil)
    if live_store?
      room = @live_store.current_room(user || owner)
      return room != nil && room["__id"].to_i == table_id.to_i
    end
    return false if !@backend.respond_to?(:activate_table)

    @backend.activate_table(table_id: table_id, owner: owner, capacity: capacity)
  end

  def establish_membership(table_id:, owner:, capacity:, user:, invitation_id: nil, bootstrap: false, timeout: 10.0, table: nil)
    current_user = user.to_s
    return false if current_user.empty?

    if live_store?
      current = @live_store.current_room(current_user)
      return true if current != nil && current["__id"].to_i == table_id.to_i

      if invitation_id != nil
        accepted = @live_store.accept_invitation(
          table_id: table_id,
          invitation_id: invitation_id,
          participant_metadata: { "table_id" => table_id.to_i }
        )
        @mutex.synchronize { @newly_joined[[table_id.to_i, current_user.downcase]] = true } if accepted
        return accepted
      end
      status = establish_membership_status(table_id: table_id, owner: owner, capacity: capacity, user: current_user, table: table)
      return [:joined, :already_here].include?(status)
    end

    activate_table(table_id: table_id, owner: owner, capacity: capacity, user: current_user)
    request_started = if current_user.casecmp(owner.to_s) == 0
      true
    elsif invitation_id != nil
      accept_invitation(
        table_id: table_id,
        invitation_id: invitation_id,
        participant_metadata: { "table_id" => table_id.to_i }
      )
    elsif bootstrap
      request_membership(table_id: table_id, owner: owner, user: current_user)
    else
      true
    end
    return false if !request_started

    connected = wait_for_membership(table_id: table_id, timeout: timeout)
    return true if connected

    reject_invitation(table_id: table_id, invitation_id: invitation_id) if invitation_id != nil
    deactivate_table(table_id: table_id)
    false
  end

  def establish_membership_status(table_id:, owner:, capacity:, user:, table: nil)
    raise "The native LiveSessions store is unavailable" if !live_store?
    candidate = table || { "__id" => table_id, "owner" => owner, "max_players" => capacity }
    status = @live_store.join_room(candidate, user.to_s)
    @mutex.synchronize { @newly_joined[[table_id.to_i, user.to_s.downcase]] = true } if status == :joined
    status
  end

  def request_membership(table_id:, owner:, user:)
    return false if live_store?
    return false if !@backend.respond_to?(:request_membership)

    current_user = user.to_s
    return false if current_user.empty?
    return true if current_user.casecmp(owner.to_s) == 0

    @backend.request_membership(
      table_id: table_id,
      owner: owner,
      packet: packet_envelope(current_user).merge(
        "type" => "game_room_transport_join",
        "table_id" => table_id.to_i
      )
    )
  end

  def wait_for_membership(table_id:, timeout: 10.0)
    return @live_store.wait_for_room(table_id, timeout: timeout) if live_store?
    return false if !@backend.respond_to?(:wait_for_membership)

    @backend.wait_for_membership(table_id: table_id, timeout: timeout)
  end

  def deactivate_table(table_id:)
    return @live_store.deactivate_room(table_id) if live_store?
    return false if !@backend.respond_to?(:deactivate_table)

    @backend.deactivate_table(table_id: table_id)
  end

  def connected_users(table_id)
    return @live_store.connected_users(table_id) if live_store?
    return nil if !@backend.respond_to?(:connected_users)

    @backend.connected_users(table_id)
  end

  def consume_new_join(table_id, user)
    return false if !live_store?

    @mutex.synchronize { @newly_joined.delete([table_id.to_i, user.to_s.downcase]) == true }
  end

  def invite_user(table_id:, user:, metadata:)
    return @live_store.invite_user(table_id: table_id, user: user, metadata: metadata) if live_store?
    return false if !@backend.respond_to?(:invite_user)

    @backend.invite_user(table_id: table_id, user: user, metadata: metadata)
  end

  def accept_invitation(table_id:, invitation_id:, participant_metadata: {})
    if live_store?
      return @live_store.accept_invitation(
        table_id: table_id,
        invitation_id: invitation_id,
        participant_metadata: participant_metadata
      )
    end
    return false if !@backend.respond_to?(:accept_invitation)

    @backend.accept_invitation(
      table_id: table_id,
      invitation_id: invitation_id,
      participant_metadata: participant_metadata
    )
  end

  def reject_invitation(table_id:, invitation_id:)
    return @live_store.reject_invitation(table_id: table_id, invitation_id: invitation_id) if live_store?
    return false if !@backend.respond_to?(:reject_invitation)

    @backend.reject_invitation(table_id: table_id, invitation_id: invitation_id)
  end

  def receive(user, packet)
    normalized = validate_packet(user, packet)
    return false if normalized == nil

    announce_participant = false
    @mutex.synchronize do
      prune_seen_packets
      return false if @seen_packets.key?(normalized["packet_id"])

      @seen_packets[normalized["packet_id"]] = monotonic_time
      prune_seen_packets
      case normalized["type"]
      when "game_room_table_changed"
        @pending_table_changes[normalized["table_id"]] = true
      when "game_room_game_changed"
        session_id = normalized["session_id"]
        table_id = normalized["table_id"]
        @pending_game_changes[session_id] ||= monotonic_time
        if normalized["change"] == "started"
          @pending_game_starts[table_id] = session_id
        end
      when "game_room_transport_join"
        announce_participant = true
      end
    end
    if announce_participant && @backend.respond_to?(:participant_announced)
      @backend.participant_announced(table_id: normalized["table_id"], user: normalized["actor"])
    end
    true
  end

  def table_changed(table_id:, users:, actor:)
    return DeliveryResult.new(status: :sent) if live_store?
    id = table_id.to_i
    return if id <= 0

    publish(
      users,
      actor: actor,
      packet: packet_envelope(actor).merge(
        "type" => "game_room_table_changed",
        "table_id" => id
      )
    )
  end

  def table_joined(table_id:, users:, actor:)
    return DeliveryResult.new(status: :sent) if live_store?
    id = table_id.to_i
    return if id <= 0

    recipients = recipients_for(users, actor)
    packet = packet_envelope(actor).merge(
      "type" => "game_room_table_changed",
      "table_id" => id
    )
    if @backend.respond_to?(:table_joined)
      @backend.table_joined(users: recipients, packet: packet)
    else
      @backend.publish(users: recipients, packet: packet)
    end
  end

  def game_changed(table_id:, session_id:, users:, change:, actor:)
    return DeliveryResult.new(status: :sent) if live_store?
    table = table_id.to_i
    session = session_id.to_i
    return if table <= 0 || session <= 0

    recipients = recipients_for(users, actor)
    return DeliveryResult.new(status: :sent) if recipients.empty?

    packet = packet_envelope(actor).merge(
      "type" => "game_room_game_changed",
      "change" => change.to_s,
      "table_id" => table,
      "session_id" => session
    )
    result = publish_to_backend(recipients, packet)
    @mutex.synchronize { @pending_recoveries[table] = true } if result.status == :no_session
    result
  end

  def consume_table_change(table_id)
    @mutex.synchronize { @pending_table_changes.delete(table_id.to_i) == true }
  end

  def consume_game_change(session_id)
    @mutex.synchronize { @pending_game_changes.delete(session_id.to_i) }
  end

  def consume_game_start(table_id)
    @mutex.synchronize do
      session_id = @pending_game_starts.delete(table_id.to_i).to_i
      session_id > 0 ? session_id : nil
    end
  end

  def consume_recovery(table_id)
    @mutex.synchronize { @pending_recoveries.delete(table_id.to_i) }
  end

  private

  def live_store_changed(table_id, kind, value)
    @mutex.synchronize do
      case kind.to_sym
      when :game_started
        @pending_game_starts[table_id.to_i] = value.to_i if value.to_i.positive?
        @pending_table_changes[table_id.to_i] = true
      when :game
        @pending_game_changes[value.to_i] ||= monotonic_time if value.to_i.positive?
      when :closed
        @pending_recoveries[table_id.to_i] = :closed
      when :recovery
        @pending_recoveries[table_id.to_i] ||= true
        @pending_table_changes[table_id.to_i] = true
      when :network_error
        @pending_recoveries[table_id.to_i] = value if @pending_recoveries[table_id.to_i] != :closed
      when :table
        @pending_table_changes[table_id.to_i] = true
      end
    end
  end

  def default_backend(program)
    if program == nil || !LiveSessionBackend.supported?
      raise "ELTEN Game Room requires the LiveSessions API"
    end

    live = LiveSessionBackend.new(
      program,
      receiver: method(:receive),
      membership_receiver: method(:session_membership_changed),
      gap_receiver: method(:session_gap)
    )
    HybridBackend.new(
      bootstrap: MembershipBootstrapBackend.new(program),
      live: live
    )
  end

  def session_membership_changed(table_id, _user, change)
    @mutex.synchronize do
      if change.to_sym == :closed
        @pending_recoveries[table_id.to_i] = true
      else
        @pending_table_changes[table_id.to_i] = true
      end
    end
  end

  def session_gap(table_id, _from, _to)
    @mutex.synchronize { @pending_recoveries[table_id.to_i] = true }
  end

  def packet_envelope(actor)
    {
      "version" => PROTOCOL_VERSION,
      "packet_id" => SecureRandom.uuid,
      "actor" => actor.to_s
    }
  end

  def validate_packet(user, packet)
    return nil if !packet.is_a?(Hash)
    return nil if strict_integer(packet["version"]) != PROTOCOL_VERSION

    sender = user.to_s
    actor = packet["actor"].to_s
    return nil if sender.empty? || sender.length > MAX_USERNAME_LENGTH
    return nil if actor.empty? || actor.length > MAX_USERNAME_LENGTH
    return nil if sender.casecmp(actor) != 0

    packet_id = packet["packet_id"].to_s
    return nil if !PACKET_ID_PATTERN.match?(packet_id)

    type = packet["type"].to_s
    table_id = valid_identifier(packet["table_id"])
    return nil if table_id == nil

    normalized = {
      "version" => PROTOCOL_VERSION,
      "packet_id" => packet_id.downcase,
      "actor" => actor,
      "type" => type,
      "table_id" => table_id
    }
    case type
    when "game_room_table_changed"
      normalized
    when "game_room_transport_join"
      normalized
    when "game_room_game_changed"
      session_id = valid_identifier(packet["session_id"])
      change = packet["change"].to_s
      return nil if session_id == nil || !GAME_CHANGES.include?(change)

      normalized.merge("session_id" => session_id, "change" => change)
    else
      nil
    end
  end

  def strict_integer(value)
    return value if value.is_a?(Integer)
    return Integer(value, 10) if value.is_a?(String) && value.match?(/\A\d+\z/)

    nil
  rescue ArgumentError, TypeError
    nil
  end

  def valid_identifier(value)
    id = strict_integer(value)
    id if id != nil && id.between?(1, MAX_IDENTIFIER)
  end

  def prune_seen_packets
    now = monotonic_time
    @seen_packets.delete_if { |_packet_id, received_at| now - received_at > SEEN_PACKET_TTL }
    overflow = @seen_packets.length - MAX_SEEN_PACKETS
    return if overflow <= 0

    @seen_packets.sort_by { |_packet_id, received_at| received_at }
      .first(overflow)
      .each { |packet_id, _received_at| @seen_packets.delete(packet_id) }
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  rescue Exception
    Time.now.to_f
  end

  def publish(users, actor:, packet:)
    recipients = recipients_for(users, actor)
    return DeliveryResult.new(status: :sent) if recipients.empty?

    publish_to_backend(recipients, packet)
  end

  def publish_to_backend(recipients, packet)
    result = @backend.publish(users: recipients, packet: packet)
    return result if result.is_a?(DeliveryResult)
    return DeliveryResult.new(status: :sent, recipients: result) if result.is_a?(Array)
    return DeliveryResult.new(status: :sent, recipients: recipients) if result == true

    DeliveryResult.new(status: :failed)
  rescue StandardError => error
    if defined?(Log)
      Log.warning(
        "ELTEN Game Room transport publish failed for table #{packet["table_id"]}: " \
        "#{error.class}: #{error.message}"
      )
    end
    DeliveryResult.new(status: :failed, error: error)
  end

  def recipients_for(users, actor)
    unique_users(users).reject do |user|
      user.casecmp(actor.to_s) == 0
    end
  end

  def unique_users(users)
    result = []
    users.to_a.each do |user|
      value = user.to_s
      next if value.empty? || GameRoomParticipants.bot?(value)
      next if result.any? { |candidate| candidate.casecmp(value) == 0 }

      result << value
    end
    result
  end
end
