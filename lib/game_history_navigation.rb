module GameRoomHistory
  Entry = Struct.new(:text, :category, keyword_init: true)

  class Navigator
    CATEGORIES = [:all, :game, :chat, :room].freeze

    def initialize
      @category = :all
      @position = nil
    end

    attr_reader :category

    def change_category(entries, direction)
      index = CATEGORIES.index(@category).to_i
      @category = CATEGORIES[(index + direction.to_i) % CATEGORIES.length]
      matching = matching_entries(entries)
      @position = matching.empty? ? nil : matching.length - 1
      category_label
    end

    def move(entries, direction)
      matching = matching_entries(entries)
      return category_message(matching) if matching.empty?

      if @position == nil
        @position = matching.length - 1
      else
        @position = bounded_position(@position + direction.to_i, matching)
      end
      matching[@position].text.to_s
    end

    def jump(entries, edge)
      matching = matching_entries(entries)
      return category_message(matching) if matching.empty?

      @position = edge.to_sym == :first ? 0 : matching.length - 1
      matching[@position].text.to_s
    end

    private

    def matching_entries(entries)
      values = entries.to_a
      return values if @category == :all

      values.select { |entry| entry.category.to_sym == @category }
    end

    def bounded_position(position, entries)
      [[position.to_i, 0].max, entries.length - 1].min
    end

    def category_message(entries, include_entry: false)
      summary = _("%{category}, entries: %{count}.") % {
        category: category_label,
        count: entries.length
      }
      return summary if !include_entry || entries.empty?

      "#{summary} #{entries.last.text}"
    end

    def category_label
      case @category
      when :game
        _("Game")
      when :chat
        _("Chat")
      when :room
        _("Room events")
      else
        _("All")
      end
    end
  end
end
