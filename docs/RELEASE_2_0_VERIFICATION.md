# Game Room 2.0/build 227 — weryfikacja źródeł

17 września 2026. Trzy ostatnie plany wdrożone, cztery wcześniejsze
niewydane plany zachowane. Bez instalacji i publikacji.
Wyniki pierwszego etapu: `IMPLEMENTATION_2_0_VERIFICATION.md`.

## Scrabble

Jedna gra dla 2–4 ludzi, bez botów. Język pierwszy w ustawieniach stołu,
niezależny od UI; przy jednym słowniku brak dodatkowej listy zestawu.

| Punkt | Wdrożenie i kontrola |
|---|---|
| Dane PL/EN | SJP 2026-09-01 (CC BY 4.0), 3 244 813 słów; Wordnik 2021-07-29 (MIT), 194 152. NFC, 2–15 liter, polskie znaki zachowane; osobne rozkłady po 100 płytek z dwoma blankami. |
| Ładowanie | Wersja i checksum w opcjach partii, leniwe zestawy, skompresowane bloki, binarne wyszukiwanie i cache 16 bloków. Bez sieci podczas sprawdzania słów. |
| Legalność | H8, jeden wiersz/kolumna, bez luk, połączenie z planszą także równoległe; wszystkie powstałe wyrazy, nie tylko główny. |
| Punkty | Premie tylko nowych pól, prawidłowe mnożniki, blank 0, +50 za siedem nowych płytek. Legalne 0 punktów nie jest pasem. |
| UI | A1–O15, prywatny szkic, H/V/N, Shift+litera/AltGr, cyfry/Shift+cyfry, Enter/Delete/Backspace/Z/F/G/P/C/I/Y/L/E/S/T. Bez przerabiania zwykłych rąk kart. |
| Błędne słowo | Sześć reakcji: pozostawienie/koniec tury, 0/5/10 kary. Raz za próbę, bez karania geometrii, bez resetu zegara. Podgląd nie sprawdza słownika. |
| Wymiana/blokada | Wymiana od 8 w woreczku, zwrot przed losowaniem. Trzy pełne obiegi bez postawienia kończą grę tylko bez możliwości wymiany. |
| Koniec | Odjęcie pozostałych liter; premia opróżniającego stojak tylko przy pustym woreczku. Najwyższy skorygowany wynik, remis wspólny. |
| Czas/zapis | 0 lub 20–600 s; timeout oddaje turę bez kary/dobierania. Modalny wybór nie zatrzymuje terminu. Zapis bez lokalnego szkicu. |
| Replay | Krótkie fragmenty atomowej akcji, rewizje, deterministyczne rozdanie, powtórzenie nie dubluje próby. |

Testy: scrabble_test, scrabble_surface_test, game_option_form_test,
packaged_rules_encoding_test. Binarna kontrola obejmuje oba słowniki,
żółw/qi, polski AltGr, sortowanie stojaka i układanie słowa.
Licencje i źródła: `content/WORD_DICTIONARIES_NOTICE.md`.
To nie OSPS/NWL/Collins/QC. Nie wykonano niezależnej oceny językowej
każdego słowa; użyto gotowych list z kontrolą struktury i próbek.

## Taboo

4/6/8 ludzi, dwie równe drużyny przez wspólny formularz, brak botów.
Po 500 kart PL/EN z pięcioma zakazami, trwałymi ID i checksumami.

| Punkt | Wdrożenie i kontrola |
|---|---|
| Rozmowa | Zewnętrzna konferencja/komunikator/słuchawki, bez mikrofonu, nagrywania i automatycznej oceny mowy. |
| Role | Karta dla opisującego i przeciwników; zgadujący/obserwatorzy nie widzą jej w UI, skrótach, pomocy ani bieżącej historii. |
| Tura | Enter, trzysekundowe przygotowanie, 30–300 s, Enter/P/B. Token karty odrzuca spóźnione zgłoszenie do poprzedniej odsłony. |
| Punkty | Odgadnięcie +1 własnej drużyny; pominięcie/naruszenie +1 przeciwnika; timeout karty neutralny. |
| Moderacja | Korekty i zatwierdzenie każdej tury przez mastera, techniczne powtórzenie bez punktów. Master może obserwować; pierwszy gracz nie zyskuje jego uprawnień. |
| Rotacja | Równe liczby tur i zmiana opisującego; dogrywka zawsze po jednej turze każdej drużyny. |
| UI | Lista sześciu wierszy; stabilny formularz, bez powtórki karty przy zwykłym odświeżeniu; C/1–6 uprawnieni, R/S/T wspólne. |
| Dźwięki | shuffle/replay/skip/buzzer2/ding dla startu/odgadnięcia/pominięcia/naruszenia/timeoutu, finał win2/lose3 dla drużyn. Bez tykania i dublowania sygnałów nowych kart. |
| Zapis | Między zatwierdzonymi turami, nie w czasie opisywania/sporu; deterministyczna talia, brak natychmiastowej powtórki przy przetasowaniu. |

Testy: taboo_test, taboo_surface_test, taboo_network_test, game_sounds_test
i wczytanie binarne. Test modelu pięciu klientów obejmuje czterech graczy
i obserwującego moderatora, fałszywe zatwierdzenie przez pierwszego gracza,
korektę i identyczność replayów.

Karty zredagowano po porównaniu konstrukcji z otwartymi przykładami tabooo;
nie skopiowano talii komercyjnej ani całej bazy.
Szczegóły: `content/TABOO_CONTENT_NOTICE.md`. Nie przeprowadzono próbnych
tur głosowych z ludźmi ani nie potwierdzono równej trudności każdej karty.
Ukrycie treści dotyczy zwykłego UI, nie klienta zmodyfikowanego do analizy
wspólnego stanu i lokalnego banku kart.

## Siedem poprawek

1. D: Yahtzee i Chińczyk; Farkle zachowany, Monopoly bez zmian.
2. V/Shift+V: własna/cudza karta Yahtzee, wybór przeciwnika; nieuzupełnione
   pola odróżnione od zera, właściwe kategorie, premie i wyniki; tylko podgląd.
3. Alfabetyczna kolejność lokalizowanych nazw, z polskimi literami.
   Osobny test nazw wczytanych jako ASCII-8BIT przez hosta.
4. Nazwa 99 bez zmiany ID `ninety_nine` i zapisów.
5. Farkle: reguła PR #6 dawidpiepera, commit
   `5cbec01d85e797901d8ebb9504afaa3f935164b7`, zaadaptowana lokalnie,
   bez scalenia na GitHubie. Dokończenie bieżącego obiegu, najwyższy
   wynik/remis. Bot ocenia lidera i pozostałe tury, nie ryzykuje pewnego
   ostatniego zwycięstwa ani nie odkłada pewnej przegranej. Budżet/głębokość
   nie zwiększone. Stare archiwa bez wersji reguły zachowują wersję 1,
   nowy start otrzymuje 2.
6. Ctrl+X: master, poza aktywną partią; obecne wartości, walidacja opcji
   i składu, anulowanie bez zapisu. Można przygotować opcje przed zebraniem
   minimum ludzi. Powtórna kontrola i porównanie w uporządkowanej historii
   chronią przed konkurencyjnymi formularzami/startem nowej gry.
   Jeden rekord zawiera zmianę i jej historię. W czacie nadal wycinanie.
7. Ctrl+Q: potwierdzenie i kontrola mastera/ID, trwała granica bez
   fikcyjnego wyniku. Późne ruchy, boty i timeouty nie wchodzą do replaya;
   ponowienie po utracie odpowiedzi nie dubluje końca. Unfreeze ani reconnect
   nie przywracają przerwanej partii. Kolejny start ma odrębne ID/opcje.

Pokój, LiveSession, uczestnicy, boty, role, prywatność i czat pozostają.
Nie ma nowego ogłoszenia stołu ani Ctrl+Shift+X. Nowe pokoje mają discovery
protocol 4, nieobsługiwany przez stare klienty. W dawnym pokoju nowe
polecenia ukryte; nowy start wymaga nowego stołu. Zachowano archiwa.

Testy: release_2_shortcuts_test, farkle_final_round_test,
table_lifecycle_controls_2_test, stare testy Farkle i wspólnych mechanizmów.
Scenariusz Ctrl+Q obejmuje utratę odpowiedzi po zapisie, ponowienie, spóźniony
pakiet, stary status, reconnect, zmianę opcji i nowy start. Nie odtworzono
osobno każdej fazy każdej gry w żywym interfejsie.

## Wyniki i ograniczenia

- 48 wybranych skryptów przeszło; bez pełnego runnera.
- Składnia 98 nowych/zmienionych Ruby i git diff --check poprawne.
- Zgodne manifesty: 2.0/227, papierek, API 3.0.3.
- 2700 skompilowanych tłumaczeń PL, zasady i jeden changelog PL/EN.
- Binarne wczytanie: 22 gry, nowe zestawy, istniejące Quiz/Monopoly,
  zaproszenia i pomoc. Sprawdzenie gotowej paczki to osobny krok.
- Zachowano poprzednie cztery plany i ponowiono wybrane testy. Ich
  wcześniejsza mała próba serwerowa jest opisana w osobnym raporcie.
  W tym etapie nie dokonywano nowych zmian serwera.
- Nie rozegrano nowych gier na rzeczywistych klientach, nie wykonano
  setek symulacji ani pełnego audytu wszystkich wcześniejszych gier.
- Chmura zapisów, Ctrl+Shift+X, źródła ELTEN-a, instalacja i publikacja
  poza zakresem.

Logi poza repo: `diagnostics/release-2-0/TESTS.json`, `SOURCE.json`.
Po zbudowaniu podpis, liczby plików, binarny odczyt i hash gotowej paczki
zapisywane są tam w `PACKAGE.json` i `README.md`, nie wewnątrz paczki.
Changelog: [CHANGELOG_2_0.md](CHANGELOG_2_0.md).
