require_relative "card_timeouts"
require_relative "../../lib/saved_games"

class TimedArchiveMemory
  def initialize; @root = {}; end
  def read_json(_path, default:); JSON.parse(JSON.generate(@root)); end
  def update_json(_path, default:)
    root = read_json(nil, default: {})
    yield root
    @root = JSON.parse(JSON.generate(root))
  end
end
