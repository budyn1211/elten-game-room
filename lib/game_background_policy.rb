# Local presentation policy only. It neither pauses the model nor changes
# global speech. No disk/network access on the notification/UI path.
module GameRoomBackgroundPolicy
  module_function

  def outside?(program, covered: false)
    return true if !window_foreground?
    active = defined?($activecontrols) && $activecontrols.to_a.reverse.find do |control|
      control.respond_to?(:game_room_hotkeys_active?) && control.game_room_hotkeys_active?
    end
    return false if active && active.game_room_program.equal?(program)
    !!covered
  end

  def window_foreground?
    return true unless defined?($wnd) && $wnd.to_i != 0 && /mswin|mingw/ =~ RUBY_PLATFORM
    unless @foreground
      require "fiddle"
      @user32 = Fiddle.dlopen("user32.dll")
      abi = defined?(Fiddle::Function::STDCALL) ? Fiddle::Function::STDCALL : Fiddle::Function::DEFAULT
      @foreground = Fiddle::Function.new(@user32["GetForegroundWindow"], [], Fiddle::TYPE_VOIDP, abi)
    end
    @foreground.call.to_i == $wnd.to_i
  rescue StandardError, LoadError
    true
  end

  def enabled?(program, key)
    !program.class.respond_to?(:normalized_settings) || program.class.normalized_settings[key] != false
  end

  def speech?(program, covered: false)
    !outside?(program, covered: covered) || enabled?(program, "background_table_speech")
  end

  def turn_sound?(program, covered: false)
    outside?(program, covered: covered) && enabled?(program, "background_turn_sound")
  end
end
