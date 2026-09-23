require "tmpdir"
require "fileutils"
require "open3"
require "rbconfig"
require "json"
root = File.expand_path("..", __dir__)
Dir.mktmpdir("game-room-old-locale-cli-") do |temporary|
  %w[tools locale].each { |directory| FileUtils.mkdir_p(File.join(temporary, directory)) }
  FileUtils.cp(File.join(root, "tools/compile-polish-catalog.rb"), File.join(temporary, "tools/compile-polish-catalog.rb"))
  FileUtils.cp(File.join(root, "locale/PL.mo"), File.join(temporary, "locale/PL.mo"))
  File.write(File.join(temporary, "locale/catalog-contexts.json"), "{}")
  File.write(File.join(temporary, "tools/translations.rb"), 'require "json"; puts JSON.generate(ARGV); exit 17')
  [[], ["--check"]].each do |arguments|
    output, status = Open3.capture2e(RbConfig.ruby, File.join(temporary, "tools/compile-polish-catalog.rb"), *arguments)
    expected = arguments.empty? ? ["compile", "PL"] : ["check", "PL"]
    raise "the old compiler still bypasses PO: #{output}" unless status.exitstatus == 17 && output.include?(JSON.generate(expected))
  end
  output, status = Open3.capture2e(RbConfig.ruby, File.join(temporary, "tools/compile-polish-catalog.rb"), "locale/old-pl.json")
  raise "legacy JSON import can overwrite translator changes" unless !status.success? && output.include?("PL.po") && !output.include?('["compile"')
end
puts "Legacy compiler forwards compile/check to PO and rejects old JSON imports"
