module GameSurfaces
  SurfacePart = Struct.new(:id, :surface, keyword_init: true)
  CompositeSpec = Struct.new(:parts, keyword_init: true)

  class CompositeSurface
    include ActionEmitter

    def initialize(spec, state: {})
      @spec = spec
      @parts = @spec.parts.to_a
      validate_parts!
      remembered = state_value(state, "parts", {})
      @surfaces = @parts.map do |part|
        child_state = remembered_value(remembered, part.id)
        surface = GameSurfaces.build(part.surface, state: child_state)
        surface.on_action do |action|
          @action_handler&.call(action.with_source(part.id))
        end
        surface
      end
      raise ArgumentError, "a composite surface must expose at least one field" if fields.empty?
    end

    def fields
      @surfaces.flat_map(&:fields)
    end

    def state
      values = {}
      @parts.each_with_index do |part, index|
        values[part.id.to_s] = @surfaces[index].state
      end
      { "parts" => values }
    end

    def submission_action
      @surfaces.each do |surface|
        next if !surface.respond_to?(:submission_action)

        action = surface.submission_action
        return action if action != nil
      end
      nil
    end

    def suppress_next_focus!(field_index = 0)
      remaining = field_index.to_i
      @surfaces.each do |surface|
        count = surface.fields.length
        if remaining < count
          surface.suppress_next_focus!(remaining)
          return
        end
        remaining -= count
      end
    end

    def cancel_pending_action?
      @surfaces.any? do |surface|
        surface.respond_to?(:cancel_pending_action?) && surface.cancel_pending_action?
      end
    end

    def cancel_pending_action!
      surface = @surfaces.find do |candidate|
        candidate.respond_to?(:cancel_pending_action?) && candidate.cancel_pending_action?
      end
      return false if surface == nil

      surface.cancel_pending_action!
    end

    private

    def validate_parts!
      raise ArgumentError, "a composite surface requires parts" if @parts.empty?
      ids = @parts.map { |part| part.id.to_s }
      raise ArgumentError, "surface part ids must not be empty" if ids.any?(&:empty?)
      raise ArgumentError, "surface part ids must be unique" if ids.uniq.length != ids.length
      raise ArgumentError, "surface parts require a specification" if @parts.any? { |part| part.surface == nil }
    end

    def remembered_value(remembered, id)
      return {} if !remembered.respond_to?(:key?)
      return remembered[id.to_s] if remembered.key?(id.to_s)
      return remembered[id.to_sym] if id.respond_to?(:to_sym) && remembered.key?(id.to_sym)

      {}
    end

    def state_value(state, key, default)
      return default if !state.respond_to?(:key?)
      return state[key] if state.key?(key)
      return state[key.to_sym] if state.key?(key.to_sym)

      default
    end
  end
end
