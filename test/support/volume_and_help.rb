require_relative 'host_source'
require_relative "ui"
require_relative "log"

class Program
  def self.server_app(**_options); end
  def self.app_runtime; nil; end
end
module Session
  def self.name; "Alice"; end
end
module EltenLink
  class Error < StandardError; end
  class Client; end
end
module EltenAPI
  module LiveSessions
    class Error < StandardError; end
    class TimeoutError < Error; end
    class SessionClosed < Error; end
    class StackFull < Error; end
  end
  module Tasks
    class Cancelled < StandardError; end
  end
  module KeyboardState
    def self.clear_current_frame; @cleared = true; end
  end
end

# Use the real host dispatcher/cache and native action representation.
require EltenTestHost.file("src/eapi/quickactions.rb")
EltenAPI::QuickActions.class_variable_set(:@@actions, [
  EltenAPI::QuickActions::QuickAction.new(:tips, "Help", [], 1),
  EltenAPI::QuickActions::QuickAction.new(:lastspeech, "Native F2", [], 2),
  EltenAPI::QuickActions::QuickAction.new(:tips, "Ctrl+F1", [], 13)
])
EltenAPI::QuickActions.class_variable_set(:@@hotkey_actions, nil)
require_relative "../../__app"

def assert(value, message)
  raise message unless value
end
