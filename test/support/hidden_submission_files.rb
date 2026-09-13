require "json"
require "fileutils"
require_relative "../../lib/hidden_submissions"

# Mirrors ELTEN Program.write_binary_file, including replacement and cleanup.
# All paths belong to a disposable test directory, never a real user profile.
class HiddenSubmissionFiles
  attr_reader :directory, :writes
  attr_accessor :blocked

  def initialize(directory)
    @directory = directory
    @writes = []
    @blocked = []
  end

  def read_json(name, default:)
    path = File.join(directory, name)
    File.file?(path) ? JSON.parse(File.binread(path)) : default
  end

  def write_json(name, value)
    writes << name
    path = File.join(directory, name)
    tmp = path + ".tmp-#{Process.pid}-#{Thread.current.object_id}"
    File.binwrite(tmp, JSON.generate(value).b)
    raise Errno::EACCES, "simulated replacement lock" if blocked.include?(name)
    FileUtils.mv(tmp, path)
    true
  ensure
    File.delete(tmp) if tmp && File.file?(tmp)
  end

  def retry_now
    instance_variable_get(:@game_room_hidden_submission_stores)&.each_value { |s| s[:retry_at] = 0.0 }
  end
end
