require 'digest'
require 'json'
require 'optparse'

# Historical audits may be inspected freely, but applying an old decision file
# requires explicit approval of the exact source, report and destination bytes.
# This guard performs no writes; its default output is a preflight manifest.
module QuizWriteGuard
  def self.options!(args)
    options = {apply: false}
    OptionParser.new do |parser|
      parser.on('--apply', 'Apply only the approved input manifest') { options[:apply] = true }
      parser.on('--expect MANIFEST', 'JSON manifest captured and reviewed in dry-run') { |path| options[:expect] = path }
    end.parse!(args)
    options
  end

  def self.check!(tool:, inputs:, outputs:, versions:, options:, output: $stdout)
    inputs = inputs.map { |path| File.expand_path(path) }
    outputs = outputs.map { |path| File.expand_path(path) }
    inputs.each { |path| raise ArgumentError, "Missing audit input: #{path}" unless File.file?(path) }
    snapshot = {
      'format' => 1, 'tool' => tool,
      'versions' => versions.to_h { |path, value| [File.expand_path(path), Integer(value)] },
      'files' => (inputs + outputs).uniq.sort.to_h do |path|
        [path, File.file?(path) ? Digest::SHA256.file(path).hexdigest : nil]
      end
    }
    downgrades = snapshot['versions'].filter_map do |path, planned|
      next unless File.file?(path)
      current = File.read(path, encoding: 'UTF-8').scan(/^\s*version:\s*(\d+)/).flatten.map(&:to_i).max
      "#{path}: #{current} -> #{planned}" if current && current > planned
    end
    if !options[:apply]
      output.puts JSON.pretty_generate(snapshot)
      warn "DRY RUN: no files written. Review all decisions before --apply --expect MANIFEST."
      warn "Historical data version cannot replace current data: #{downgrades.join('; ')}" unless downgrades.empty?
      return false
    end
    raise ArgumentError, 'Applying an audit requires --expect MANIFEST' unless options[:expect]
    expected = JSON.parse(File.read(options[:expect], encoding: 'UTF-8'))
    raise ArgumentError, 'Audit input or destination changed since approval' unless expected == snapshot
    raise ArgumentError, "Refusing data version downgrade: #{downgrades.join('; ')}" unless downgrades.empty?
    true
  end

  def self.content_paths(root)
    %w[quiz_general_en.rb quiz_general_en_data.rb quiz_pl_wikidata.rb quiz_pl_wikidata_data.rb
      quiz_witcher_pl.rb quiz_witcher_pl_data.rb quiz_witcher_pl_medium_data.rb QUIZ_IMPORT_REPORT.json].map { |name| File.join(root, 'content', name) }
  end

  def self.versions(root, version)
    %w[quiz_general_en.rb quiz_pl_wikidata.rb quiz_witcher_pl.rb].to_h { |name| [File.join(root, 'content', name), version] }
  end
end
