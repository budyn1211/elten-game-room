require_relative 'host_source'
require_relative "game_option_encoding"

# Actual host checkbox speech, in addition to the binary-loaded form and the
# existing faithful control doubles. This does not launch an ELTEN client.
module Configuration
  def self.controlspresentation; :voice_only; end
end
module EltenAPI
  module Controls
    class FormField; end
  end
end
host = EltenTestHost.root
load File.join(host, "src/ui/controls/check_box.rb")
