# Reproducible synthetic cues, matching the reference's 180 Hz / 150 ms tones
# and 10-second white noise buffers. No original program is executed.
require "tmpdir"
require_relative "encode_audio"
rate = 44_100
directory = File.expand_path('../Audio', __dir__)
ffmpeg, ffprobe = ARGV
names = %w[left right].product(%w[noise tone]).map { |side, mode| "pong_echo_#{mode}_#{side}.opus" }
raise "Back up and remove existing echo assets before regenerating" if names.any? { |name| File.exist?(File.join(directory, name)) }
%w[left right].each_with_index do |side, channel|
  %w[noise tone].each do |mode|
    seconds, amplitude, fade = mode == 'noise' ? [10, 0.12, 0.05] : [0.15, 0.2, 0.02]
    count = (rate * seconds).round
    edge = (rate * fade).round
    rng = Random.new(20260920 + channel)
    samples = Array.new(count) do |i|
      signal = mode == 'noise' ? rng.rand * 2 - 1 : Math.sin(2 * Math::PI * 180 * i / rate)
      envelope = [1.0, i.to_f / edge, (count - 1 - i).to_f / edge].min
      (signal * envelope * amplitude * 32767).round
    end
    pcm = samples.flat_map { |n| [n, n] }.pack('s<*')
    format = [1, 2, rate, rate * 4, 4, 16].pack('vvVVvv')
    wave = 'RIFF'.b + [36 + pcm.bytesize].pack('V') + 'WAVEfmt '.b + [16].pack('V') + format +
      'data'.b + [pcm.bytesize].pack('V') + pcm
    Dir.mktmpdir("gr-echo-") do |temporary|
      original = File.join(temporary, "echo.wav")
      File.binwrite(original, wave)
      GameRoomAudioEncoding.encode(original, File.join(directory, "pong_echo_#{mode}_#{side}.opus"),
        ffmpeg: ffmpeg || "ffmpeg", ffprobe: ffprobe || "ffprobe")
    end
  end
end
puts 'Generated four Pong echolocation assets from deterministic PCM, encoded as Opus 144 kb/s VBR.'
