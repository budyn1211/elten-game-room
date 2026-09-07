module GameRoomRules
  REQUIRED_SECTION_IDS = [:goal, :setup, :play, :ending, :variants, :controls].freeze
  CTRL_F1_KEY = 0x70

  module ShortcutFormEvents
    private

    def keyevents
      events = super
      if key_first_pressed?(GameRoomRules::CTRL_F1_KEY)
        events << [:key_f1, :f1]
      end
      events
    end
  end

  class Section
    attr_reader :id, :title, :paragraphs

    def initialize(id:, title:, paragraphs:)
      @id = id.to_sym
      @title = title.to_s.strip
      @paragraphs = paragraphs.to_a.map { |paragraph| paragraph.to_s.strip }.reject(&:empty?).freeze
      raise ArgumentError, "a rule section requires an id" if @id.to_s.empty?
      raise ArgumentError, "a rule section requires a title" if @title.empty?
      raise ArgumentError, "a rule section requires content" if @paragraphs.empty?
    end

    def text
      paragraphs.join("\r\n\r\n")
    end
  end

  class Book
    attr_reader :game_id, :title, :sections

    def initialize(game_id:, title:, sections:)
      @game_id = game_id.to_s.strip
      @title = title.to_s.strip
      @sections = sections.to_a.freeze
      raise ArgumentError, "a rule book requires a game id" if @game_id.empty?
      raise ArgumentError, "a rule book requires a title" if @title.empty?
      if @sections.any? { |section| !section.is_a?(Section) }
        raise ArgumentError, "a rule book may contain only rule sections"
      end

      ids = @sections.map(&:id)
      raise ArgumentError, "rule section ids must be unique" if ids.uniq.length != ids.length
      missing = REQUIRED_SECTION_IDS - ids
      if !missing.empty?
        raise ArgumentError, "missing rule sections: #{missing.join(", ")}"
      end
      required_order = ids.select { |id| REQUIRED_SECTION_IDS.include?(id) }
      if required_order != REQUIRED_SECTION_IDS
        raise ArgumentError, "required rule sections are out of order"
      end
    end

    def with_current_options(summary)
      text = summary.to_s.strip
      return self if text.empty?

      current = Section.new(
        id: :current_options,
        title: _("Current table options"),
        paragraphs: [text]
      )
      self.class.new(game_id: game_id, title: title, sections: [current] + sections)
    end
  end

  def self.bind_ctrl_f1(form, fields, &handler)
    raise ArgumentError, "Ctrl+F1 requires an action" if handler == nil

    form.extend(ShortcutFormEvents)
    fields.to_a.each do |field|
      field.add_tip(_("Press Ctrl+F1 to read the game rules.")) if field.respond_to?(:add_tip)
    end
    form.on(:key_f1) do |parameters|
      next if !ctrl_f1_event?(parameters)

      EltenAPI::KeyboardState.clear_current_frame if defined?(EltenAPI::KeyboardState)
      handler.call
    end
  end

  def self.ctrl_f1_event?(parameters)
    shift, main_modifier, option = parameters.to_a
    shift != true && main_modifier == true && option != true
  end
end
