require_relative 'audio_tutorial_native'

def SpeechOutput.speak_sequence(sequence)
  speak_text(sequence.speech_text, method: 1, interrupt: true)
end

class BackgroundHelpNativeDriver
  attr_accessor :root, :keys
  attr_reader :frames
  def initialize
    @keys, @previous, @frames = [], [], 0
  end
  def tick(form)
    # Native constructors and resume call loop_update too; they do not consume
    # the next user action from the outer game's wait.
    keys = form.equal?(@root) && form.instance_variable_get(:@wait) ? @keys.shift : []
    keys ||= []
    @frames += 1
    raise 'Native help wait did not resume' if @frames > 100
    state = "\0" * 256
    keys.each { |code| state.setbyte(code, 0x80) }
    events = (@previous - keys).map { |code| [code, false] } +
      (keys - @previous).map { |code| [code, true] }
    EltenAPI::KeyboardState.update(raw_state: state, events: events, now: @frames * 0.1,
      pressed_implies_held: false, synthesize_repeats: false)
    @previous = keys
    $input_frame_serial = $input_frame_serial.to_i + 1
    $keyboard_state_frame_serial = $input_frame_serial
    $keyboard_state_frame_thread = Thread.current
    $activecontrols = []
  end
end
