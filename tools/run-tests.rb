#!/usr/bin/env ruby

require "rbconfig"

root = File.expand_path("..", __dir__)
tests = Dir.chdir(root) { Dir["test/*_test.rb"].sort }

abort "No tests found" if tests.empty?

tests.each_with_index do |test, index|
  puts "[#{index + 1}/#{tests.length}] #{test}"
  success = system(RbConfig.ruby, test, chdir: root)
  abort "Test failed: #{test}" if !success
end

puts "All #{tests.length} tests passed"
