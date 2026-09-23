require "rbconfig"

check = ARGV.delete("--check")
abort "JSON translation imports are no longer supported. Edit locale/PL.po instead." unless ARGV.empty?
script = File.expand_path("translations.rb", __dir__)
environment = { "BUNDLE_GEMFILE" => File.expand_path("Gemfile.i18n", __dir__) }
exec environment, RbConfig.ruby, script, check ? "check" : "compile", "PL"
