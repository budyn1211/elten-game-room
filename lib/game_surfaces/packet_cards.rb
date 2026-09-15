require "json"

module GameSurfaces
  PacketCardSpec = Struct.new(
    :id, :header, :cards, :action_name, :allow_packet, :empty_label, :hand_order, :hand_epoch,
    keyword_init: true
  )

  # A card hand which can prepare a packet locally with Shift+Enter.  The
  # packet is submitted as one game action, so no intermediate selection is
  # written to LiveSessions.
  class PacketCardSurface
    include ActionEmitter

    attr_reader :command_field_index

    def initialize(spec, state: {})
      @spec = spec
      @cards = spec.cards.to_a
      validate!
      index = state_value(state, "index", 0)
      if spec.hand_order != nil
        @cards, index, changed = CardHandCursor.resolve(@cards, spec.hand_order, spec.hand_epoch,
          state_value(state, "hand_cursor", {}), index)
        @cursor_announcement = card_label(@cards[index]) if changed
      end
      @signature = @cards.map { |card| card_id(card) }.join("|")
      same_epoch = spec.hand_order == nil || state_value(state, "hand_cursor", {})["epoch"] == spec.hand_epoch.to_s
      @selected_ids = if same_epoch && state_value(state, "signature", "").to_s == @signature
        state_value(state, "selected_ids", []).to_a.map(&:to_s)
      else
        []
      end
      @selected_ids.select! { |id| @cards.any? { |card| card_id(card) == id } }
      @pending = nil
      @control = RefreshAwareListBox.new(
        labels, header: spec.header.to_s,
        index: bounded_index(index), quiet: true,
        empty_label: (spec.empty_label || _("Your hand is empty")).to_s
      )
      @control.on(:select) { |parameters| activate(parameters.to_a[0].to_i) }
    end

    def fields
      [@control]
    end

    def state
      result = {
        "index" => @pending == nil ? @control.index.to_i : @pending[:card_index],
        "selected_ids" => @selected_ids.dup,
        "signature" => @signature
      }
      if @spec.hand_order != nil
        result["hand_cursor"] = CardHandCursor.snapshot(@cards, @spec.hand_order, @spec.hand_epoch, result["index"])
      end
      result
    end

    def reusable_for?(spec)
      spec.is_a?(PacketCardSpec) && spec.id == @spec.id && @spec.hand_order != nil && spec.hand_order != nil
    end

    def update_spec(spec)
      remembered = state
      @spec = spec
      @cards, index, changed = CardHandCursor.resolve(spec.cards.to_a, spec.hand_order, spec.hand_epoch,
        remembered["hand_cursor"], remembered["index"])
      validate!
      signature = @cards.map { |card| card_id(card) }.join("|")
      same_hand = signature == @signature && remembered["hand_cursor"]["epoch"] == spec.hand_epoch.to_s
      @selected_ids.clear unless same_hand
      @signature = signature
      if @pending != nil && same_hand
        @pending[:card] = @cards.find { |card| card_id(card) == card_id(@pending[:card]) }
        @pending[:card_index] = @cards.index(@pending[:card])
      else
        @pending = nil
      end
      next_labels = @pending ? card_choices(@pending[:card]).map { |choice| choice_label(choice) } : labels
      @control.options = next_labels if @control.options != next_labels
      @control.header = @pending ? card_choice_header(@pending[:card]) : spec.header.to_s
      @control.empty_label = spec.empty_label.to_s if @control.respond_to?(:empty_label=)
      @control.index = bounded_index(index) unless @pending
      @cursor_announcement = changed && !@pending ? card_label(@cards[index]) : nil
      self
    end

    def take_cursor_announcement(field_index = nil)
      message = field_index == 0 ? @cursor_announcement : nil
      @cursor_announcement = nil
      message
    end

    def suppress_next_focus!(_field_index = 0)
      @control.suppress_next_focus!
    end

    def cancel_pending_action?
      @pending != nil || !@selected_ids.empty?
    end

    def cancel_pending_action!
      if @pending != nil
        restore_cards(speak: true)
      else
        @selected_ids.clear
        refresh_labels
        speak(_("Prepared packet cleared."))
      end
      true
    end

    def handle_command(command, payload = {})
      @command_field_index = nil
      if command.to_s == "navigate_playable_card"
        return navigate_playable_card(payload)
      end
      if command.to_s == "announce_packet"
        prepared = @selected_ids.filter_map { |id| @cards.find { |card| card_id(card) == id } }
        speak(prepared.empty? ? _("No packet prepared.") : prepared.map { |card| card_label(card) }.join(", "))
        return true
      end
      return false if command.to_s != "clear_packet"

      @selected_ids.clear
      restore_cards(speak: false) if @pending != nil
      refresh_labels
      speak(_("Prepared packet cleared."))
      true
    end

    private

    def navigate_playable_card(payload)
      hand_id = (payload["hand_id"] || payload[:hand_id]).to_s
      return false if hand_id != @spec.id.to_s
      if @pending != nil || !@selected_ids.empty?
        speak(_("Finish or clear the prepared packet first."))
        return true
      end

      target = CardHandCursor.navigation_index(
        @cards.map { |card| card_id(card) },
        @control.index,
        payload["card_ids"] || payload[:card_ids],
        payload["direction"] || payload[:direction]
      )
      if target == nil
        speak((payload["empty_message"] || payload[:empty_message] || _("You have no playable card.")).to_s)
        return true
      end

      auto_card_id = (payload["auto_card_id"] || payload[:auto_card_id]).to_s
      auto_action = payload["auto_action"] || payload[:auto_action]
      if (payload["card_ids"] || payload[:card_ids]).to_a.map(&:to_s).uniq.length == 1 &&
          card_id(@cards[target]) == auto_card_id && auto_action.respond_to?(:to_h)
        shortcut = payload["shortcut"] || payload[:shortcut]
        return Action.from_h(auto_action, source: "shortcut:#{shortcut}")
      end

      @control.index = target
      @control.announce_current_card
      @command_field_index = 0
      true
    end

    def activate(index)
      if @pending != nil
        choice = card_choices(@pending[:card])[@control.index.to_i]
        return if choice == nil

        submit_packet(@pending[:card_index], choice_value(choice))
        restore_cards(speak: false)
        return
      end

      card = @cards[index]
      return if card == nil
      if shift_pressed? && @spec.allow_packet != false
        toggle_card(card)
        return
      end

      choices = card_choices(card)
      if !choices.empty?
        @pending = { card: card, card_index: index }
        @control.options = choices.map { |choice| choice_label(choice) }
        @control.header = card_choice_header(card)
        @control.index = 0
        @control.focus(0)
      else
        submit_packet(index, nil)
      end
    end

    def toggle_card(card)
      id = card_id(card)
      if @selected_ids.delete(id)
        message = _("%{card} removed from the packet.") % { card: card_label(card) }
      else
        @selected_ids << id
        message = _("%{card} added to the packet.") % { card: card_label(card) }
      end
      refresh_labels
      speak(message)
    end

    def submit_packet(index, choice)
      current = @cards[index]
      ids = @selected_ids.dup
      ids << card_id(current) if !ids.include?(card_id(current))
      cards = ids.filter_map do |id|
        card = @cards.find { |candidate| card_id(candidate) == id }
        card_value(card) if card
      end
      payload = { "cards" => JSON.generate(cards) }
      payload["choice"] = choice if choice != nil
      emit_action("card_packet", (@spec.action_name || "play").to_s, payload, source: @spec.id)
    end

    def refresh_labels
      @control.options = labels
    end

    def restore_cards(speak:)
      index = @pending[:card_index]
      @pending = nil
      @control.options = labels
      @control.header = @spec.header.to_s
      @control.index = bounded_index(index)
      @control.focus(@control.index) if speak
    end

    def labels
      @cards.map do |card|
        label = card_label(card)
        @selected_ids.include?(card_id(card)) ? _("%{card}; selected") % { card: label } : label
      end
    end

    def card_id(card)
      card.respond_to?(:id) ? card.id.to_s : card.to_s
    end

    def card_label(card)
      card.respond_to?(:label) ? card.label.to_s : card.to_s
    end

    def card_value(card)
      card.respond_to?(:value) ? card.value : card
    end

    def card_choices(card)
      card.respond_to?(:choices) ? card.choices.to_a : []
    end

    def choice_label(choice)
      choice.respond_to?(:label) ? choice.label.to_s : choice.to_s
    end

    def choice_value(choice)
      choice.respond_to?(:value) ? choice.value : choice
    end

    def card_choice_header(card)
      value = card.respond_to?(:choice_header) ? card.choice_header.to_s : ""
      value.empty? ? _("Choose how to play %{card}") % { card: card_label(card) } : value
    end

    def shift_pressed?
      key_held?(0x10) == true
    rescue Exception
      false
    end

    def bounded_index(value)
      return 0 if @cards.empty?
      [[value.to_i, 0].max, @cards.length - 1].min
    end

    def validate!
      raise ArgumentError, "a packet card surface requires an id" if @spec.id.to_s.empty?
      ids = @cards.map { |card| card_id(card) }
      raise ArgumentError, "packet card ids must be unique" if ids.any?(&:empty?) || ids.uniq.length != ids.length
    end

    def state_value(state, key, default)
      return default if !state.respond_to?(:key?)
      return state[key] if state.key?(key)
      return state[key.to_sym] if state.key?(key.to_sym)
      default
    end
  end
end
