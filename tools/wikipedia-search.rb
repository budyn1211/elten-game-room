# encoding: UTF-8
require "json"
require "net/http"
require "uri"

query = ARGV.join(" ")
uri = URI("https://en.wikipedia.org/w/api.php")
uri.query = URI.encode_www_form(
  "action" => "query",
  "list" => "search",
  "srsearch" => query,
  "srlimit" => "5",
  "format" => "json",
  "formatversion" => "2"
)
request = Net::HTTP::Get.new(uri)
request["User-Agent"] = "ELTEN-Game-Room-Quiz-Factual-Audit/1.0 (https://github.com/papierek1997/elten-game-room)"
response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
puts JSON.pretty_generate(JSON.parse(response.body).dig("query", "search"))
