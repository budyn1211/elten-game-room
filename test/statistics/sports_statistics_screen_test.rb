require_relative '../support/quiz_creator_native'
require_relative '../support/native_tasks'
require_relative '../../lib/sports_rankings/screen'
require_relative '../../lib/game_statistics_screen'

GameRoomLocalization.boot(host_language: 'en', settings: {'interface_language'=>'en'})
module Session
  def self.name; @sports_user || 'Alice'; end
  def self.sports_user=(value); @sports_user=value; end
end
module GameRoomClock
  def self.synchronize; true; end
end

def sports_frame(form)
  EltenAPI::KeyboardState.update(raw_state: "\0"*256, events: [], now: Process.clock_gettime(Process::CLOCK_MONOTONIC))
  $input_frame_serial = $input_frame_serial.to_i + 1
  $keyboard_state_frame_serial, $keyboard_state_frame_thread = $input_frame_serial, Thread.current
  $activecontrols = []
  form.update
end

def settle_sports(form)
  Timeout.timeout(5) do
    loop do
      sports_frame(form)
      break unless form.fields.first.text == 'Loading statistics'
      Thread.pass
    end
  end
end

runtime = TestTaskRuntime.new('sports-statistics-ui')
program = Object.new
program.class.define_singleton_method(:app_runtime) { runtime }
program.class.define_singleton_method(:analytics_enabled?) { $developer_mode != true }
ui, calls = Thread.current, []
warnings = []
original_developer_mode = $developer_mode
original_warning = Log.method(:warning)
Log.define_singleton_method(:warning) { |message| warnings << message }
rows = [{'user'=>'Alice','won'=>4,'lost'=>2,'scored'=>45,'conceded'=>31},
  {'user'=>'Bob','won'=>1,'lost'=>5,'scored'=>20,'conceded'=>50}]
store = Object.new
store.define_singleton_method(:report) do |**options|
  raise 'Statistics network read ran on the UI thread' if Thread.current == ui
  calls << options
  rows.map(&:dup)
end
game = Struct.new(:id, :name).new('axel_pong', 'Axel Pong')
build_screen = -> {
  GameRoomSportsRankings::Screen.new(program:program,game:game,
    service:Struct.new(:store).new(store),today:-> {Date.new(2026,10,24)})
}
screen = build_screen.call
screen.instance_variable_set(:@mode, 'singles')
screen.define_singleton_method(:input_user) { |_header| 'Bob' }
Form.driver = lambda do |form|
  field, period, choose_player, own, refresh = form.fields
  assert(field.is_a?(EditBox) && (field.flags & EditBox::Flags::ReadOnly) != 0, 'Statistics are not read-only text')
  assert(period.options == ['All time','Last 7 days','Last 30 days','Last six months','Last year'], 'Statistics period choices differ')
  settle_sports(form)
  assert(field.header == 'Alice: All time', 'The initial report is not the current account across all recorded history')
  assert(field.text.lines.size == 6 && field.text.include?('Matches won: 4') && field.text.include?('Goal balance: 14'), 'A requested counter is missing')
  assert(!field.text.match?(/ranking|place|points/i), 'Statistics still expose a ranking')
  form.index = 1
  period.index = 1
  period.trigger(:move)
  settle_sports(form)
  assert(calls.last.values_at(:from_day,:to_day)==[20261018,20261024], 'The seven-day period is not inclusive')
  assert(form.index == 1 && period.index == 1, 'A completed read stole focus from the period selector')
  choose_player.trigger(:press)
  settle_sports(form)
  assert(field.header == 'Bob: Last 7 days' && field.text.include?('Matches won: 1'), 'Selecting another player did not replace the report')
  own.trigger(:press)
  settle_sports(form)
  assert(field.header == 'Alice: Last 7 days' && field.text.include?('Matches won: 4'), 'My statistics did not restore the signed-in player')
  refresh.trigger(:press)
  settle_sports(form)
  assert(calls.last[:fresh], 'Explicit Refresh reused the old snapshot')
  assert(screen.send(:range,3,Date.new(2026,10,24))==[20260425,20261024], 'The six-month calendar period differs')
  form.cancel_button.trigger(:press)
end

begin
  Programs.with_runtime(runtime) { screen.send(:show_statistics) }
  assert(calls.first[:from_day].nil?, 'The default report omitted recorded history')

  # Keep only the latest selection while the first bounded read is pending.
  gate, entered = Queue.new, Queue.new
  held = true
  store.define_singleton_method(:report) do |**options|
    calls << options
    if held
      held = false
      entered << options[:cancellation_token]
      gate.pop
    end
    rows.map(&:dup)
  end
  screen = build_screen.call
  screen.instance_variable_set(:@mode,'doubles')
  Form.driver = lambda do |form|
    Timeout.timeout(5) { entered.pop }
    before = calls.size
    period = form.fields[1]
    [1,2,3,4,1].each { |index| period.index=index; period.trigger(:move) }
    assert(calls.size==before, 'Rapid selections launched overlapping network reads')
    gate << true
    settle_sports(form)
    assert(calls.size==before+1 && calls.last[:mode]=='doubles' && calls.last[:from_day]==20261018,
      'The final selection was dropped or intermediate selections were queried')
    assert(form.fields.first.header=='Alice: Last 7 days', 'A stale read replaced the current report')
    form.cancel_button.trigger(:press)
  end
  Programs.with_runtime(runtime) { screen.send(:show_statistics) }

  # A read error must not become a six-zero report; Refresh can recover.
  unavailable = true
  store.define_singleton_method(:report) do |**_options|
    raise GameRoomSportsRankings::Unavailable, 'offline' if unavailable
    []
  end
  screen = build_screen.call
  screen.instance_variable_set(:@mode,'singles')
  Form.driver = lambda do |form|
    settle_sports(form)
    assert(form.fields.first.text=='Player statistics are unavailable. Try Refresh.', 'Failure became zero statistics')
    unavailable = false
    form.fields[4].trigger(:press)
    settle_sports(form)
    assert(form.fields.first.text.include?('Matches won: 0'), 'An empty successful report is not distinct from an error')
    form.cancel_button.trigger(:press)
  end
  Programs.with_runtime(runtime) { screen.send(:show_statistics) }
  assert(warnings==['Player statistics read failed: GameRoomSportsRankings::Unavailable'], 'Unexpected or missing read-error diagnostics')

  # Changing accounts closes the old view and cancels its pending read.
  token = nil
  store.define_singleton_method(:report) do |**options|
    entered << options[:cancellation_token]
    gate.pop
    rows.map(&:dup)
  end
  screen = build_screen.call
  screen.instance_variable_set(:@mode,'singles')
  Form.driver = lambda do |form|
    form.instance_variable_set(:@wait,true)
    token = Timeout.timeout(5) { entered.pop }
    Session.sports_user = 'Bob'
    sports_frame(form)
    assert(!form.instance_variable_get(:@wait), 'Account change left the old report open')
    form.cancel_button.trigger(:press)
    gate << true
  end
  Programs.with_runtime(runtime) { screen.send(:show_statistics) }
  assert(token.cancelled?, 'Closing statistics did not cancel the pending request')
  Session.sports_user = 'Alice'

  # The same host-mode predicate also invalidates a captured player-statistics
  # view. Its pending normal-mode read is cancelled, not shown as a send error.
  screen = build_screen.call
  screen.instance_variable_set(:@mode, 'singles')
  Form.driver = lambda do |form|
    form.instance_variable_set(:@wait, true)
    token = Timeout.timeout(5) { entered.pop }
    $developer_mode = true
    form.fields[4].trigger(:press)
    sports_frame(form)
    assert(!form.instance_variable_get(:@wait), 'Developer mode kept the old sports statistics view open')
    form.cancel_button.trigger(:press)
    gate << true
  end
  Programs.with_runtime(runtime) { screen.send(:show_statistics) }
  assert(token.cancelled?, 'Developer mode did not cancel the pending statistics read')
  unavailable_messages = []
  screen = build_screen.call
  screen.define_singleton_method(:alert) { |message| unavailable_messages << message }
  screen.define_singleton_method(:choose) { |*_, **_| raise 'Developer mode opened the sports selector' }
  Programs.with_runtime(runtime) { screen.run }
  assert(unavailable_messages == ['Player statistics are temporarily unavailable.'], 'Developer mode did not report statistics as unavailable')
  $developer_mode = original_developer_mode

  # The common Statistics entry routes General and opt-in games independently.
  opened = []
  client = Struct.new(:key,:opened) do
    def run; opened << key; end
    def close; opened << :closed; end
  end
  statistic_game = Struct.new(:id,:name,:enabled,:factory) do
    def supports_player_statistics?; enabled; end
    def build_player_statistics_client(_program); factory.call; end
  end
  games = [statistic_game.new('krowa','Krowa',false,nil),
    statistic_game.new('axel_pong','Axel Pong',true,-> {client.new(:pong,opened)}),
    statistic_game.new('audio_ball','Audio Ball',true,-> {client.new(:ball,opened)})]
  registry = Object.new
  registry.define_singleton_method(:ids) { games.map(&:id) }
  registry.define_singleton_method(:build) { |id| games.find { |value| value.id==id } }
  Form.driver = lambda do |form|
    list = form.fields.first
    assert(list.options==['General','Axel Pong','Audio Ball'], 'Statistics did not separate program activity from player results')
    3.times { |index| list.index=index; form.accept_button.trigger(:press) }
    form.cancel_button.trigger(:press)
  end
  Programs.with_runtime(runtime) do
    GameRoomStatisticsMenu.new(program:program,registry:registry,general:-> {opened << :general}).run
  end
  assert(opened==[:general,:pong,:closed,:ball,:closed], 'The Statistics menu routed or closed the wrong client')
ensure
  $developer_mode = original_developer_mode
  Session.sports_user = 'Alice'
  gate << true if gate
  screen.close
  runtime.close
  Log.define_singleton_method(:warning, original_warning)
end
puts 'PASS native sports statistics: routing, six counters, periods, responsive reads, coalescing, errors, focus, account/developer-mode cancellation and disabled entry'
