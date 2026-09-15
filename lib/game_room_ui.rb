require_relative "game_room_preferences"
require_relative "context_help"

# The host handles function keys before Form events. Intercept dispatch, not
# saved QuickActions or host sources. Only a currently waiting Game Room form
# in the host's active-controls list can replace a native action. The bridge
# holds no application/runtime reference and is installed just once.
module GameRoomUI
  HostForm = Form
  VOLUME_LABELS = {
    "all" => "All Game Room sounds", "game" => "Game sounds",
    "room" => "Sounds when someone enters or leaves a room",
    "chat" => "Chat sounds", "notifications" => "Invitation and Game Room notification sounds"
  }.freeze
  GLOBAL_TIPS = [
    "Press F2 to lower and F3 to raise the selected Game Room sound volume.",
    "Press Shift+F2 or Shift+F3 to select the previous or next sound group."
  ].freeze
  HotkeyAction = Struct.new(:callback) do
    def call
      callback.call
    end
  end

  module_function

  def install_hotkeys
    return unless defined?(EltenAPI::QuickActions)

    target = EltenAPI::QuickActions.singleton_class
    return if target.instance_variable_get(:@game_room_dispatch_bridge)

    bridge = Module.new do
      define_method(:hotkey_actions) do |key|
        form = $activecontrols.to_a.reverse.find do |control|
          control.respond_to?(:game_room_hotkeys_active?) && control.game_room_hotkeys_active?
        end
        if form != nil && [1, 2, 3, -2, -3].include?(key)
          action = form.game_room_hotkey_action(key)
          return [action] if action != nil
        end
        super(key)
      end
    end
    target.prepend(bridge)
    target.instance_variable_set(:@game_room_dispatch_bridge, true)
  end

  class Form < HostForm
    attr_accessor :game_room_program, :game_room_volume_reader, :game_room_volume_writer
    attr_accessor :game_room_general_help_tips

    def initialize(fields, program: nil, **options)
      @game_room_program = program
      super(fields, **options)
    end

    def wait
      GameRoomUI.install_hotkeys
      @game_room_waiting = true
      super
    ensure
      @game_room_waiting = false
    end

    def game_room_hotkeys_active?
      @game_room_waiting == true
    end

    def game_room_hotkey_action(key)
      return HotkeyAction.new(-> { show_game_room_help }) if key == 1
      return nil unless @game_room_program&.respond_to?(:adjust_game_room_volume, true)

      HotkeyAction.new(lambda do
        clear_game_room_key
        @game_room_program.send(
          :adjust_game_room_volume, key,
          reader: game_room_volume_reader, writer: game_room_volume_writer
        )
      end)
    end

    def show_game_room_help
      opened_here = false
      return if @game_room_help_open

      field = fields[index.to_i]
      game = field.respond_to?(:game_room_game_help_tips) ? field.game_room_game_help_tips.to_a : []
      context = field.respond_to?(:game_room_context_help_tips) ? field.game_room_context_help_tips.to_a : []
      tips = field.respond_to?(:get_tips) ? field.get_tips.to_a : []
      form_tips = respond_to?(:get_tips) ? get_tips.to_a : []
      history_tips = if field.is_a?(EditBox) && (field.flags.to_i & EditBox::Flags::ReadOnly) == 0
        []
      else
        game_room_general_help_tips.to_a
      end
      items = (game + context + tips + form_tips + history_tips + GLOBAL_TIPS.map { |tip| _(tip) })
        .map(&:to_s).reject(&:empty?).uniq
      items = [_("No shortcuts are available on this screen.")] if items.empty?
      @game_room_help_open = true
      opened_here = true
      clear_game_room_key
      list = ListBox.new(items, header: _("Keyboard shortcuts"), quiet: true)
      close = Button.new(_("Close"))
      dialog = GameRoomUI::Form.new([list, close], program: @game_room_program, quiet: true)
      dialog.instance_variable_set(:@game_room_help_open, true)
      dialog.game_room_volume_reader = game_room_volume_reader
      dialog.game_room_volume_writer = game_room_volume_writer
      dialog.accept_button = close
      dialog.cancel_button = close
      dialog.hide(close)
      close.on(:press) { dialog.resume }
      dialog.wait
      clear_game_room_key
      # A modal help view does not replace controls or modify the parent wait.
      field.focus if field.respond_to?(:focus)
    ensure
      @game_room_help_open = false if opened_here
    end

    private

    def clear_game_room_key
      EltenAPI::KeyboardState.clear_current_frame if defined?(EltenAPI::KeyboardState)
    end
  end

  # NotificationPresentation only supports a sound path, not a volume. Its
  # sound getter is read by the host at delivery, AFTER suppression/DND checks.
  # Use the app's SoundPool then and return nil to prevent a second host sound.
  module NotificationSound
    attr_accessor :game_room_notice_player

    def sound
      if !@game_room_notice_played
        @game_room_notice_played = true
        game_room_notice_player&.call
      end
      nil
    end
  end
end
