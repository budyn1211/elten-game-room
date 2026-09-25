class FormTimer
  def initialize(*_args, **_kwargs); end
end
require_relative 'binary_rule_dictionary'
require_relative '../../lib/axel_pong/client'

def assert(value, message); raise message unless value; end
class PongUiAudio
  def suspend; end
  def update(*_args, **_kwargs); end
  def close; end
  def cycle_echo
    @index = (@index || 0) + 1
    %w[off noise tone][@index % 3]
  end
end
