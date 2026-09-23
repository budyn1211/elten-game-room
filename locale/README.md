# Translation files

**Edit one PO file per target interface language.**

- `PL.po`: the complete editable Polish interface catalog.
- `game-room.pot`: generated English-message template for a new language.
- `<LANG>.mo`: generated runtime catalog; do not edit it by hand.
- `*-pl.json`: generated legacy compatibility views, not translation sources.
  Their Polish values come only from `PL.po`.
- `catalog-contexts.json`: retained legacy context metadata, not a translation
  file. The compatibility exporter uses the English-only layout under `tools/`.

English is the original source language. There is no editable `EN.po` or required
`EN.mo`: an explicit English interface uses the original English messages.

The catalog covers menu labels, announcements, rules/help and the in-app
changelog. It does **not** contain Scrabble/Krowa word lists, quiz questions,
Taboo cards, alphabets, game identifiers, board data or audio recordings. Those
remain independent gameplay resources and keep their own language/version/checksum.

## Editing a translation

Open the language's PO file in Poedit or another Gettext-compatible editor. Edit
`msgstr` translations, not English `msgid`, `msgctxt` or source references.
Preserve placeholders such as `%{player}`, `%{count}` and `%{score}` exactly.
Fill all required plural variants. An empty translation is allowed and uses the
runtime fallback. Fuzzy/unreviewed and obsolete entries are not compiled.

Do not manually update the old JSON fragments or `pl` fields in
`docs/rulebooks/*.json`: they are generated views of the same PO. Their English
text and rule structure remain developer inputs. Polish changelog documents are
also refreshed from the PO. This compatibility layer preserves existing consumers
without creating a second editable Polish translation source.

## Developer commands

Use Ruby 4.0. Translation tooling uses the standard Ruby GetText gem, like ELTEN's
POT generator, plus Ruby's Prism parser for correct Ruby string extraction.
These are build-time tools only; the installed Game Room gains no new dependency.

Install the tooling once:

```text
bundle install --gemfile tools/Gemfile.i18n
```

After changing English source messages or the English rule structure:

```text
ruby tools/compile-rulebooks.rb
ruby tools/translations.rb update
```

`update` refreshes source references, adds new empty entries and writes the POT.
It preserves existing translations and historical/dynamic entries; it does not
automatically delete messages missing from static extraction.

After editing a PO, validate and compile it:

```text
ruby tools/translations.rb compile PL
ruby tools/translations.rb check PL
```

The first command regenerates MO and the Polish compatibility views. The second
is read-only and fails if generated files are stale. Neither command edits PO.
Without a language argument, compilation/check processes all PO files.

`ruby tools/compile-polish-catalog.rb` remains a compatibility shortcut for PO
compilation. Passing old JSON filenames is deliberately rejected, so an old
command cannot overwrite a translator's changes.

## Another language

Create a draft from the generated template:

```text
ruby tools/translations.rb new CS --name "čeština"
```

This creates only `CS.po`; it does not create a runtime catalog or change the
installed program. Translate it, then run `compile CS` and `check CS`. A complete
translation can then be declared in both manifests and packaged with `CS.mo`.
The existing package format uses two-letter language codes. A Czech catalog does
not require a Czech version of ELTEN. Initialization uses the checked-in Gettext
plural defaults in `tools/plural_forms.json` (Babel data, license in
`tools/licenses/Babel.txt`), so it does not download CLDR data or need Python.
For a language without a preset, `new` accepts explicit `--plural-forms` metadata;
the compiler validates the expression before using it.

## Migration and generated-file safety

The initial Polish PO is recovered from the complete MO, not just the JSON
fragments. This retains older messages with no JSON source, as well as contexts
and all plural forms. One redundant singular MO record has the same text as its
plural entry's first form; the standard PO stores those forms as a single plural
entry without changing runtime wording.

`import-mo PL` is an explicit one-time recovery command. It refuses to overwrite
an existing PO. Normal compilation reads only PO, never an old MO or legacy
Polish JSON values. `tools/translation_layout.json` describes compatibility file
membership using English message IDs; it contains no Polish translations.
