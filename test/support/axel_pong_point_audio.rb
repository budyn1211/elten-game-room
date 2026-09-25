require_relative 'pong_audio'
require_relative 'pong_client'

class PongSound
  def length; 2.0; end
  def finished?; !playing?; end
end
