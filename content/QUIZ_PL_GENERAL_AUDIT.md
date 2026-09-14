# Polish general quiz content audit

## Scope

This audit covers every question in the current Polish Wikidata general-knowledge pack on the `fix/quiz-polish-content-audit` branch before the audit changes:

- 15,428 questions in total.
- 3,050 chemistry questions.
- 3,101 geography questions.
- 3,001 sport questions.
- 3,071 faith and religion questions.
- 3,205 history questions.
- 284 generation schemas and 61 separately curated sport records reviewed for question-to-property semantics, answer type, temporal wording, and option granularity.

The separate Witcher pack is not part of this file or this audit.

## Verification performed

- 13,237 direct item-property questions were checked against current non-deprecated Wikidata claims, including Polish and English labels and aliases.
- 1,651 date questions were checked against current Wikidata time values and their precision.
- Every four-option set was checked for duplicates and lexical containment, such as a general term being offered beside its more specific form.
- Schema-level checks covered property misuse, singular wording for unsafe multi-valued relations, present-tense claims without time qualifiers, mixed answer classes, city-versus-region mismatches, overlapping continent models, and relations that did not prove what the prompt asserted.
- High-risk sport findings were checked separately against current Wikidata claims and the external sources listed in `QUIZ_PL_SPORT_SOURCES.txt`.
- Questions backed only by an unsafe or insufficiently precise interpretation were removed instead of being rewritten speculatively.

## Result

- 4,489 questions removed.
- 602 questions edited.
- 10,939 questions retained.

| Category | Before | Removed | After |
|---|---:|---:|---:|
| Chemistry | 3,050 | 814 | 2,236 |
| Geography | 3,101 | 752 | 2,349 |
| Sport | 3,001 | 684 | 2,317 |
| Faith and religion | 3,071 | 1,184 | 1,887 |
| History | 3,205 | 1,055 | 2,150 |

The complete removal list, original options, reason codes, and available evidence URLs are in `QUIZ_PL_GENERAL_REMOVALS.json`. The 602 complete replacements are in `QUIZ_PL_GENERAL_EDITS.json`. `QUIZ_PL_GENERAL_AUDIT_LEDGER.json` records all 284 generation schemas, all 15,428 question-to-source assignments, all 61 curated records, all 13,237 direct-relation checks, and all 1,651 date checks.

## Important reviewed examples

- The Eighty Years' War ending in 1648 is correct and was retained. It is not a mistaken reference to the Thirty Years' War: both conflicts ended in 1648. Encyclopaedia Britannica dates the Eighty Years' War to 1568–1648 and states that Spain recognized Dutch independence in the separate peace of 1648: https://www.britannica.com/event/Eighty-Years-War
- Questions that treated Wikidata property P802 as proving a doctoral relationship were removed. P802 means notable student, not doctoral student: https://www.wikidata.org/wiki/Property:P802
- Building questions that treated P571 as a construction-completion date were removed when no stronger evidence was available. P571 is inception; Wikidata explicitly directs official-opening dates to P1619: https://www.wikidata.org/wiki/Property:P571
- William G. Morgan was removed from a generated volleyball-player schema. The International Volleyball Hall of Fame identifies him as volleyball's inventor and confirms that he was born in Lockport, New York: https://volleyhall.org/william-morgan-father-of-volleyball.html
- The incorrect Spain answer for Achraf Hakimi was corrected to Morocco. Supporting source: https://www.theguardian.com/football/2022/dec/05/achraf-hakimi-morocco-spain-world-cup-2022-qatar

## Reproducibility notes

- Wikidata verification snapshot: 2026-09-13.
- Wikidata data is licensed CC0.
- The exact audited pack is reconstructed from pinned base revision `2e043a8e0cf5b68df0799a5ffc4a1bb791b24a25`, the removal manifest, and the edit manifest with `ruby tools/rebuild-audited-polish-quiz.rb`.
- Run `ruby tools/rebuild-audited-polish-quiz.rb --check` to verify the generated data, checksum, counts, schema ledger, direct-relation ledger, and date ledger without rewriting files.
- The loader checksum is regenerated whenever the pack is rebuilt.
