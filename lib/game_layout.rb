module GameRoomLayout
  STANDARD_SECTIONS = [:game, :history, :chat, :users].freeze

  class ViewSpec
    attr_reader :surface, :sections, :history_header, :history_empty_label

    def initialize(surface:, history_header: nil, history_empty_label: nil)
      raise ArgumentError, "a game view requires a surface" if surface == nil

      @sections = STANDARD_SECTIONS
      @surface = surface
      @history_header = history_header == nil ? nil : history_header.to_s
      @history_empty_label = history_empty_label == nil ? nil : history_empty_label.to_s
    end
  end

  Snapshot = Struct.new(
    :surface_state,
    :history_index,
    :users_index,
    :form_index,
    :focus_location,
    :surface_identity,
    :history_follows_tail,
    :chat_text,
    :chat_index,
    :chat_check,
    keyword_init: true
  )

  module ShortcutFormBehavior
    def game_shortcut_keys=(keys)
      @game_shortcut_keys = keys.to_a.map do |key|
        key.to_s.sub(/\Akey_/, "").downcase
      end.uniq
    end

    def game_shortcut_signatures=(signatures)
      @game_shortcut_signatures = signatures.to_a.map do |key, modifiers|
        [key.to_s.sub(/\Akey_/, "").downcase, modifiers.to_a.map(&:to_sym).uniq.sort]
      end
      self.game_shortcut_keys = @game_shortcut_signatures.map(&:first)
    end

    def history_navigation_signatures=(signatures)
      @history_navigation_signatures = signatures.to_a.map do |key, modifiers|
        [key.to_s.sub(/\Akey_/, "").downcase, modifiers.to_a.map(&:to_sym).uniq.sort]
      end
    end

    def key_processed(key)
      normalized = key.to_s.sub(/\Akey_/, "").downcase
      modifiers = active_shortcut_modifiers
      if @history_navigation_signatures.to_a.include?([normalized, modifiers])
        return true if editable_text_field?

        return false
      end
      if @game_shortcut_keys.to_a.include?(normalized)
        if editable_text_field?
          return true if !modifiers.include?(:control) && !modifiers.include?(:alt)
          return false if @game_shortcut_signatures.to_a.include?([normalized, modifiers])

          return true
        end
        return false
      end

      super
    end

    private

    def editable_text_field?
      field = fields[index.to_i] if respond_to?(:fields) && respond_to?(:index)
      return false if !defined?(EditBox) || !field.is_a?(EditBox)

      flags = field.respond_to?(:flags) ? field.flags.to_i : field.instance_variable_get(:@flags).to_i
      (flags & EditBox::Flags::ReadOnly) == 0
    end

    def active_shortcut_modifiers
      modifiers = []
      modifiers << :shift if respond_to?(:raw_key_held?, true) && raw_key_held?(:key_shift)
      modifiers << :control if respond_to?(:modifier_held?, true) && modifier_held?(:main_modifier)
      modifiers << :alt if respond_to?(:modifier_held?, true) && modifier_held?(:option)
      modifiers.sort
    end
  end

  class Screen
    attr_reader :surface, :history, :users, :chat, :back_button, :form

    def initialize(
      view_spec:,
      surface_state:,
      history_items:,
      user_items:,
      history_index:,
      users_index:,
      form_index:,
      focus_location: nil,
      previous_surface_identity: nil,
      users_header:,
      chat_text: "",
      chat_index: 0,
      chat_check: 0,
      chat_control: nil
    )
      raise ArgumentError, "a game screen requires a view specification" if !view_spec.is_a?(ViewSpec)

      @view_spec = view_spec
      @surface_identity = surface_identity_for(@view_spec.surface)
      @history_items = history_items.to_a.map(&:to_s)
      @user_items = user_items.to_a.map(&:to_s)
      @surface = GameSurfaces.build(@view_spec.surface, state: surface_state || {})
      raise ArgumentError, "a game surface must expose at least one field" if @surface.fields.empty?

      @history = GameSurfaces::RefreshAwareListBox.new(
        @history_items,
        header: text_or_default(@view_spec.history_header, _("Game history")),
        index: bounded_index(history_index, @history_items),
        quiet: true,
        empty_label: text_or_default(@view_spec.history_empty_label, _("No moves yet"))
      )
      @users = GameSurfaces::RefreshAwareListBox.new(
        @user_items,
        header: users_header.to_s,
        index: bounded_index(users_index, @user_items),
        quiet: true
      )
      @chat = chat_control
      if @chat == nil
        @chat = GameSurfaces::RefreshAwareEditBox.new(
          _("Chat"),
          text: chat_text.to_s,
          quiet: true,
          max_length: 400
        )
        @chat.restore_selection(index: chat_index, check: chat_check)
      end
      @back_button = Button.new(_("Back to the table"))

      section_fields = {
        game: @surface.fields,
        history: [@history],
        users: [@users],
        chat: [@chat]
      }
      @content_fields = []
      @field_locations = []
      @view_spec.sections.each do |section|
        section_fields.fetch(section).each_with_index do |field, section_index|
          @content_fields << field
          @field_locations << [section, section_index]
        end
      end
      initial_focus_location = focus_location
      if focus_location.to_a[0]&.to_sym == :game && previous_surface_identity != nil &&
          previous_surface_identity != @surface_identity
        initial_focus_location = [:game, 0]
      end
      initial_form_index = form_index_for_location(initial_focus_location, fallback: form_index)
      @form = GameSurfaces::RefreshAwareForm.new(
        @content_fields + [@back_button],
        index: initial_form_index,
        quiet: true
      )
      @form.extend(ShortcutFormBehavior)
      @form.cancel_button = @back_button
      @form.hide(@back_button)
    end

    def shortcut_fields
      @content_fields.reject { |field| field.equal?(@chat) }
    end

    def suppress_focus!
      location = @field_locations[@form.index.to_i]
      return false if location == nil

      field = @content_fields[@form.index.to_i]
      field.suppress_next_focus! if field.respond_to?(:suppress_next_focus!)
      true
    end

    def wait_without_announcement
      @form.wait_without_announcement
    end

    def snapshot
      form_index = bounded_index(@form.index, @content_fields)
      focus_location = @field_locations[form_index]
      history_is_focused = focus_location.to_a[0]&.to_sym == :history
      history_follows_tail = !history_is_focused || @history.index.to_i >= @history_items.length - 1
      history_index = if history_follows_tail
        [@history_items.length - 1, 0].max
      else
        @history.index.to_i
      end
      Snapshot.new(
        surface_state: @surface.state,
        history_index: history_index,
        users_index: @users.index.to_i,
        form_index: form_index,
        focus_location: focus_location,
        surface_identity: @surface_identity,
        history_follows_tail: history_follows_tail,
        chat_text: @chat.text,
        chat_index: @chat.index.to_i,
        chat_check: @chat.check.to_i
      )
    end

    private

    def bounded_index(index, items)
      return 0 if items.empty?

      [[index.to_i, 0].max, items.length - 1].min
    end

    def form_index_for_location(location, fallback:)
      section = location.to_a[0]&.to_sym
      section_index = location.to_a[1].to_i
      matches = @field_locations.each_index.select do |index|
        @field_locations[index][0] == section
      end
      return bounded_index(fallback, @content_fields) if matches.empty?

      matches[[[section_index, 0].max, matches.length - 1].min]
    end

    def surface_identity_for(spec)
      if spec.is_a?(GameSurfaces::CompositeSpec)
        children = spec.parts.to_a.map do |part|
          "#{part.id}=#{surface_identity_for(part.surface)}"
        end
        return "#{spec.class.name}[#{children.join('|')}]"
      end

      id = spec.respond_to?(:id) ? spec.id.to_s : ""
      "#{spec.class.name}:#{id}"
    end

    def text_or_default(value, default)
      value.to_s.empty? ? default : value.to_s
    end
  end
end
