require_relative '../support/room_interface'

sync = Object.new
sync.define_singleton_method(:next_event) { nil }
calls = 0
Form.driver = lambda do |form|
  button = form.cancel_button
  assert(button && button.label == 'Leave table', 'Recovery still exposes an unguarded Back action')
  resumes = 0
  form.define_singleton_method(:resume) { resumes += 1 }
  3.times do |index|
    button.trigger(:press)
    assert(resumes == (index == 2 ? 1 : 0), 'Cancelled/failed departure closed the recovery form')
  end
end
event = GameScreen.wait_for_connection(sync, leave_table: -> { calls += 1; [false, nil, true].fetch(calls - 1) })
assert(calls == 3 && event.kind == :left_table, 'Only confirmed departure may finish the recovery form')

# A missing callback is not permission to discard an existing membership.
Form.driver = lambda do |form|
  form.define_singleton_method(:resume) { raise 'Missing leave callback closed the recovery form' }
  form.cancel_button.trigger(:press)
end
assert(GameScreen.wait_for_connection(sync).nil?, 'An unrelated form return invented a departure')

# Exercise the real application branch without replacing wait_for_connection.
# Returning from a wait alone is not evidence of a server-side closure.
app = EltenGameRoom.allocate
app.define_singleton_method(:load_room_state) { |*, **| :unavailable }
attempts = 0
app.define_singleton_method(:leave_table_from_screen) { |_| attempts += 1; false }
Form.driver = ->(form) { form.cancel_button.trigger(:press) }
assert(app.send(:table_screen_state, {'__id' => 7}, nil, sync, nil) == :retry, 'Failed recovery departure returned to the lobby')
assert(attempts == 1, 'Application did not use its common guarded departure')
app.define_singleton_method(:leave_table_from_screen) { |_| true }
assert(app.send(:table_screen_state, {'__id' => 7}, nil, sync, nil).nil?, 'Confirmed recovery departure did not finish')

Form.driver = nil
puts 'PASS initial connection: real form/cancel action, denied/failed/confirmed departure, no nil-to-lobby shortcut'
