# encoding: UTF-8
require "cgi"

module QuizDataCleanup
  module_function

  # Preserve visible labels; links remain in the provenance rather than speech.
  def text(value)
    CGI.unescapeHTML(value.to_s)
      .gsub(/\[\[(?:[^\]|]+\|)?([^\]]+)\]\]/, '\\1')
      .gsub(/\[https?:\/\/[^\s\]]+\s+([^\]]+)\]/, '\\1')
      .gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip
  end

  def problem(question)
    prompt = question.fetch("prompt", "")
    return "missing actor/context" if prompt.match?(/\A\(?serial[, )].*—.*ta osoba/i)
    return "depends on another question" if prompt.match?(/\b(?:previous|preceding|last|next|earlier|above|following) (?:question|answer)\b|\b(?:question|answer) (?:number |no\. ?|#)\d/i)
    values = [prompt, question["correct"], *question["wrong"]].map(&:to_s)
    return "unresolved import markup" if values.any? { |v| v.match?(/\[https?:\/\/|\[\[|\]\]|[|]|\{\{|\}\}|\[[^\]]*\z/) }
    return "empty question/answer" if values.any?(&:empty?)
    return "duplicate choices after cleanup" if values.drop(1).map(&:downcase).uniq.length != 4
    nil
  end

  # Only the known equivalent templates, not a fuzzy match that could collapse
  # different facts (e.g. country of residence vs. a town of residence).
  def fact_key(question)
    prompt = question["prompt"].downcase
      .gsub("w jakiej miejscowości lub lokacji mieszkała", "gdzie mieszkała")
      .gsub("jaki przydomek nosiła ta postać", "jak nazywano tę postać")
      .gsub("którym z poniższych przezwisk określano tę postać", "jak nazywano tę postać")
    [question["category"].downcase, prompt, question["correct"].downcase]
  end

  def clean(questions, source: nil)
    kept, rejected, changed, seen = [], [], [], {}
    questions.each do |original|
      question = Marshal.load(Marshal.dump(original))
      %w[category prompt correct].each { |key| question[key] = text(question[key]) }
      question["wrong"] = Array(question["wrong"]).map { |value| text(value) }
      # Options are shuffled: positional descriptions of all choices are invalid.
      ([question["correct"]] + question["wrong"]).each do |value|
        value.gsub!(/\bAll of the above\b/i, "All of these")
        value.gsub!(/\bNone of the above\b/i, "None of these")
      end
      reason = problem(question)
      key = fact_key(question)
      reason ||= "duplicate fact template: #{seen[key]}" if seen.key?(key)
      if reason
        rejected << { "id" => original["id"], "reason" => reason, "prompt" => original["prompt"] }
        next
      end
      changed << original["id"] if question != original
      seen[key] = original["id"]
      if source
        links = [original["prompt"], original["correct"], *original["wrong"]].join(" ").scan(%r{https?://[^\s\]]+}).uniq
        # The import URL is stored once in the pack; stable record IDs identify
        # original rows. Retain explicit article links where the input has them.
        question["source_links"] = links if !links.empty?
      end
      kept << question
    end
    [kept, { "input" => questions.length, "kept" => kept.length, "changed" => changed, "rejected" => rejected }]
  end
end
