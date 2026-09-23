# encoding: UTF-8
require_relative 'preferences'
require_relative '../game_content'
require_relative '../game_room_ui'

module GameRoomAudioBall
  class Settings
    def _(text); GameRoomContent.utf8(super(text)); end

    def initialize(values, program:, tick: nil, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @values, @program = Preferences.normalize(values), program
      @tick, @clock = tick, clock
    end

    def wait
      require_relative '../realtime/timer' if @tick
      side = ListBox.new([_('Right (default)'), _('Left')],
        header: _('Your listening side (only for you)'), index: @values['listening_side'] == 'left' ? 1 : 0, quiet: true)
      save, cancel = Button.new(_('Save')), Button.new(_('Cancel'))
      form = GameRoomUI::Form.new([side, save, cancel], program: @program, quiet: true)
      form.accept_button, form.cancel_button = save, cancel
      accepted = false
      save.on(:press) { accepted = true; form.resume }
      cancel.on(:press) { form.resume }
      timer = GameRoomRealtime::Timer.new(clock: @clock, &@tick) if @tick
      form.add_timer(timer) if timer
      form.wait
      accepted ? Preferences.normalize('listening_side' => side.index == 1 ? 'left' : 'right') : nil
    ensure
      timer&.stop
      form.delete_timer(timer) if form && timer
    end
  end
end
