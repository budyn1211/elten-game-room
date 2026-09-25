require_relative "binary_rules_load"

# Like the host, keep MO keys binary and return an unknown source unchanged.
class CatHeadTailBinaryDictionary
  def initialize(catalog)
    @catalog = catalog.to_h { |key, value| [key.b, value] }
  end
  def _(source)
    @catalog.fetch(source, source)
  end
end

$cht_dictionary = CatHeadTailBinaryDictionary.new(RULES_CATALOG)
if ENV["ELTEN_DICTIONARY_SOURCE"]
  module EltenAPI; module Resources; end; end
  module Programs
    def self.current_runtime; nil; end
    def self.runtime_from_caller; nil; end
  end
  require ENV.fetch("ELTEN_DICTIONARY_SOURCE")
  $cht_dictionary = Object.new.extend(EltenAPI::Dictionary)
  $cht_dictionary.send(:loadmo, BinaryRulesLoad.read(File.join(BinaryRulesLoad::ROOT, "locale/PL.mo")))
end

def _(source)
  return source unless $cht_language == :pl
  $cht_dictionary.send(:_, source)
end
