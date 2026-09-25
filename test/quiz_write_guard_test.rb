require 'tmpdir'
require 'stringio'
require_relative '../tools/support/quiz_write_guard'

def assert(value, message); raise message unless value; end
def rejected(message)
  yield
  raise 'expected audit rejection'
rescue ArgumentError => error
  assert(error.message.include?(message), "unexpected rejection: #{error.message}")
end
Dir.mktmpdir('quiz-preflight-') do |folder|
  source = File.join(folder, 'review.json')
  target = File.join(folder, 'pack.rb')
  approval = File.join(folder, 'approved.json')
  File.write(source, '{"decisions":[]}')
  File.write(target, "version: 4,\n")
  args = {tool: 'test-audit', inputs: [source], outputs: [target], versions: {target => 4}}
  output = StringIO.new
  assert(!QuizWriteGuard.check!(**args, options: {}, output: output), 'dry run permitted writes')
  assert(File.read(target) == "version: 4,\n" && Dir.children(folder).length == 2, 'dry run wrote files')
  File.write(approval, output.string)
  rejected('requires --expect') { QuizWriteGuard.check!(**args, options: {apply: true}) }
  assert(QuizWriteGuard.check!(**args, options: {apply: true, expect: approval}), 'approved exact inputs rejected')
  File.write(source, '{"decisions":["changed"]}')
  rejected('changed since approval') { QuizWriteGuard.check!(**args, options: {apply: true, expect: approval}) }
  File.write(source, '{"decisions":[]}')
  File.write(target, "version: 4,\n# newer edit\n")
  rejected('changed since approval') { QuizWriteGuard.check!(**args, options: {apply: true, expect: approval}) }
  args[:versions] = {target => 3}
  output = StringIO.new
  QuizWriteGuard.check!(**args, options: {}, output: output)
  File.write(approval, output.string)
  rejected('version downgrade') { QuizWriteGuard.check!(**args, options: {apply: true, expect: approval}) }
end
puts 'Historical audit boundary: no default writes, exact source/destination approval and version downgrade rejection passed'
