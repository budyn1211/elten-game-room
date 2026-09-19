require_relative "../lib/game_room_clock"
require_relative "../lib/game_session_clock"
require_relative "../lib/notification_time"

def assert(value, message); raise message unless value; end
module EltenAPI
  module Tasks
    class Cancelled < StandardError; end
  end
end

wall, elapsed, requests, failure = 99_000, 10.0, 0, nil
clock = GameRoomClock::Clock.new(fetch: -> { requests += 1; raise failure if failure; 1000 + elapsed - 10 },
  elapsed: -> { elapsed }, wall: -> { wall })
assert(clock.now == wall && requests == 0, "offline access fetched the network")
assert(clock.synchronize == 1000 && requests == 1, "clock did not use server sample")
[-864_000,864_000].each do |skew|
  wall = skew
  elapsed += 10
  1000.times { assert(clock.now == 1000+elapsed-10, "OS correction affected server time") }
  clock.synchronize
end
assert(requests == 1, "UI clock reads or a fresh synchronization sent HTTP")
elapsed += 300
failure = IOError.new("offline")
assert(clock.synchronize == 1320 && requests == 2, "outage replaced confirmed time")
10.times { clock.synchronize }
assert(requests == 2, "outage caused a request storm")
elapsed += 60
failure = EltenAPI::Tasks::Cancelled.new
begin
  clock.synchronize
  raise "cancellation swallowed"
rescue EltenAPI::Tasks::Cancelled
end
failure = nil
assert(clock.synchronize == 1380, "clock could not recover")
[nil,0,-1,"1000",Float::NAN,Float::INFINITY].each do |bad|
  invalid = GameRoomClock::Clock.new(fetch: -> { bad })
  begin
    invalid.synchronize
    raise "invalid initial server time accepted: #{bad}"
  rescue IOError
    assert(!invalid.synchronized?, "invalid sample became authoritative")
  end
end

# A refresh in the network worker never holds the lock used by the UI.
entered, release = Queue.new, Queue.new
elapsed = 0.0
blocked = false
requests = 0
clock = GameRoomClock::Clock.new(elapsed: -> { elapsed }, fetch: -> {
  requests += 1
  if blocked
    entered << true
    release.pop
  end
  2000 + elapsed
})
clock.synchronize
elapsed, blocked = 301.0, true
worker = Thread.new { clock.synchronize }
entered.pop
reader = Thread.new { 1000.times { clock.now } }
begin
  assert(reader.join(1), "clock read waited on HTTP refresh")
ensure
  release << true
  worker.join
  reader.join
end
threads = 8.times.map { Thread.new { clock.synchronize } }
threads.each(&:join)
assert(requests == 2, "concurrent start duplicated a clock request")

GameRoomClock.instance_variable_set(:@clock, clock)
session = {"created_at"=>100,"__server_started_at"=>2000,"__clock_offset"=>5}
state = GameRoomSessionClock.attach({},session)
assert(GameRoomSessionClock.for_state(state) == 396, "view lost the existing game epoch")
frozen = GameRoomSessionClock.attach({},session.merge("__frozen_at"=>2010))
assert(GameRoomSessionClock.for_state(frozen) == 105, "pause used OS time")
assert(GameRoomSessionClock.new.now(session) == GameRoomSessionClock.for_state(state), "UI and action clocks differ")

Envelope = Struct.new(:date,:expiration,:metadata,keyword_init:true)
AppEnvelope = Struct.new(:created_at,:metadata,keyword_init:true)
[-7200,7200].each do |skew|
  metadata = {"created_at"=>1000+skew,"expires_at"=>1300+skew}
  notice = Envelope.new(date:1000,expiration:300,metadata:metadata)
  assert(GameRoomNotificationTime.expires_at(notice)==1300,"sender clock changed expiration")
  opened = AppEnvelope.new(created_at:1000,metadata:metadata)
  assert(GameRoomNotificationTime.expires_at(opened)==1300,"opening reset or skewed expiration")
  metadata["native_expires_at"] = 1100
  assert(GameRoomNotificationTime.expires_at(opened)==1100,"private authorization deadline extended")
  metadata.delete("native_expires_at")
  metadata["expires_in"] = 50
  assert(GameRoomNotificationTime.expires_at(opened)==1050,"remaining delivery TTL ignored")
end
assert(GameRoomNotificationTime.expires_at(AppEnvelope.new(created_at:1000,metadata:{expires_in:40}))==1040,"symbol metadata lost")
assert(GameRoomNotificationTime.expires_at(Struct.new(:metadata).new({"expires_at"=>300}))==300,"old adapter compatibility lost")

# Production API shape, bounded timeout and no host helper fallback to Time.now.
module EltenLink
  module System
    def self.server_time(*); raise "Do not use the host wall-clock fallback"; end
  end
  class Client
    class << self; attr_accessor :response, :requests; end
    self.requests = []
    def api_data(*args, **kwargs)
      self.class.requests << [args, kwargs]
      self.class.response
    end
  end
end
EltenLink::Client.response = {"time" => 1_800_000_000}
GameRoomClock.instance_variable_set(:@clock, nil)
GameRoomClock.synchronize
assert(GameRoomClock.now.between?(1_800_000_000, 1_800_000_002), "production clock ignored the API sample")
assert(EltenLink::Client.requests == [[["GET", "/api/v1/system/time", nil], {timeout: 5}]], "wrong time endpoint or timeout")
[nil, {}, {"time" => -1}, {"time" => "1800000000"}].each do |response|
  EltenLink::Client.response = response
  GameRoomClock.instance_variable_set(:@clock, nil)
  before = EltenLink::Client.requests.size
  2.times do
    begin
      GameRoomClock.synchronize
      raise "invalid API time accepted"
    rescue GameRoomNetworkErrors::ClockUnavailable
    end
  end
  assert(EltenLink::Client.requests.size == before + 1, "first synchronization failure bypassed retry backoff")
end
tick, broken = 0, false
bug_clock = GameRoomClock::Clock.new(elapsed: -> { tick }, fetch: -> { raise NoMethodError, "bug" if broken; 1000 })
bug_clock.synchronize
tick, broken = 301, true
begin
  bug_clock.synchronize
  raise "programming error swallowed by clock fallback"
rescue NoMethodError
end
puts "PASS server clock: wall jumps, outage, recovery, validation, cancellation, concurrent/nonblocking reads, game epoch/pause and server notification TTL"
