require_relative "support/krowa"
require_relative "../games/krowa_support/server_store"
require_relative "../games/krowa_support/daily_access"
require_relative "../games/krowa_support/profile"
require_relative "../lib/game_audio"

class KrowaTestTables
  attr_accessor :enabled
  def initialize; @tables = {}; @enabled = true; end
  def available?; @enabled; end
  def fetch(name); @tables[name] ||= Table.new; end
  class Table
    attr_reader :rows, :queries
    attr_accessor :fail_after, :lost_ack, :user, :concurrent_first
    def initialize; @rows = []; @queries = []; @user = "Alice"; end
    def insert(values)
      if concurrent_first
        @concurrent_first = false
        insert(values)
      end
      row = values.merge("__id" => @rows.length + 1, "__insertion_user" => user, "__insertion_time" => 1)
      @rows << row
      if lost_ack
        @lost_ack = false
        raise IOError, "acknowledgement lost after server write"
      end
      row
    end
    def insert_many(values)
      values.each_with_index.map do |value, index|
        raise IOError, "partial batch" if fail_after && index >= fail_after
        insert(value)
      end
    end
    def select(where: {}, order: [], limit: 500, offset: 0, **extra)
      @queries << {where: where, order: order, limit: limit, offset: offset}.merge(extra)
      selected = @rows.select { |row| where.all? { |key, value| row[key] == value } }
      order.reverse_each { |key, direction| selected = selected.sort_by { |row| row[key] }; selected.reverse! if direction == "desc" }
      selected.drop(offset).first(limit)
    end
  end
end

run = KrowaTestGame.new
tables = KrowaTestTables.new
store = GameRoomGames::KrowaServerStore.new(server_tables: tables, bank: run.bank, user: "Alice")
assert(store.record_daily_open("2026-09-18") == :opened, "daily first start denied")
assert(store.record_daily_open("2026-09-18") == :already_used, "daily second start permitted")
daily_table = tables.fetch("krowa_daily_completions")
daily_table.concurrent_first = true
assert(store.record_daily_open("2026-09-19") == :already_used, "concurrent later claim won")
tables.enabled = false
assert(store.record_daily_open("2026-09-20") == :unavailable, "unchecked tables enable daily")
tables.enabled = true
calls = 0
guard = GameRoomGames::KrowaDailyAccess.new(run.program, user: "Alice", store: store,
  fetch: -> { calls += 1; Time.utc(2026, 9, 20, 22, 30) })
assert(guard.consume("variant" => "random") == true && calls.zero?, "non-daily start requests network")
options = {"variant" => "daily"}
assert(guard.consume(options) == true && options["__daily_day"] == "2026-09-21", "wrong Warsaw date")
assert(guard.consume(options).is_a?(String) && calls == 2, "stale prepared day or repeat start")
winter = GameRoomKrowa::WarsawDate.today_id(clock: -> { Time.utc(2026, 12, 1, 23, 30) })
assert(winter == "2026-12-02", "winter Warsaw date")
daily_table.lost_ack = true
lost_guard = GameRoomGames::KrowaDailyAccess.new(run.program, user: "Alice", store: store,
  fetch: -> { Time.utc(2026, 9, 22, 12) })
lost_options = {"variant" => "daily"}
assert(lost_guard.consume(lost_options).is_a?(String) && !lost_options.key?("__daily_day"), "failed daily claim started a game")
assert(lost_guard.consume(lost_options).is_a?(String), "lost daily acknowledgement allowed a second attempt")
assert(daily_table.rows.count { |row| row["day_key"] == 20260922 } == 1, "daily retry duplicated the claim")

code = "a" * 64
rounds = [{word: "kot", attempts: 2, solved: true}, {word: "las", attempts: 3, solved: true}, {word: "dom", attempts: 24, solved: false}]
details = tables.fetch("krowa_tower_rounds")
summaries = tables.fetch("krowa_tower_scores")
details.fail_after = 1
assert(store.publish_tower(run_code: code, participants: %w[Alice Bob], rounds: rounds) == :unavailable, "partial details reported success")
assert(details.rows.length == 1 && summaries.rows.empty?, "incomplete ranking made public")
details.fail_after = nil
summaries.lost_ack = true
assert(store.publish_tower(run_code: code, participants: %w[Alice Bob], rounds: rounds) == :published, "lost summary ack not resolved")
assert(store.publish_tower(run_code: code, participants: %w[Alice Bob], rounds: rounds) == :unchanged, "repeat publication duplicated run")
assert(details.rows.length == 3 && summaries.rows.length == 1, "duplicate publication rows")
assert(store.tower_rounds(code, user: "Alice").length == 3, "round detail lookup")
# No truncated 32-bit run key and no mixing another account's details.
details.user = "Bob"
details.insert("run_code" => code, "round" => 1, "word" => "rak", "attempts" => 1, "solved" => 1)
assert(store.tower_rounds(code, user: "Alice").first["word"] == "kot", "accounts mixed")
details.user = "Alice"
long_code = "b" * 64
501.times { |index| details.insert("run_code" => long_code, "round" => index + 1, "word" => "kot", "attempts" => 1, "solved" => 1) }
assert(store.tower_rounds(long_code, user: "Alice").length == 501, "tower details truncated at page boundary")
assert(details.queries.any? { |query| query[:offset] == 500 }, "pagination did not advance")

profile = GameRoomGames::KrowaProfile.new(run.program, user: "Alice")
run.automatic
assert(run.guess("Alice", "xyz", adding: true) == :ok, "custom noun addition")
run.automatic
profile.observe(run.replay)
profile.remove_dictionary(["xyz"])
writes = run.program.writes
3.times { profile.observe(run.replay) }
assert(!profile.data["dictionary"].include?("xyz") && run.program.writes == writes, "removed noun resurrected or idle disk writes")
other = KrowaTestGame.new(program: run.program)
other.context.session_id = 50
other.automatic; other.guess("Alice", "xyz", adding: true); other.automatic
profile.observe(other.replay)
assert(profile.data["dictionary"].include?("xyz"), "explicit re-add denied")
profile.remove_dictionary(["xyz"])
profile = GameRoomGames::KrowaProfile.new(run.program, user: "Alice")
profile.observe(run.replay); profile.observe(other.replay)
assert(!profile.data["dictionary"].include?("xyz"), "older replay undid a later removal")
assert(GameRoomGames::KrowaProfile.new(run.program, user: "Bob").data["dictionary"].empty?, "dictionary crosses accounts")

class KrowaAudioProgram < KrowaTestProgram
  Sound = Struct.new(:volume, :plays, :closed) { def play; self.plays = plays.to_i + 1; end }
  attr_accessor :enabled, :level
  attr_reader :effects, :sounds
  def initialize; super; @enabled = true; @level = 1.0; @effects = []; @sounds = []; end
  def game_room_sound_enabled?(_); enabled; end
  def game_room_sound_volume(_); level; end
  def create_sound_from_asset(_asset, **_); Sound.new.tap { |s| @sounds << s }; end
  def play_sound_from_asset(asset, **options); @effects << [asset, options]; end
  def manage(_); end
  def release(sound, close:); sound.closed = close; end
end
program = KrowaAudioProgram.new
audio = GameRoomAudio.new(program, game_id: "krowa")
audio.update("krowa-single"); audio.play("krowa-success")
assert(program.sounds.empty? && program.effects.empty?, "optional audio default on")
audio.save("music" => true, "effects" => true, "music_volume" => 40, "effects_volume" => 70)
program.level = 0.2
audio.update("krowa-single"); audio.play("krowa-success")
assert((program.sounds.last.volume - 0.08).abs < 0.00001, "music ignores shared volume")
assert((program.effects.last[1][:volume] - 0.14).abs < 0.00001, "effect ignores shared volume")
program.enabled = false
audio.update("krowa-single"); audio.play("krowa-success")
assert(program.sounds.last.closed && program.effects.length == 1, "shared mute ignored")
program.enabled = true; program.level = 0
audio.update("krowa-single"); audio.play("krowa-success")
assert(program.effects.length == 1, "zero volume still plays")
audio.close
puts "Krowa: daily account claim/date, partial ranking/retry/pagination, dictionary removal, shared audio controls OK"
