require_relative 'ui'
require_relative '../../lib/game_surfaces'
require_relative 'session_runner'
require_relative '../../games/makao'
require_relative '../../games/poker'
require_relative '../../games/quiz_party'
require_relative '../../content/languages'
require_relative '../../content/quiz_pl_wikidata'

class RunnerTestClock
  attr_accessor :value
  def initialize(value); @value = value; end
  def now(_session); @value.to_i; end
  def now_f(_session); @value.to_f; end
end
