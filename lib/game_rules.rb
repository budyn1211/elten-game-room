require_relative "game_content"
require_relative "context_help"

require_relative "game_room_localization"

module GameRoomRules
  using GameRoomLocalization::Translations
  REQUIRED_SECTION_IDS = [:controls].freeze
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
      @title = GameRoomContent.utf8(title).strip
      @paragraphs = paragraphs.to_a.map { |paragraph| GameRoomContent.utf8(paragraph).strip }.reject(&:empty?).freeze
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
      raise ArgumentError, "a rule book requires game rules" if (ids - [:controls, :current_options]).empty?
    end

    # Sections are headings in a document, not separate places in the UI.
    # Keep the two documents independent so rules never repeat key bindings.
    def documents
      result = [
        Section.new(id: :rules, title: _("Rules"), paragraphs: sections.reject { |section| [:controls, :current_options].include?(section.id) }.map { |section| "#{section.title}\r\n#{section.text}" }),
        Section.new(id: :controls, title: _("In-game keyboard shortcuts"), paragraphs: sections.find { |section| section.id == :controls }.paragraphs)
      ]
      current = sections.find { |section| section.id == :current_options }
      result << current if current
      result
    end

    def with_current_options(summary)
      text = summary.to_s.strip
      return self if text.empty?

      current = Section.new(
        id: :current_options,
        title: _("Current table options"),
        paragraphs: [text]
      )
      self.class.new(game_id: game_id, title: title, sections: [current] + sections.reject { |section| section.id == :current_options })
    end
  end

  def self.common_controls
    [
      translate("Tab and Shift+Tab: move between the game's fields, chat and the other table sections. Game letter keys do not replace typing in an editable field."),
      translate("F1: open the current field's help list. Arrows browse it; Enter or Escape closes it. Ctrl+F1: open rules, game shortcuts and, at a table, its current settings. During a game the shortcuts list reflects the current game fields; outside a game it is a reference for all phases."),
      translate("F2 and F3: lower or raise the selected sound group's volume by 10 percentage points. Shift+F2 and Shift+F3: choose the sound group. All Game Room sounds controls the master level without changing each group's setting. Speech and other ELTEN sounds are unaffected."),
      translate("Outside text entry, Shift+Left and Shift+Right choose the history view: all, game, chat or room events. Ctrl+Left and Ctrl+Right read its previous or next entry; adding Shift jumps to the first or last. In editable fields these keys keep their editing meaning."),
      translate("Enter in Chat: send the typed message. In grid games, /a1 can place a piece and /e2 e4 can move one, using the same legality checks as the board. Draughts also accepts numbered squares. Start a message with // to send a literal slash. Escape closes an open list or dialog.")
    ]
  end

  # Some ELTEN dictionaries index MO keys as binary bytes. UTF-8 source keys
  # containing e.g. an en dash then miss despite an existing translation.
  # Retry only an untranslated key, locally; never patch the host dictionary.
  def self.translate(text)
    source = GameRoomContent.utf8(text)
    translated = GameRoomContent.utf8(_(source))
    if translated == source && !source.ascii_only?
      translated = GameRoomContent.utf8(_(source.b))
    end
    translated
  end

  def self.bind_ctrl_f1(form, fields, &handler)
    raise ArgumentError, "Ctrl+F1 requires an action" if handler == nil

    form.extend(ShortcutFormEvents)
    tip = GameRoomContextHelp.shortcut_tip("Ctrl+F1", _("Game rules"))
    fields.to_a.each do |field|
      field.add_tip(tip) if field.respond_to?(:add_tip)
    end
    GameRoomContextHelp.exclude_from_game_help(fields, [tip])
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
