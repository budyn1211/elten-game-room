# Interface-language verification

The implementation is in the `feature/independent-interface-language` worktree,
based on commit `73e9eac0dce895e49f81aca6170925847a12b3ad`.
The existing version/build identifiers were not changed. An unsigned test
installer has now been built and checked. It was not signed or installed, and
no running ELTEN profile was modified.

## Results after the PO-authoring migration

- Focused regression matrix: 58 of 59 scripts passed without skips; syntax checks
  passed for all 149 changed/new Ruby files. The single failure is still the
  unchanged baseline completeness failure described below, not a new regression.
- Pre-PR execution of `ruby tools/run-tests.rb` also covered the Audio Ball lobby
  fixture, which now selects the app's English language explicitly; all 24 real
  option-form cases pass. The full runner then stops at script 35 of 358,
  `test/audit_212_strategy_features_test.rb`, with
  `Farkle must choose any certain winning keep`. The identical assertion fails
  on the untouched `73e9eac` baseline and in PR #13's earlier CI run
  `35865129224`. This is not a full-suite pass; no AI/game-rule changes were made.
- `locale/PL.po` contains 4,521 message entries. Its 19 untranslated entries keep
  the existing runtime fallback; migration did not invent missing translations.
- Independent Python Gettext comparison against the pre-migration MO found no
  changed or missing translation values. Babel also parsed the resulting PO.
  The only normalized raw identity is the redundant singular/plural question
  entry documented in `locale/README.md`.
- Comparing runtime files with the previous installer inventory finds only
  `locale/PL.mo` changed. No game dictionaries, questions, cards, audio, Ruby
  runtime sources or manifests changed during the authoring migration.
- Catalog tests cover 21 cases, including obsolete blocks at any position,
  placeholders, Unicode/backslashes, empty plural variants, atomic writes and
  fault injection. The extractor covers 18 tests and 1,987 assertions.
- End-to-end CLI tests cover editing real PO entries followed by update, compile,
  check and both old compiler entry points. Poisoned generated JSONs cannot
  override the authoritative PO, and truncated mirrors can be regenerated.
- New Czech, German, Japanese and Arabic drafts compile with their standard
  plural defaults. These were temporary fixtures, not supplied translations.
- `ruby tools/translations.rb check PL` passes without changing any file. A full
  rule generation, PO update and compile cycle was also byte-for-byte idempotent.
- Independent review identified and reproduced three edge-case defects, then a
  separate implementation context fixed them with RED-to-GREEN tests. Final
  independent re-review passed with no security or logic findings. Additional
  injected write, flush and fsync failures preserved PO bytes and unrelated files.
- The extractor still warns about a dynamic regional-board label in
  `content/monopoly_boards.rb`; existing catalog entries are retained, not deleted.
- No replacement installer was built for this authoring-only migration. The
  unsigned installer section below documents the earlier language-selection build.

Repeat the authoring checks after installing the tooling:

```text
bundle install --gemfile tools/Gemfile.i18n
ruby tools/translations.rb check PL
ruby test/translation_catalog_test.rb
ruby test/translation_extractor_test.rb
ruby test/translation_compatibility_test.rb
ruby test/translation_workflow_test.rb
ruby test/translation_authority_test.rb
ruby test/translation_legacy_entrypoints_test.rb
ruby test/rulebook_source_generation_test.rb
```

## Results after the fallback-order correction

- Focused source regression matrix: 50 of 51 scripts passed; no skips.
- The one failing script, `test/release_2_localization_test.rb`, fails identically
  on the untouched base checkout. Its existing missing Polish messages are
  `%{player}: %{positions}.` and
  `Daily Krowa requires a private table. Create a new private table for this variant.`
  The assertion and missing translations were not hidden or rewritten.
- Syntax: all 134 changed/new Ruby files passed `ruby -c`.
- Actual-host integration: 7 of 7 scenarios and 256 assertions passed, with
  `ELTEN_HOST_SOURCE` explicitly supplied. It extracts the actual RuntimeBackend
  and loads the real host dictionary plus binary Game Room sources in isolated
  namespaces. This is not a live GUI or NVDA test.
- Both host PL/app EN and host EN/app PL pass, including load-time menu constants,
  rules, contextual CatHeadTail messages, real Quiz plurals, content labels,
  widget labels and deferred F1 callbacks with no current runtime.
- A synthetic incomplete Czech MO works without Czech host resources. With known
  languages cs/en/pl, missing Czech entries use Polish before English source;
  unknown languages are ignored. Explicit primary English remains English.
- UI and save tests verify primary-before-known Tab order, native required
  selection, Save/Cancel, stable codes, unchanged unrelated settings and the
  restart notice. Existing widget/preset and Pong settings checks pass.
- Catalog validation covers byte order, bounds, UTF-8, empty entries, malformed
  plural expressions and short-circuiting. No catalog expression is evaluated
  as Ruby code.
- Every production translation-helper call passes the lexical-scope AST check.
- Polish catalog compilation is idempotent and preserves every old entry.
- Release dependency preflight includes both new runtime files and the MO;
  352 required runtime/license files were checked. The installer result is below.
- Independent review identified the English-fallback ordering defect, which was
  reproduced by new unit and actual-host regression tests before correction.
  A separate fix context applied the one-line correction. Final independent
  re-review passed with no security or logic findings; its additional precedence,
  plural, context and missing-translation matrix passed all 36 checks.
- `git diff --check` passes. The original Game Room checkout and host checkout
  remain clean.

## Repeating key checks

Set `ELTEN_HOST_SOURCE` to an ELTEN 3 source checkout, then run:

```text
ruby test/game_room_localization_test.rb
ruby test/game_room_catalog_validation_test.rb
ruby test/game_room_language_runtime_test.rb
ruby test/game_room_language_settings_test.rb
ruby test/game_room_language_save_test.rb
ruby test/game_room_translation_scope_test.rb
ruby test/game_room_language_pack_writer_test.rb
ruby test/game_rules_translation_test.rb
ruby test/game_option_encoding_test.rb
ruby test/axel_pong_settings_test.rb
ruby test/widget_presets_test.rb
ruby test/widget_inline_presets_test.rb
```

A SKIP is not a successful actual-host verification. The focused matrix is not
a full historical game/bot suite; the full-runner attempt above stops at a baseline failure. The
package-boundary tests prevent missing production code or MO records from being
read from the checkout and have also passed with the actual test installer.

## Unsigned test installer

`ELTEN-Game-Room-interface-languages-unsigned.eltsetup` is in the workspace's
`Game Room/Paczki` directory. It retains version 2.0.2.5 and build 236.
The host builder was explicitly given `--unsigned`; no signing was performed.

- Size: 23,302,025 bytes.
- SHA-256: `60f1d9d6ae1c35c764d89a69ba8d8dcedd93c2f1c1f274af551a9cbbb321e938`.
- Every source/staging/package file matches: 341 runtime records (206 Ruby,
  134 audio, one MO), plus 11 loose files. No duplicates, omissions, extra
  development files or changed manifests were found.
- `release_binary_loading_test.rb` and `game_option_encoding_test.rb` passed
  with this installer as their package argument.
- Language settings and Save/Cancel tests also passed after loading production
  code from this installer through `packaged_rules_encoding_test.rb`.
- This package requires developer-mode ELTEN. No installation, client restart,
  signing, server publication or GitHub operation was performed.

The detailed package hash inventory is stored outside the repository in
`Game Room/Materiały/interface-languages-20260923-171739/PACKAGE.json`.
