# encoding: UTF-8
require "json"
require "fileutils"
require "net/http"
require "uri"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_witcher_pl_data")

output_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
questions = GameRoomContent::Pack1f9366a686ccc2dddda06ad6.load.fetch("questions")

def question_subject(question)
  question.fetch("prompt").to_s.split(" — ", 2).first.to_s.strip
end

titles = questions.flat_map do |question|
  [question_subject(question), question.fetch("correct").to_s.strip]
end.reject(&:empty?).uniq.sort

endpoint = URI("https://wiedzmin.fandom.com/api.php")
records = {}

titles.each_slice(40).with_index do |batch, batch_index|
  response = nil
  4.times do |attempt|
    request = Net::HTTP::Post.new(endpoint)
    request["User-Agent"] = "ELTEN-Game-Room-Witcher-medium-audit/218"
    request.set_form_data(
      "action" => "query",
      "format" => "json",
      "formatversion" => "2",
      "redirects" => "1",
      "prop" => "categories",
      "cllimit" => "max",
      "titles" => batch.join("|")
    )
    begin
      response = Net::HTTP.start(
        endpoint.host,
        endpoint.port,
        use_ssl: true,
        open_timeout: 15,
        read_timeout: 30
      ) { |http| http.request(request) }
      break if response.is_a?(Net::HTTPSuccess)
    rescue IOError, SystemCallError, Timeout::Error
      response = nil
    end
    sleep(0.4 * (attempt + 1))
  end
  raise "Witcher Wiki request failed for batch #{batch_index + 1}" if !response.is_a?(Net::HTTPSuccess)

  query = JSON.parse(response.body).fetch("query")
  aliases = {}
  Array(query["normalized"]).each { |row| aliases[row.fetch("from")] = row.fetch("to") }
  Array(query["redirects"]).each { |row| aliases[row.fetch("from")] = row.fetch("to") }
  pages = Array(query["pages"]).to_h { |page| [page.fetch("title"), page] }

  batch.each do |requested|
    resolved = requested
    5.times do
      next_title = aliases[resolved]
      break if next_title == nil || next_title == resolved
      resolved = next_title
    end
    page = pages[resolved]
    page ||= pages.values.find { |candidate| candidate.fetch("title").casecmp?(resolved) }
    records[requested] = {
      "title" => page == nil ? resolved : page.fetch("title"),
      "missing" => page == nil || page.key?("missing"),
      "categories" => page == nil ? [] : Array(page["categories"]).map { |category| category.fetch("title") }.sort
    }
  end

  warn "Fetched #{[batch_index * 40 + batch.length, titles.length].min}/#{titles.length}"
end

payload = {
  "generated" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
  "source" => endpoint.to_s,
  "titles" => records
}
FileUtils.mkdir_p(File.dirname(output_path))
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts output_path
