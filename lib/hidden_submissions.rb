require "digest"
require "json"
require "securerandom"

module HiddenSubmissions
  Envelope = Struct.new(
    :session_id,
    :round_id,
    :user,
    :payload,
    :nonce,
    :commitment,
    keyword_init: true
  )

  module Commitment
    module_function

    def create(payload, nonce: SecureRandom.hex(32))
      normalized = normalize(payload)
      digest = Digest::SHA256.hexdigest("#{nonce}\0#{JSON.generate(normalized)}")
      [digest, nonce.to_s, normalized]
    end

    def valid?(payload:, nonce:, commitment:)
      calculated, = create(payload, nonce: nonce)
      secure_compare(calculated, commitment.to_s)
    end

    def normalize(value)
      case value
      when Hash
        normalized_keys = value.keys.map(&:to_s)
        if normalized_keys.uniq.length != normalized_keys.length
          raise ArgumentError, "hidden submission payload has duplicate normalized keys"
        end
        normalized_keys.sort.each_with_object({}) do |key, result|
          original = value.keys.find { |candidate| candidate.to_s == key }
          result[key] = normalize(value[original])
        end
      when Array
        value.map { |item| normalize(item) }
      when String, Integer, Float, TrueClass, FalseClass, NilClass
        value
      else
        raise ArgumentError, "hidden submission payload must be JSON-compatible"
      end
    end

    def secure_compare(first, second)
      return false if first.bytesize != second.bytesize

      difference = 0
      first.bytes.zip(second.bytes) { |left, right| difference |= left ^ right }
      difference == 0
    end
    private_class_method :secure_compare
  end

  class MemoryStorage
    def initialize
      @state = { "entries" => {} }
    end

    def read
      Marshal.load(Marshal.dump(@state))
    end

    def update
      yield @state
      read
    end
  end

  class ProgramStorage
    DEFAULT_PATH = "hidden_submissions.json"

    def initialize(program, path: DEFAULT_PATH)
      @program = program
      @path = path.to_s
    end

    def read
      normalize_root(@program.read_json(@path, default: { "entries" => {} }))
    end

    def update(&block)
      root = read
      block.call(root)
      @program.write_json(@path, root)
      root
    end

    private

    def normalize_root(root)
      value = root.is_a?(Hash) ? root : {}
      entries = value["entries"]
      value["entries"] = {} if !entries.is_a?(Hash)
      value
    end
  end

  class Vault
    def initialize(storage)
      @storage = storage
    end

    def prepare(session_id:, round_id:, user:, payload:, nonce: nil)
      # A lost acknowledgement must not destroy the envelope whose commitment
      # may already be on the server. Reuse identical submissions and retain
      # older versions if the user edited an answer before retrying.
      previous = reveal(session_id: session_id, round_id: round_id, user: user)
      normalized_payload = Commitment.normalize(payload)
      return previous if previous != nil && previous.payload == normalized_payload

      digest, actual_nonce, normalized = Commitment.create(
        payload,
        nonce: nonce || SecureRandom.hex(32)
      )
      envelope = Envelope.new(
        session_id: session_id.to_i,
        round_id: round_id.to_s,
        user: user.to_s,
        payload: normalized,
        nonce: actual_nonce,
        commitment: digest
      )
      @storage.update do |state|
        state["entries"] ||= {}
        key = entry_key(envelope.session_id, envelope.round_id, envelope.user)
        old = state["entries"][key]
        versions = old == nil ? {} : old.fetch("versions", {}).dup
        versions[old["commitment"]] = old.reject { |name, _| name == "versions" } if old != nil
        state["entries"][key] = serialize(envelope).merge("versions" => versions)
      end
      envelope
    end

    def reveal(session_id:, round_id:, user:, commitment: nil)
      data = @storage.read.fetch("entries", {})[entry_key(session_id, round_id, user)]
      if data != nil && commitment != nil && data["commitment"] != commitment
        data = data.fetch("versions", {})[commitment]
      end
      data == nil ? nil : deserialize(data)
    end

    def discard(session_id:, round_id:, user:)
      removed = false
      @storage.update do |state|
        entries = state["entries"] ||= {}
        removed = entries.delete(entry_key(session_id, round_id, user)) != nil
      end
      removed
    end

    def verify(envelope)
      Commitment.valid?(
        payload: envelope.payload,
        nonce: envelope.nonce,
        commitment: envelope.commitment
      )
    end

    private

    def entry_key(session_id, round_id, user)
      Digest::SHA256.hexdigest([session_id.to_i, round_id.to_s, user.to_s.downcase].join("\0"))
    end

    def serialize(envelope)
      {
        "session_id" => envelope.session_id,
        "round_id" => envelope.round_id,
        "user" => envelope.user,
        "payload" => envelope.payload,
        "nonce" => envelope.nonce,
        "commitment" => envelope.commitment
      }
    end

    def deserialize(data)
      Envelope.new(
        session_id: data["session_id"].to_i,
        round_id: data["round_id"].to_s,
        user: data["user"].to_s,
        payload: data["payload"],
        nonce: data["nonce"].to_s,
        commitment: data["commitment"].to_s
      )
    end
  end
end
