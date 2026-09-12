require "json"
require_relative "support/ui"

# ELTEN evaluates decompressed sources as binary strings, unlike Ruby's
# ordinary require. Reproduce that boundary without installing or running UI.
module BinaryRulesLoad
  ROOT = File.expand_path("..", __dir__)
  @loaded = {}

  def self.read(path)
    relative = path.delete_prefix(ROOT + "/")
    @entries ? @entries.fetch(relative.downcase).b : File.binread(path)
  end

  def self.package=(path)
    require "zip"
    require "zstd-ruby"
    require "stringio"
    require_relative "../../work/elten-3.0.1-app-dev/src/EAPI/programsigning"
    @entries = {}
    Zip::File.open(path) do |zip|
      manifest = JSON.parse(zip.read("__manifest.json")).fetch("payload")
      data = Programs::ProgramSigning.decode_package(zip.read(manifest.fetch("entry"))).fetch(:code_file)
      io = StringIO.new(data)
      magic = "Elten3AppPackage"
      raise "Invalid code header" unless io.read(magic.bytesize) == magic
      u32 = -> { io.read(4).unpack1("V") }
      @metadata = JSON.parse(Zstd.decompress(io.read(u32.call)))
      until io.eof?
        type = io.read(1).unpack1("C")
        name = type == 3 ? "locale/#{io.read(2)}.mo" : io.read(io.read(2).unpack1("v"))
        payload = io.read(u32.call)
        @entries[name.downcase] = type == 2 ? payload : Zstd.decompress(payload).b
      end
    end
  end

  def self.load(path)
    path = File.expand_path(path)
    return false if @loaded[path]
    @loaded[path] = true
    # Do not force UTF-8 here: that was precisely what hid the build-209 bug.
    TOPLEVEL_BINDING.eval(read(path), path, 1)
    true
  end

  def self.catalog
    bytes = read(File.join(ROOT, "locale/PL.mo"))
    count, originals, translations = bytes.byteslice(8, 12).unpack("V3")
    count.times.to_h do |index|
      length, offset = bytes.byteslice(originals + index * 8, 8).unpack("V2")
      source = bytes.byteslice(offset, length).force_encoding("UTF-8")
      length, offset = bytes.byteslice(translations + index * 8, 8).unpack("V2")
      [source, bytes.byteslice(offset, length).force_encoding("UTF-8")]
    end
  end

  module Requires
    def require_relative(name)
      origin = caller_locations(1, 1).first.path
      if origin.start_with?(BinaryRulesLoad::ROOT + "/")
        path = File.expand_path(name, File.dirname(origin))
        path += ".rb" unless path.end_with?(".rb")
        return BinaryRulesLoad.load(path) if path.start_with?(BinaryRulesLoad::ROOT + "/")
      end
      require File.expand_path(name, File.dirname(origin))
    end
    private :require_relative
  end
end

BinaryRulesLoad.package = ARGV.first if ARGV.first
RULES_CATALOG = BinaryRulesLoad.catalog
def _(text)
  utf8 = text.to_s.dup.force_encoding("UTF-8")
  RULES_CATALOG.fetch(utf8, utf8)
end

def n_(singular, plural, count)
  _(count.to_i == 1 ? singular : plural)
end

class Program
  def self.server_app(**_options); end
end

Kernel.prepend(BinaryRulesLoad::Requires)
BinaryRulesLoad.load(File.join(BinaryRulesLoad::ROOT, "__app.rb"))
registry = EltenGameRoom::GAME_REGISTRY
raise "Lost games during binary loading" unless registry.ids.length == 16
registry.ids.each do |id|
  game = registry.build(id)
  documents = game.rule_book(options: game.default_options).documents
  raise "Wrong rules documents: #{id}" unless documents.length == 3
  documents.each do |document|
    raise "Wrong title encoding: #{id}" unless document.title.encoding == Encoding::UTF_8 && document.title.valid_encoding?
    raise "Wrong text encoding: #{id}" unless document.text.encoding == Encoding::UTF_8 && document.text.valid_encoding?
  end
end
GameRoomContent::MonopolyBoards.choices.each do |choice|
  board = GameRoomContent::MonopolyBoards.build(choice.value)
  raise "Binary currency in #{choice.value}" unless board[:currency].encoding == Encoding::UTF_8
  raise "Binary symbol in #{choice.value}" unless board[:currency_symbol].encoding == Encoding::UTF_8
  board[:squares].each do |square|
    raise "Binary field name in #{choice.value}" unless square[:name].encoding == Encoding::UTF_8
  end
end
metadata = BinaryRulesLoad.instance_variable_get(:@metadata) || JSON.parse(File.read(File.join(BinaryRulesLoad::ROOT, "manifest.json")))
raise "Runtime build differs from package manifest" unless EltenGameRoom::GAME_ROOM_BUILD_ID.to_s == metadata.fetch("build_id").to_s
raise "Runtime version differs from package manifest" unless EltenGameRoom::GAME_ROOM_VERSION == metadata.fetch("version")
puts "Binary program loading, all 16 rule books and 19 Monopoly boards passed"
