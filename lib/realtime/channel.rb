require 'digest'
require_relative '../game_room_background'
require_relative 'protocol'

module GameRoomRealtime
  # The only owner of Game Room's Communications endpoint. Sessions remain
  # private even for a public table. No per-frame network wait, retry loop,
  # background UI calls, application notifications, or original Pong service.
  class Channel
    attr_reader :epoch, :last_error

    def initialize(program:, match:, owner:, viewer:, clock:, members:, work: nil)
      @program, @match, @owner, @viewer = program, match, owner.to_s, viewer.to_s
      @clock, @members = clock, members
      @work = work || GameRoomBackground::Work.new
      @closed = false
      @next_retry = 0.0
      @invited_at = {}
      @incoming = {} # One newest packet per authenticated member, bounded by roster.
      @pending_invitation = nil
      @resource_lock = Mutex.new
    end

    def host?; @owner.casecmp?(@viewer); end
    def connected?; @session != nil && @session.state == :open && @endpoint && !@endpoint.closed?; end

    def tick
      return if @closed
      if (result = @work.take)
        value, error = result
        @last_error = error.class.to_s if error
        if value.is_a?(Array) && value.first == :endpoint
          @endpoint = value.last
          @next_retry = 0.0
          @endpoint.on_invitation { |invitation| consider_invitation(invitation) unless @closed }
        elsif value.is_a?(Array) && value.first == :session
          attach(value.last)
        end
      end
      drain_invitations if @endpoint && !host? && !@endpoint.closed?
      return if @work.busy?
      now = @clock.call
      if @reconnect_requested
        @reconnect_requested = false
        endpoint = release_ownership
        @endpoint = nil
        @session = nil
        @epoch = nil
        @incoming.clear
        @next_retry = now + 1
        dispose_endpoint(endpoint)
      end
      if @endpoint == nil || @endpoint.closed?
        return if now < @next_retry
        if @endpoint
          # Native transport failures may close the endpoint themselves. It
          # still belongs to Program's resource registry until we release it.
          dispose_endpoint(release_ownership)
          @endpoint = @session = @epoch = nil
          @incoming.clear
          @pending_invitation = nil
        end
        @next_retry = now + 3.0
        @work.start do
          endpoint = @program.communication
          retained = @resource_lock.synchronize do
            if @closed
              false
            else
              @owned_endpoint = endpoint
              true
            end
          end
          if !retained
            dispose_endpoint(endpoint)
            nil
          else
            [:endpoint, endpoint]
          end
        end
      elsif host? && !connected?
        return if now < @next_retry
        @next_retry = now + 3.0
        endpoint = @endpoint
        @work.start do
          session = endpoint.create_session(metadata: metadata, capacity: 32, public: false, encryption: 192)
          if @closed
            session.close
            nil
          else
            [:session, session]
          end
        end
      elsif !host? && @pending_invitation
        invitation, @pending_invitation = @pending_invitation, nil
        previous = @session
        @work.start do
          session = invitation.accept
          # Accepting the new session succeeded. A failed departure from the old
          # one must not discard the replacement (or leave it without handlers).
          begin
            previous.leave if previous && !previous.equal?(session) && previous.state == :open
          rescue StandardError
            nil
          end
          if @closed
            session.leave
            nil
          else
            [:session, session]
          end
        end
      elsif host? && connected?
        present = @session.participants.map { |p| p.user.downcase }
        missing = allowed_members.find do |name|
          !present.include?(name.downcase) && !name.casecmp?(@viewer) && now - @invited_at.fetch(name.downcase, -10.0) >= 5
        end
        if missing
          @invited_at[missing.downcase] = now
          session = @session
          @work.start { session.invite(missing); nil }
        end
      end
    end

    def send(data)
      return false unless connected? && data.is_a?(String) && data.bytesize <= Protocol::MAX_BYTES
      targets = @session.participants.select do |p|
        p.id != @session.self_id && authorized?(p.user) && (host? || p.user.casecmp?(@owner))
      end
      return true if targets.empty?
      # Verified API queues TCP fallback without waiting; UDP is nonblocking.
      @session.send_unreliable(data, to: targets)
      true
    rescue StandardError => error
      @last_error = error.class.to_s
      false
    end

    def take_packets
      packets, @incoming = @incoming, {}
      packets
    end

    def reconnect
      @reconnect_requested = true
    end

    def close
      return if @closed
      endpoint = @resource_lock.synchronize do
        @closed = true
        owned = @owned_endpoint || @endpoint
        @owned_endpoint = nil
        owned
      end
      @incoming.clear
      @pending_invitation = nil
      # Closing a dedicated endpoint releases its sessions and callbacks. An
      # already-running finite setup operation checks @closed before returning.
      @work.close
      @session = @endpoint = nil
      dispose_endpoint(endpoint)
    end

    private

    def release_ownership
      @resource_lock.synchronize do
        endpoint = @owned_endpoint || @endpoint
        @owned_endpoint = nil
        endpoint
      end
    end

    def dispose_endpoint(endpoint)
      return unless endpoint
      endpoint.close unless endpoint.closed?
    rescue StandardError => error
      @last_error = error.class.to_s
    ensure
      @program.release(endpoint) if endpoint && @program.respond_to?(:release)
    end

    def metadata; { 'gr_realtime' => Protocol::VERSION, 'match' => @match }; end
    def allowed_members; @members.call.to_a.map(&:to_s).reject { |n| n.start_with?('bot:') }.uniq.first(32); end
    def authorized?(name); allowed_members.any? { |candidate| candidate.casecmp?(name.to_s) }; end

    def drain_invitations
      # Invitations can precede registration of the UI callback while the
      # endpoint is being created. timeout: 0 is a verified non-pumping poll.
      8.times do
        invitation = @endpoint.next_invitation(timeout: 0)
        break unless invitation
        consider_invitation(invitation)
      end
    rescue StandardError => error
      @last_error = error.class.to_s
    end

    def consider_invitation(invitation)
      return if host? || @pending_invitation
      return if connected? && @last_packet_at && @clock.call - @last_packet_at < 2
      return unless invitation.sender.user.to_s.casecmp?(@owner)
      return unless invitation.session_metadata == metadata && invitation.status == :pending
      @pending_invitation = invitation
    end

    def attach(session)
      @session = session
      @last_error = nil
      @epoch = Digest::SHA256.hexdigest(session.id.to_s)[0, 16]
      @incoming.clear
      @invited_at.clear
      @last_packet_at = nil
      @received_sequences = {}
      session.on_unreliable do |message|
        next if @closed || !@session.equal?(session)
        sender = message.sender.user.to_s
        next unless authorized?(sender) && (host? || sender.casecmp?(@owner))
        packet = Protocol.decode(message.data, match: @match, epoch: @epoch)
        next unless packet && packet['k'] == (host? ? 'input' : 'state')
        key = sender.downcase
        next if packet['n'] <= @received_sequences.fetch(key, -1)
        @received_sequences[key] = packet['n']
        @incoming[key] = packet
        @last_packet_at = @clock.call
      end
      session.on_owner_changed { |_owner| reconnect unless @closed || !@session.equal?(session) }
    end
  end
end
