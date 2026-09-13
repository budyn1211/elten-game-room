# Witcher question sets — data version 2

## Result

The Polish Quiz Party catalogue offers three Witcher sets after selecting the
language:

- `Wiedźmin`: all 6,571 questions;
- `Wiedźmin — gry`: 3,292 questions;
- `Wiedźmin — książki i ekranizacje`: 3,279 questions, comprising 3,154 book
  questions and 125 screen-adaptation questions.

Every source ID occurs once in exactly one detailed set. The full set uses the
same reviewed prompt as its detailed counterpart. Question answers, wrong
answers, difficulty and thematic category are unchanged.

## Review method

All 6,571 records passed through the same review, including records marked as
medium or high confidence in the supplied preliminary map. Explicit wording in
the question wins first. The next evidence is the medium of the subject and of
the concrete answer in Wiedźmin Wiki categories captured on 13 September 2026.
For a shared subject, a relationship question can be resolved by the medium of
the related answer. The preliminary map is used only when it agrees with source
metadata or when no stronger source category is available.

The audit checked 3,971 unique subject/answer labels through the Wiki API.
2,922 resolved to pages with categories; 1,049 labels were missing, often
because they are generic answer values rather than article titles. The review
changed 2,351 assignments relative to the supplied map. Every decision and its
basis is recorded; no question is left unclassified.

Questions that did not already name their medium received a natural phrase in
the question, such as `w grach z serii Wiedźmin`, `w książkach z cyklu
Wiedźmin` or `w ekranizacjach Wiedźmina`. This affects 5,810 prompts. Four
obviously damaged performer labels in prompt text were cleaned, including the
truncated serial-dubbing label; IDs and answers were preserved.

This review establishes the division and removes ambiguity from the wording.
It is not a claim that all 6,571 correct answers and distractors received an
independent factual verification.

## Runtime design

`content/quiz_witcher_pl_data.rb` remains the only full question database.
`content/quiz_witcher_pl_medium_data.rb` stores the compact reviewed medium map
and prompt replacements. `content/quiz_witcher_pl_sets.rb` materializes only
the set selected by the table. Registration does not parse either large data
resource, and every pack verifies its own version-2 checksum after lazy load.

## Audit files

The complete external report is in `diagnostics/witcher-medium-audit-218`:

- `ALL_DECISIONS.json`: one decision for every ID;
- `CHANGES_FROM_SUPPLIED_MAP.json`: all 2,351 changed classifications;
- `SUMMARY.json`: totals and decision bases;
- `WIKI_PAGES.json`: captured source categories;
- `witcher-medium-data.json`: compact generated runtime input.

The generators are `tools/fetch-witcher-wiki-metadata.rb` and
`tools/audit-witcher-medium-split.rb`.
