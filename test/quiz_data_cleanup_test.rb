# encoding: UTF-8
require_relative "../tools/quiz-data-cleanup"
require "json"

def assert(value, message); raise message unless value; end
def question(prompt, correct = "Answer", wrong = %w[One Two Three])
  { "id" => prompt, "category" => "test", "level" => "easy", "prompt" => prompt, "correct" => correct, "wrong" => wrong }
end
data = [
  question("(serial, 2019 — którą postać zagrała ta osoba?"),
  question("Who was in the previous question?"),
  question("Abigail — gdzie mieszkała ta postać?", "Podgrodzie"),
  question("Abigail — w jakiej miejscowości lub lokacji mieszkała ta postać?", "Podgrodzie"),
  question("Abigail — w jakim państwie mieszkała ta postać?", "Temeria"),
  question("Film legend Charlie Chaplin was born in which country?"),
  question("(You're) Having My Baby was sung by whom?"),
  question("What does com mean in http://www.microsoft.com?"),
  question("[https://example.org Actor] — whom did this actor play?", "[https://example.org/role Role]"),
  question("[[Article|Name]] — what is the nickname?", "All of the above"),
  question("Collision after cleaning?", "[[Name]]", ["Name", "Two", "Three"])
]
cleaned, report = QuizDataCleanup.clean(data, source: "pinned-import")
assert(report["rejected"].length == 4, "cleanup dropped a valid question or kept an invalid one")
assert(cleaned.any? { |q| q["correct"] == "Temeria" }, "town and country facts were collapsed")
linked = cleaned.find { |q| q["correct"] == "Role" }
assert(linked["prompt"] == "Actor — whom did this actor play?" && linked["source_links"].length == 2, "wiki text or provenance was lost")
assert(cleaned.any? { |q| q["correct"] == "All of these" }, "shuffled answers still refer to their position")
assert(QuizDataCleanup.clean(data, source: "pinned-import") == [cleaned, report], "cleanup is not reproducible")
puts "Quiz data cleanup passed: context, markup, provenance, duplicate templates and valid counterexamples"
