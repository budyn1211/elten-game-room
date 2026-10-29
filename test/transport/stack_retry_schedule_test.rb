require_relative '../support/host_source'
require EltenTestHost.file('src/eltenlink/error.rb')
require_relative '../support/assertions'
require_relative '../../lib/game_sync'
require_relative '../../lib/game_session_feed'
include GameRoomTest::Assertions

class StackRetryTransport
  attr_reader :reads
  attr_accessor :error

  def initialize; @reads = 0; end
  def pending_move_error(_id); nil; end
  def reconcile(_id)
    @reads += 1
    raise @error if @error
  end
end

transport = StackRetryTransport.new
feed = GameRoomSessionFeed.new(transport, 41)
now = 0.0
sync = GameRoomSync::Controller.new(transport: feed, table_id: 41, clock: -> { now })
failure = EltenLink::Error.new('Live session stack request failed', code: 'network_error')
feed.notify(:network_error, failure)
assert_equal(nil, sync.next_event)
assert_equal(5.0, sync.next_reconcile_at, 'The first stack recovery must wait five seconds, not thirty')

# SDK errors and gaps can arrive more often than our retry interval. They
# must not keep moving its deadline into the future or count as new attempts.
[1.0, 2.0, 4.99].each do |tick|
  now = tick
  feed.notify(:network_error, failure)
  feed.notify(:recovery, nil)
  assert_equal(nil, sync.next_event)
  assert_equal(5.0, sync.next_reconcile_at, 'Native error notices postponed an already scheduled read')
  assert_equal(0, transport.reads, 'A notice performed an early stack read')
end

[[5.0, 15.0], [15.0, 30.0], [30.0, 45.0]].each do |tick, deadline|
  now = tick
  assert_equal(:recovery, sync.next_event&.kind, 'Recovery required another move or key press')
  transport.error = failure
  assert_raises(EltenLink::Error) { sync.synchronize { :unused } }
  assert_equal(deadline, sync.next_reconcile_at, 'Retry intervals must be 5, 10, then at most 15 seconds')
  # The executor also observes this same exception after synchronize raises.
  sync.failed!(failure)
  assert_equal(deadline, sync.next_reconcile_at, 'One failed read was counted twice')
end
assert_equal(3, transport.reads)
now = 45.0
transport.error = nil
assert_equal(:recovery, sync.next_event&.kind)
assert_equal(:current, sync.synchronize { :current })
assert(!sync.recovery_pending?, 'Successful catch-up retained an outage')
assert(sync.next_reconcile_at.infinite?, 'Healthy play started polling')
100.times { assert_equal(nil, sync.next_event) }
assert_equal(4, transport.reads)

now = 100.0
feed.notify(:network_error, failure)
sync.next_event
assert_equal(105.0, sync.next_reconcile_at, 'Success did not reset the failure count')

now = 101.0
limited = EltenLink::Error.new('Too many requests', code: 'rate_limits.exceeded',
  response: {'error' => {'retry_after' => 90}})
limited.define_singleton_method(:retry_after) { 90.0 }
feed.notify(:network_error, limited)
sync.next_event
assert_equal(191.0, sync.next_reconcile_at, 'An explicit server cooldown was shortened')
now = 110.0
feed.notify(:network_error, failure)
sync.next_event
assert_equal(191.0, sync.next_reconcile_at, 'A generic error changed the retained Retry-After boundary')
sync.synchronize(complete: false) { :cached_chat }
assert_equal(191.0, sync.next_reconcile_at, 'A partial UI/chat update cleared recovery')

feed.notify(:closed, nil)
assert_equal(:closed, sync.next_event&.kind, 'Confirmed closure waited for the network retry')
assert(!sync.recovery_pending?)
bug = NoMethodError.new('not a network fault')
assert_raises(NoMethodError) { sync.failed!(bug) }
assert(!sync.recovery_pending?, 'A programmer error scheduled a network retry')

now = 0.0
custom = GameRoomSync::Controller.new(transport: feed, table_id: 41, error_backoff: 2.0, clock: -> { now })
custom.failed!(failure)
assert_equal(2.0, custom.next_reconcile_at)
now = 2.0
custom.next_event
custom.failed!(failure)
assert_equal(6.0, custom.next_reconcile_at, 'A caller-provided retry interval was ignored')

# Submission may enter synchronize directly after its cooldown, without
# consuming next_event first. It is still one real retry, not another hint.
now = 6.0
transport.error = failure
assert_raises(EltenLink::Error) { custom.synchronize { :unused } }
assert_equal(12.0, custom.next_reconcile_at, 'Direct recovery did not advance to the capped third interval')
custom.failed!(failure)
assert_equal(12.0, custom.next_reconcile_at, 'The direct recovery exception was counted twice')

puts 'PASS stack retry schedule: 5/10/15-second bounded intervals, no deadline starvation or duplicate counting, reset, Retry-After, partial reads, closure and programmer errors'
