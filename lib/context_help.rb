module GameRoomContextHelp
  module DynamicTips
    attr_accessor :game_room_context_help_tips
    attr_accessor :game_room_game_help_tips

    def get_tips
      inherited = defined?(super) ? super.to_a : []
      (inherited + game_room_context_help_tips.to_a + game_room_game_help_tips.to_a).uniq
    end
  end

  module_function

  # Context actions change with the current screen and game phase. Keep their
  # help separate from a control's permanent tips so obsolete shortcuts can be
  # replaced instead of accumulating for the lifetime of the shared form.
  def replace(fields, tips, source: :context)
    current = tips.to_a.map(&:to_s).reject(&:empty?).uniq
    fields.to_a.each do |field|
      next if !field.respond_to?(:add_tip)

      field.extend(DynamicTips) if !field.singleton_class.ancestors.include?(DynamicTips)
      if source == :game
        field.game_room_game_help_tips = current
      else
        field.game_room_context_help_tips = current
      end
    end
  end
end
