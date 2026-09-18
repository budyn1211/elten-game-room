# Game Room 2.0.1 — build 229

Wydanie przygotowywane na polecenie użytkownika z 18 września 2026.
Obejmuje ukończone poprawki opisane w `POST_228_IMPLEMENTATION.md` oraz
redakcję zasad opisaną w `RULES_REWRITE_REVIEW.md`. Nie zmienia zasad
punktacji, protokołu stołów, baz pytań ani schematu serwera.

Changelog użytkownika znajduje się w `CHANGELOG_2_0_1.md` i w aplikacji.
Pierwsza paczka miała 11 nowych punktów w PL/EN pod jednym nagłówkiem.
Na kolejne polecenie przebudowania zachowano je i dopisano trzy poprawki:
wspólny formularz prywatności, nowe gry domyślnie we widgecie oraz dźwięki
Domino/Mexican Train — łącznie 14 punktów. Szczegóły: `DOMINO_SOUNDS_229.md`.
Wcześniejsze changelogi zachowano. Oba manifesty i stałe runtime wskazują
2.0.1/229; wymagane API pozostaje 3.0.3, autor — papierek.

## Kontrola wydania

Przed podpisaniem wykonywane są testy celowane zasad, pomocy, sortowania,
powiadomień, języków, dźwięków oraz changelogu. Sprawdzane są składnia
zmienionych Ruby, powtórna kompilacja zasad i katalogu oraz spójność zmian.
Nie uruchamiać pełnego zestawu testów tylko na potrzeby tego wydania.

Gotowa paczka wymaga niezależnego sprawdzenia podpisu autora, zgodności
każdego zapakowanego pliku ze źródłem, obu manifestów i stałych runtime,
dźwięków, zachowanych historycznych changelogów i nowego tłumaczenia.
Testy binarnego ładowania należy uruchomić z rzeczywistą ścieżką paczki,
również ze słownikiem i kontrolką checkbox ELTEN-a oraz PL/EN/fallback.

Wyniki pierwszego wydania zachowano w `diagnostics/release-2-0-1/`.
Ponowne pakowanie zapisuje wyniki poza repozytorium, w katalogu
roboczym `diagnostics/release-2-0-1-refresh/`: `SOURCE.json` zawiera kontrole źródeł,
`PACKAGE.json` — wynik gotowej paczki, rozmiar i SHA-256. Ten dokument
opisuje wymagany zakres, a nie zastępuje wyników tych kontroli.

## Granice polecenia

Paczka trafia do `artifacts/game-room/testing/ELTEN-Game-Room-build-229-signed.eltsetup`.
Podpisana 228 ma pozostać bez zmian, a pierwsza 229 zachowana osobno.
Nie instalować ani nie publikować
wydania, nie wysyłać zmian na GitHub i nie modyfikować serwera. Testy
automatyczne nie zastępują sprawdzenia na dwóch rzeczywistych klientach.
