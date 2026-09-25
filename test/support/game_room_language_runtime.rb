require "json"
require "ripper"
require_relative "ui"

Object.send(:remove_method, :_)

module EltenAPI
  module Resources
    def self.keys(*)
      raise "The offline language test must not load host profiles or resources"
    end
  end
end

module Configuration
  class << self
    attr_accessor :language
  end
end

module Session
  def self.languages
    "en,pl-PL"
  end
end

class Program
  def self.server_app(**_options); end
end

module Programs
  class << self
    attr_accessor :current_runtime

    def namespace_for(_manifest)
      Module.new
    end

    def runtime_from_caller
      nil
    end

    def with_runtime(runtime)
      previous = current_runtime
      self.current_runtime = runtime
      yield
    ensure
      self.current_runtime = previous
    end
  end

  module Execution
    class Backend
      attr_reader :namespace

      def initialize(runtime)
        @runtime = runtime
      end
    end
  end
end

module GameRoomLanguageRuntime
  ROOT = File.expand_path("../..", __dir__)
  WAITED_FORMS = []

  module CaptureForms
    def wait
      GameRoomLanguageRuntime::WAITED_FORMS << self
      super
    end
  end

  def self.synthetic_catalog(entries, name: "Čeština", plural: "nplurals=3; plural=(n == 1) ? 0 : (n >= 2 && n <= 4) ? 1 : 2;")
    messages = { "" => "Content-Type: text/plain; charset=UTF-8\nPlural-Forms: #{plural}\nX-Language-Name: #{name}\n" }.merge(entries).sort
    data_offset = 28 + messages.length * 16
    data = "".b
    tables = [messages.map(&:first), messages.map(&:last)].map do |strings|
      strings.map do |string|
        row = [string.bytesize, data_offset + data.bytesize].pack("V2")
        data << string.b << "\0"
        row
      end.join
    end.join
    [0x950412de, 0, messages.length, 28, 28 + messages.length * 8, 0, 0].pack("V7") + tables + data
  end

  def self.host_snapshot
    dictionary = EltenAPI::Dictionary
    state = if dictionary.const_defined?(:Catalogs, false)
      # RC2 replaces the old parallel arrays/cache with immutable catalogs.
      # Read its private registry only in this fixture, under the native lock.
      dictionary.const_get(:CatalogMutex).synchronize do
        Marshal.dump([:Catalogs, :Docs, :Languages].map { |name| dictionary.const_get(name) })
      end
    else
      names = [:DictCache, :Docs, :Params, :Sources, :Translations, :Languages]
      Marshal.dump(names.map { |name| dictionary.const_get(name) })
    end
    {
      language: Configuration.language,
      dictionary: state,
      methods: [:_, :n_, :p_, :np_].map { |name| Object.instance_method(name) },
      ancestors: [Object, Module, Class].map(&:ancestors)
    }
  end

  def self.protect_host
    forbidden = [:setlocale, :loadmo, :loadlocale, :loadlocaledata, :parse_plurals]
    guard = TracePoint.new(:call) do |trace|
      if (trace.defined_class == EltenAPI::Dictionary && forbidden.include?(trace.method_id)) ||
          (trace.self.equal?(Configuration) && trace.method_id == :language=)
        raise "Game Room changed the host locale via #{trace.method_id}"
      end
    end
    before = host_snapshot
    guard.enable { yield }
  ensure
    guard&.disable
    raise "Game Room modified the host dictionary, language or translation methods" if before && host_snapshot != before
  end

  def self.load_host(root)
    program_path = File.join(root, "src/eapi/program.rb")
    source = File.binread(program_path).force_encoding(Encoding::UTF_8)
    blocks = source.scan(/^    class RuntimeBackend < Backend\r?\n.*?^    end\r?\n(?=\r?\n    class NativeBoxBridge)/m)
    raise "Host RuntimeBackend extraction no longer matches exactly once" unless blocks.length == 1
    block = blocks.first
    raise "Host RuntimeBackend extraction is incomplete" unless Ripper.sexp(block) && block.include?("@namespace.module_eval(code, filename, line)")
    line = source[0...source.index(block)].count("\n") + 1
    Programs::Execution.module_eval(block, program_path, line)
    require File.join(root, "src/eapi/dictionary")
    Object.include(EltenAPI)
    puts "Actual host RuntimeBackend: #{program_path}:#{line} (#{block.lines.length} lines); actual dictionary.rb"
  end

  module RelativeRequires
    def require_relative(name)
      origin = caller_locations(1, 1).first
      path = origin.absolute_path || origin.path
      runtime = Programs.current_runtime
      if runtime.is_a?(GameRoomLanguageRuntime::Runtime) && File.expand_path(path).start_with?(GameRoomLanguageRuntime::ROOT + "/")
        return runtime.require_file(File.expand_path(name, File.dirname(path)))
      end
      require File.expand_path(name, File.dirname(path))
    end
    private :require_relative
  end

  class Runtime
    Manifest = Struct.new(:name, :supported_languages)
    attr_reader :manifest, :backend, :loaded, :settings_reads, :source_encodings

    def initialize(settings:, catalogs: {})
      @manifest = Manifest.new("Game Room", ["EN", "PL"] + catalogs.keys)
      @settings = Marshal.load(Marshal.dump(settings))
      @catalogs = { "pl" => File.binread(File.join(ROOT, "locale/PL.mo")) }.merge(catalogs)
      @loaded = {}
      @settings_reads = []
      @source_encodings = []
      @backend = Programs::Execution::RuntimeBackend.new(self)
    end

    def namespace
      @backend.namespace
    end

    def language_files
      @catalogs
    end

    def language_data(code)
      @catalogs[code.to_s.downcase.split(/[-_]/).first]
    end

    def read_json(name, default: {})
      raise "Unexpected profile read: #{name}" unless name == "settings.json"
      @settings_reads << name
      Marshal.load(Marshal.dump(@settings || default))
    end

    def require_file(path)
      path = File.expand_path(path)
      path += ".rb" unless path.end_with?(".rb")
      raise "Source escaped Game Room checkout: #{path}" unless path.start_with?(ROOT + "/")
      return true if @loaded[path]
      code = File.binread(path)
      @source_encodings << code.encoding
      @loaded[path] = true
      @backend.evaluate(code, path, 1)
      true
    end

    def start
      Programs.with_runtime(self) { require_file(File.join(ROOT, "__app.rb")) }
      self
    end
  end
end

Kernel.prepend(GameRoomLanguageRuntime::RelativeRequires)
Form.prepend(GameRoomLanguageRuntime::CaptureForms)
