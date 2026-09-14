# Quiz Party factual and language audit after build 219

This change reviews every question that existed in the three source databases
before the audit: English general knowledge, Polish general knowledge and the
Polish Witcher database. It does not add a new transport, game rule or user
interface. It changes only quiz content, registrations, checksums, data versions,
documentation and targeted tests.

## Decision rule

Every original stable question ID receives exactly one decision: keep, correct
or remove. A retained question must have recorded evidence for its stated answer.
If the available checks do not confirm the answer, the question is removed. A
correction is made only when the evidence supports a precise replacement; IDs
are never regenerated for edited records.

The review also rejects unsafe question construction even when answer words can
be found on a source page. This includes using a source property for a stronger
claim than it represents, asking for one answer when several live values exist,
offering overlapping answers, relying on a mutable present-day fact without a
date and treating the occurrence of words as proof of a negative assertion.
Mixed-looking answer types are reported for inspection, but are not rejected by
shape alone because legitimate quantities can be written as digits, ranges or
phrases.

## Polish general database and Balteam's audit

Balteam's independent audit at commit
`9be74abfa6968270bfc04312833767bd83833ac3` is compared with the local audit by
the original question ID. It is not merged as an opaque replacement. Its
schema-aware removal and edit manifests are checked against the exact 15,428-ID
source, and the stable local IDs and existing per-question provenance are kept.

Where Balteam identified an unsafe relation or answer set that local text search
could not detect, the schema result wins. Where local search failed to match a
fact but Balteam's structured check proves the exact Wikidata relation, the
question is retained. The comparison counts and both decisions are recorded in
the diagnostics report.

## Witcher database

The concrete fact and its medium are checked together. A character existing in
several media does not determine the set: a game-only residence or event belongs
to the games view, while a book fact belongs to books and screen adaptations.
Questions whose fact or medium remains unsupported are removed. The full set and
the two detailed views still use one shared source and an ID-to-medium map.

## Evidence and reproducibility

The audit records Wikidata items and statements, timestamped Wikipedia search
excerpts and available article revisions, Polish Witcher Wiki article revisions
and the pinned independent audit revision.
The generated `diagnostics/quiz-factual-audit-220/ALL_DECISIONS.json` contains one
row per original question. `REMOVED.json` and `CORRECTED.json` provide filtered
views, while `REPORT.md` gives final counts.

Targeted tests verify decision coverage, stable IDs, unique answer options, exact
agreement between retained decisions and runtime data, data checksums, lazy pack
loading, the disjoint Witcher views, Polish set names, match start and replay.

## Final result

| Source pack | Before | Retained | Corrected | Removed |
| --- | ---: | ---: | ---: | ---: |
| English general | 28,575 | 13,836 | 148 | 14,739 |
| Polish general | 15,428 | 10,939 | 1,337 | 4,489 |
| Witcher | 6,571 | 5,069 | 4,366 | 1,502 |

The retained Witcher source is partitioned into 2,654 game questions and 2,415
book/screen questions. All 32 targeted Quiz Party and integration tests pass.
No live client was used for this audit. The audited data were subsequently
included in the signed version 1.1.8, build 220 package; that package was not
installed or published as part of the audit.
