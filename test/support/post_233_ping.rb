require_relative 'host_source'
require_relative 'volume_and_help'
require 'timeout'

class PingManualWorker
  attr_reader :starts
  def initialize; @starts = 0; end
  def busy?; !!(@operation || @result); end
  def closed?; false; end
  def start(&block); @starts += 1; @operation = block; true; end
  def finish
    @result = [@operation.call, nil]
  rescue StandardError => error
    @result = [nil, error]
  ensure
    @operation = nil
  end
  def take; result, @result = @result, nil; result; end
end
