module GameSurfaces
  PawnTrackItem = Struct.new(:id, :label, :action, keyword_init: true)
  PawnTrackSpec = Struct.new(:id, :header, :items, :empty_label, :activation_action, keyword_init: true)

  # A compact, accessible surface for race games in which the meaningful
  # information is a pawn's logical position, not its coordinates on a drawn
  # board. Games provide already translated labels and optional actions; the
  # surface only preserves selection and emits the chosen action.
  class PawnTrackSurface
    include ActionEmitter

    def initialize(spec, state: {})
      @spec = spec
      @items = @spec.items.to_a
      validate_spec!
      @index = restored_index(state)
      @control = RefreshAwareListBox.new(
        @items.map { |item| item.label.to_s },
        header: @spec.header.to_s,
        index: @index,
        quiet: true,
        empty_label: @spec.empty_label.to_s
      )
      @control.on(:select) do |params|
        item = @items[params.to_a[0].to_i]
        action = item&.action || @spec.activation_action
        emit_surface_action(action) if action != nil
      end
    end

    def fields
      [@control]
    end

    def state
      item = @items[@control.index.to_i]
      {
        "index" => @control.index.to_i,
        "item_id" => item&.id.to_s
      }
    end

    def suppress_next_focus!(_field_index = 0)
      @control.suppress_next_focus!
    end

    private

    def emit_surface_action(action)
      emit_action(action.kind, action.name, action.payload, source: action.source)
    end

    def restored_index(state)
      remembered_id = state_value(state, "item_id", "").to_s
      by_id = @items.index { |item| item.id.to_s == remembered_id } if !remembered_id.empty?
      return by_id if by_id != nil

      requested = state_value(state, "index", 0).to_i
      return 0 if @items.empty?

      [[requested, 0].max, @items.length - 1].min
    end

    def validate_spec!
      raise ArgumentError, "a pawn track requires an id" if @spec.id.to_s.empty?
      ids = @items.map { |item| item.id.to_s }
      raise ArgumentError, "pawn track item ids must not be empty" if ids.any?(&:empty?)
      raise ArgumentError, "pawn track item ids must be unique" if ids.uniq.length != ids.length
      raise ArgumentError, "pawn track item labels must not be empty" if @items.any? { |item| item.label.to_s.empty? }
      actions = @items.map(&:action).compact
      actions << @spec.activation_action if @spec.activation_action != nil
      if actions.any? { |action| !action.is_a?(Action) }
        raise ArgumentError, "pawn track actions must be surface actions"
      end
    end

    def state_value(state, key, default)
      return default if !state.respond_to?(:key?)
      return state[key] if state.key?(key)
      return state[key.to_sym] if state.key?(key.to_sym)

      default
    end
  end
end
