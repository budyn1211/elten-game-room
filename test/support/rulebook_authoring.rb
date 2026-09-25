require_relative "ui"
require "json"

class Program
  def self.server_app(**_options); end
end
require_relative "../../__app"

def assert(condition, message)
  raise message unless condition
end
