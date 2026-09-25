# One source checkout for all native-host contracts. Never silently test a
# different ELTEN version because an old developer directory happens to exist.
module EltenTestHost
  def self.root
    value = ENV["ELTEN_HOST_SOURCE"]
    value = File.expand_path("../..", ENV["ELTEN_HOST_EAPI"]) if value.to_s.empty? && !ENV["ELTEN_HOST_EAPI"].to_s.empty?
    File.expand_path(value.to_s.empty? ? "../../../elten3" : value, __dir__)
  end

  def self.file(relative)
    path = File.join(root, relative)
    raise "Missing ELTEN host source: #{path}. Set ELTEN_HOST_SOURCE to a complete, compatible checkout." unless File.file?(path)
    path
  end
end
