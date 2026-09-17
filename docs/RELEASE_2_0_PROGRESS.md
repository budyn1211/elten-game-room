# Wydanie 2.0 — punkt wznowienia

17 września 2026. Użytkownik zlecił implementację trzech planów i podpisaną
paczkę 2.0. Nie zlecił instalacji ani publikacji. Baza wydana: 1.1.10/226;
wcześniejsze cztery plany lokalne opisuje IMPLEMENTATION_2_0_VERIFICATION.md.

## Kolejność i kontrola

- [x] Scrabble: wersjonowane słowniki PL/EN, pochodzenie/licencje i rozkłady liter.
- [x] Scrabble: reguły, punktacja, warianty błędów, zegar, replay i zapis.
- [x] Scrabble: plansza, stojak, prywatny szkic, wszystkie uzgodnione skróty.
- [x] Taboo: po 500 zredagowanych kart PL/EN, pochodzenie i licencje.
- [x] Taboo: role, drużyny, zegar, wyniki, korekty, dogrywka i zapis.
- [x] Taboo: powierzchnia, skróty, ochrona odczytu kart i dźwięki.
- [x] Poprawki 1–4: odczyt kości, karty Yahtzee, sortowanie gier, nazwa 99.
- [x] Poprawka 5: Farkle PR #6, strategia botów, zgodność zapisów.
- [x] Poprawki 6–7: Ctrl+X ustawienia i Ctrl+Q trwałe przerwanie partii.
- [x] Zasady, dynamiczna pomoc i tłumaczenia PL/EN.
- [x] Celowane testy i kontrola punkt po punkcie wszystkich trzech planów.
- [x] Wersja 2.0/build 227, changelog wspólny dla niewydanych zmian.

## Stan

Źródła wszystkich siedmiu planów gotowe. Raport punkt po punkcie:
`RELEASE_2_0_VERIFICATION.md`; changelog: `CHANGELOG_2_0.md`.
48 celowanych skryptów i składnia 98 Ruby przeszły. Nie uruchomiono pełnego
runnera ani nie rozegrano nowych gier na rzeczywistych klientach.

Podpis i zawartość gotowego artefaktu są sprawdzane osobno po zbudowaniu.
Wynik, rozmiar i SHA-256 trafią do `diagnostics/release-2-0/PACKAGE.json`
i `README.md` obok repo, nie do wnętrza paczki. Plik docelowy:
`artifacts/game-room/testing/ELTEN-Game-Room-build-227-signed.eltsetup`.
Stan końcowy wydania jest też zapisywany w nadrzędnym AGENTS.md.
Nie instalować ani nie publikować bez osobnego polecenia.
