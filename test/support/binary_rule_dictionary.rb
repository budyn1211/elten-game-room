require_relative "binary_rules_load"

# Match Dictionary#loadmo/#find: keys stay binary, successful values become
# UTF-8, and a missing key is returned unchanged. No helpful encoding fix in
# the fake. Optionally exercise the real, local ELTEN dictionary as well.
class BinaryRuleDictionary
  def initialize(catalog)
    @catalog = catalog.to_h { |key, value| [key.b, value] }
  end
  def _(source)
    @catalog.fetch(source, source)
  end
end

$rules_dictionary = BinaryRuleDictionary.new(RULES_CATALOG)
if ENV["ELTEN_DICTIONARY_SOURCE"]
  module EltenAPI; module Resources; end; end
  module Programs
    def self.current_runtime; nil; end
    def self.runtime_from_caller; nil; end
  end
  require ENV.fetch("ELTEN_DICTIONARY_SOURCE")
  $rules_dictionary = Object.new.extend(EltenAPI::Dictionary)
  $rules_dictionary.send(:loadmo, BinaryRulesLoad.read(File.join(BinaryRulesLoad::ROOT, "locale/PL.mo")))
end

def _(source)
  return source if $rules_english
  $rules_dictionary.send(:_, source)
end

GameRoomTestLocalization.use_language(:pl)
