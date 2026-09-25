# Indeks narzędzi

Narzędzia nie należą do runtime ani do instalatora. Uruchomienie kompilatora
lub historycznego aplikatora wymaga celu obejmującego zmianę jego wyjść.

## Testy i diagnostyka

- `run-tests.rb`: wspólny runner, osobny proces na skrypt, limit czasu,
  rozróżnienie błędu/pominięcia/timeoutu i opcjonalny raport JSON.
  Podanie ścieżek wybiera tylko te przypadki; `--list` pokazuje wybór bez
  wykonywania testów. Pełny przebieg bez ścieżek tylko po uzgodnieniu.
- `run-five-game-tests.rb`, `run-connection-recovery-tests.rb`,
  `run-quiz-tests.rb`, `run-audit-212-tests.rb`: nazwane wybory tego samego
  runnera. Przyjmują `--timeout`, `--report`, `--allow-skip`, `--list`;
  dawny pojedynczy argument ścieżki raportu pozostaje obsługiwany.
  Zestawy pięciu gier i audytu 212 zachowują `GAME_ROOM_FIVE_GAMES_ONLY=1`
  oraz osobno raportowaną kontrolę `check-five-game-translations.rb`.
- `benchmark-tysiac-bot.rb`, `audit-tysiac-bots.rb`,
  `diagnose-spades-threat-bids.rb`, `search-spades-*.rb`: celowana
  diagnostyka decyzji, nie automatyczna zmiana strategii lub danych.

Źródła hosta wskazuje jeden `ELTEN_HOST_SOURCE`. Brak wymaganej zależności
nie jest sukcesem. Testy korzystają z definicji w `test/support/`, nigdy
z wykonania innego `*_test.rb`. Binarne zestawy również używają wspólnego
runnera: każdy scenariusz ma oddzielny proces z binarnie wczytanym runtime
(lub wskazaną paczką), jawnym językiem i świeżymi atrapami.

## Aktywne generatory i pakowanie

- `translations.rb`, `translation_catalog.rb`, `translation_extractor.rb`,
  `translation_compatibility.rb`, `compile-polish-catalog.rb`: katalogi
  tłumaczeń; zależności w `Gemfile.i18n`.
- `compile-rulebooks.rb`, `build-word-dictionaries.rb`,
  `build-taboo-cards.rb`, `build-quiz-pack.rb`, `quiz-pack-writer.rb`:
  generowanie wskazanych treści. Niskopoziomowy writer quizu jest aktywny,
  nie jest narzędziem do usuwania pytań.
- `encode_audio.rb`, `generate-pong-echo.rb`: uzgodniony format audio.
- `release_files.rb`: jawna lista zawartości stagingu; nie pakuje całego repo.

## Trening

`training/` oraz `train-spades-profiles.rb`, `audit-spades-profiles.rb`
i `audit-spades-training-report.rb`. Kontrakty i użycie opisuje
[training/README.md](training/README.md). Nie dołączać treningu do aplikacji.

## Materiały historycznych audytów

Rodziny `fetch-quiz-*`, `fetch-witcher-*`, `fetch-wikipedia-*`,
`analyze-*`, `finalize-*`, `refine-*`, `recheck-*`, `strict-recheck-*`,
`select-quiz-audit-recheck.rb`, `generate-quiz-factual-audit-report.rb`,
`merge-quiz-pool.rb`, `merge-balteam-polish-audit.rb`,
`compare-balteam-polish-audit.rb`, `restore-english-audit-decisions.rb`
oraz wcześniejsze raportujące audyty dokumentują konkretne etapy redakcyjne.
Nie uruchamiać ich seryjnie jako porządków kodu ani ponownie odsiewać pytań.

`apply-quiz-factual-audit.rb`, `apply-quiz-recovery-audit.rb` i
`import-reviewed-quiz-packs.rb` mają dodatkową granicę zapisu:
domyślnie tylko manifest, zatwierdzone wejścia/cel i ochrona przed cofnięciem
wersji przy `--apply --expect`. Szczegóły:
[MAINTAINABILITY_CLEANUP.md](../docs/MAINTAINABILITY_CLEANUP.md).
