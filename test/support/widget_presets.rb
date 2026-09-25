require_relative 'host_source'
require_relative "settings_widget"

host = EltenTestHost.root
load File.join(host, "src/ui/input.rb")
module EltenAPI::KeyboardScheme
  def self.main_modifier; :control; end
  def self.key_code(key); key.is_a?(Integer) ? key : nil; end
end
