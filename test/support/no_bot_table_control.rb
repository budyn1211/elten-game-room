require_relative 'session_runner'
require_relative 'table_lifecycle_controls_2'
require_relative '../../games/taboo'
require_relative '../../games/scrabble'
require_relative '../../games/krowa'

def no_bot_command(h, writer, actor, selection, now: nil, moderator: false)
  h.as(writer) do
    # Match the normal UI/runner boundary: reconcile native owner changes
    # before asking the repository for the current match projection.
    h.transports.fetch(writer).room_snapshot(h.table)
    repository = h.repositories.fetch(writer)
    snapshot = repository.snapshot_for(h.session)
    replay = h.game.replay(snapshot.session, snapshot.events, repository)
    context = GameRoomGames::ActionContext.new(session_id: snapshot.session['__id'],
      table_id: h.table['__id'], table_owner: snapshot.session['__table_owner'],
      now: now || [Time.now.to_i, replay.state[:time].to_i, replay.state[:turn_started].to_i].max)
    status, plan = h.game.action_for(selection, replay, actor, context: context)
    assert(status == :ok, "#{h.game.id}: action after replacement failed: #{status}")
    repository.append_events(session: snapshot.session, sequence: repository.next_sequence(snapshot.session, snapshot.events),
      events: plan.events, actor: actor, controller: moderator)
  end
end
