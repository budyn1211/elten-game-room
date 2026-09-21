# Authoring only: do not transcode audio automatically while building a release.
require "json"
require "open3"
require "tempfile"

module GameRoomAudioEncoding
  BITRATE = "144k".freeze
  FRAME_MS = 20
  SAMPLE_RATE = 48_000

  def self.probe(path, ffprobe: "ffprobe")
    output, error, status = Open3.capture3(ffprobe, "-v", "error", "-show_streams", "-show_format", "-of", "json", path)
    raise "Cannot inspect audio: #{error}" unless status.success?
    JSON.parse(output)
  end

  def self.arguments(source, target)
    ["-v", "error", "-nostdin", "-y", "-i", source, "-map", "0:a:0", "-vn",
     "-map_metadata", "0", "-map_metadata:s:a:0", "0:s:a:0", "-c:a", "libopus",
     "-b:a", BITRATE, "-vbr", "on", "-application", "audio", "-compression_level", "10",
     "-frame_duration", FRAME_MS.to_s, "-ar", SAMPLE_RATE.to_s, "-f", "opus", target]
  end

  def self.encode(source, target, ffmpeg: "ffmpeg", ffprobe: "ffprobe")
    source = File.realpath(source)
    target = File.expand_path(target)
    raise "Output must have the .opus extension" unless File.extname(target) == ".opus"
    raise "Refusing to overwrite audio: #{target}" if File.exist?(target)
    original = probe(source, ffprobe: ffprobe).fetch("streams").select { |s| s["codec_type"] == "audio" }
    raise "Expected exactly one audio stream" unless original.length == 1
    # A fresh temporary file prevents a failed conversion leaving a partial asset.
    # No -ac or gain/trim filters: preserve channels, level and the complete recording.
    Tempfile.create(["gr-opus-", ".opus"], File.dirname(target)) do |temporary|
      temporary.close
      _output, error, status = Open3.capture3(ffmpeg, *arguments(source, temporary.path))
      raise "Audio encoding failed: #{error}" unless status.success?
      encoded = probe(temporary.path, ffprobe: ffprobe).fetch("streams")
      valid = encoded.length == 1 && encoded[0]["codec_name"] == "opus" &&
        encoded[0]["channels"] == original[0]["channels"] && encoded[0]["sample_rate"].to_i == SAMPLE_RATE
      raise "Wrong encoded format or changed channel count" unless valid
      # EXCL also protects a destination created while ffmpeg was running.
      File.open(target, File::WRONLY | File::CREAT | File::EXCL | File::BINARY) do |destination|
        File.open(temporary.path, "rb") { |input| IO.copy_stream(input, destination) }
      end
      encoded[0]
    end
  end
end

if $PROGRAM_NAME == __FILE__
  abort "Usage: ruby tools/encode_audio.rb ORIGINAL NEW.opus [FFMPEG FFPROBE]" unless (2..4).cover?(ARGV.length)
  source, target, ffmpeg, ffprobe = ARGV
  result = GameRoomAudioEncoding.encode(source, target, ffmpeg: ffmpeg || "ffmpeg", ffprobe: ffprobe || "ffprobe")
  puts JSON.generate(file: target, bitrate: GameRoomAudioEncoding::BITRATE, vbr: true,
    frame_ms: GameRoomAudioEncoding::FRAME_MS, channels: result["channels"])
end
