# PR #12: Cat, head, tail — przegląd przed integracją

21 września 2026. Sprawdzono [PR #12 autora td-programs](https://github.com/papierek1997/elten-game-room/pull/12),
commit `7930486d9051e557b36d392af558139921fda606`, bazę `fb229556`.
18 zmienionych plików, w tym nowa klasa gry, strategia, zasady PL/EN,
tłumaczenia, pięć nagrań Opus oraz testy. Przegląd wykonano w osobnym
checkoutcie `../work/pr12-review-7930486`; nie łączono PR-a i nie zmieniano
jego kodu produkcyjnego. Nie opublikowano komentarza lub recenzji na GitHubie.

## Wniosek

Gra pasuje do Game Roomu i nie wymaga przebudowy transportu ani nowych tabel.
Nie znalazłem awarii uniemożliwiającej zwykły start lub rozgrywkę w wykonanych
próbach. Przed włączeniem zalecam trzy poprawki poniżej, a następnie uzgodnienie
skrótu D i uzupełnienie pochodzenia nagrań. Nie jest to zapewnienie braku
wszystkich błędów ani zgodności z osobnym, starszym programem autora.

## Potwierdzone problemy

### 1. Zasady nie wyjaśniają samodzielnie gry i mylą utratę punktów

`docs/rulebooks/cat_head_tail.json:13–14`, generowane `games/cat_head_tail.rb:18`.
Opis zakłada znajomość Pig, nie wyjaśnia zwykłych wyników 3–6, działania
zapisu ani rozróżnienia punktów zapisanych i bieżącej tury. Twierdzi,
że jedynka odbiera wszystkie dotychczasowe punkty. Tymczasem kod zeruje
wyłącznie `turn_points`; wcześniej zapisane punkty, również te z dwójek,
pozostają. Sprawdzone: 2, 6, 1 zostawia 2 punkty w banku i kończy turę.

Końcówka opisu nie mówi wyraźnie, że ostatnie okrążenie jest uruchamiane
dopiero po zakończeniu tury z wynikiem co najmniej równym limitowi — brzmi,
jakby partia kończyła się po każdym okrążeniu. Brakuje też opisu ujemnych
punktów, możliwości ich zapisania oraz wyzerowania ujemnej tury jedynką.
Polski tekst zawiera m.in. literówkę „o-pisane” i niejasne określenie liczby
ścian kości jako „oczek”.

Naprawa: zredagować obie wersje zasad na podstawie rzeczywistego modelu,
z krótkim przykładem tury, zapisu i końca gry, bez zmiany reguł w ciemno.
Jeżeli autor zamierzał inaczej rozliczać jedynkę lub limit, wymaga to
osobnego ustalenia, nie automatycznego uznania kodu albo opisu za nadrzędny.

### 2. Bot oddaje szansę wygranej, gdy remis jest już zabezpieczony

`lib/cat_head_tail_strategy.rb:21–24`: w ostatnim okrążeniu zapisuje przy
`banked_total >= leader`, bez rozróżnienia remisu od zwycięstwa.

Odtworzono legalny przypadek przy limicie 2: Alice wyrzuca 2 i kończy turę,
Bob wyrzuca 2. Bob ma już 2 zapisane punkty oraz 0 bieżących, jest ostatni.
Strategia wybiera zapis zera i remis. Tymczasem dalszy rzut jedynką nadal
daje remis; wynik 3 i zapis daje wygraną. Także ujemny ogon, a potem jedynka,
nie odbiera zapisanego remisu. Bot może nie zapisywać wartości ujemnej.

To nie jest zarzut, że odważny ruch czasem się nie udał: w tym stanie można
zachować zabezpieczony remis i otrzymać dodatnią szansę zwycięstwa.
Naprawa: osobno obsłużyć już zabezpieczony remis ostatniego gracza, przewagę
dającą wygraną i remis wymagający dopiero zapisu ryzykowanych punktów.
Nie zamieniać bezrefleksyjnie każdego `>=` na `>`: inne końcówki wymagają
oceny ryzyka. Wystarczy mała reguła i regresja, bez kosztownego planera.

### 3. Brak polskiego podsumowania limitu

`games/cat_head_tail.rb:57–58` używa klucza `to %{limit} points`, którego
nie ma w dostarczonym MO ani źródłach tłumaczeń. Podsumowanie jest używane
przez wspólny nagłówek stołu (`__app.rb:2376–2394` w PR), więc polski
użytkownik dostanie fragment `to 100 points`. Potwierdzono odczyt katalogu
oraz rzeczywistego słownika ELTEN-a, nie tylko brak wpisu w nowym JSON.

Naprawa: dodać polskie tłumaczenie i test podsumowania. Sama nazwa własna
„Cat, head, tail” też pozostaje angielska, ale nie traktuję tego jako błędu
bez decyzji, czy tytuł ma być tłumaczony. Przy integracji skompilować wspólny
aktualny katalog — nie zastępować go starym MO z gałęzi autora.

## Dostosowanie i informacje do uzgodnienia

- D nie odczytuje rzutu; test autora wręcz wymaga braku tego skrótu.
  Dla spójności z naszymi grami kościanymi proponuję go dodać wraz z zapisem
  ostatniego rzucającego/wyniku. To rozszerzenie interfejsu, nie awaria zasad.
- Zasady wskazują autora gry TD Programs. Nie opisano osobno pochodzenia
  pięciu nowych nagrań `cht-*` w informacjach o składnikach zewnętrznych.
  Warto uzyskać informację od autora, czy są własne, czy pochodzą z innego
  źródła i na jakich warunkach można je rozpowszechniać. Brak informacji
  nie dowodzi naruszenia praw; nie przypisuję im zgadywanej licencji.
- Brak limitu czasu na ruch jest jawnym brakiem tej funkcji, nie zepsutym
  zegarem. Wspólne opóźnienie bota jest dostępne. Nie dodawać automatycznego
  zapisu lub rzutu po czasie bez ustalenia takiej zasady.

## Co pasuje i zostało sprawdzone

- Dziedziczenie po Base, rejestracja gry, wspólny interfejs, historia,
  wyniki S w prawidłowej kolejności oraz skróty C i T.
- Ruchy przez action_for i normalne zdarzenia. Wynik ogona zapisany razem
  z ósemką; replay nie losuje go ponownie. Wartości mają najwyżej 7 znaków,
  mieszczą się w istniejącym limicie 64. Brak dodatkowej ścieżki sieciowej.
- Legalne/nelegalne wyniki, dwójka pozostawiająca turę, jedynka zerująca
  bieżące punkty, ujemne punkty i zamknięcie ostatniego okrążenia.
- Koniec partii jest obsługiwany przez wspólną prezentację. Zwracanie wpisu
  wyniku przez describe_event jest zbędne, ale wspólny filtr usuwa powtórkę;
  nie zgłaszam tego jako potwierdzonego podwójnego komunikatu.
- Bot używa publicznych danych, wybiera legalną akcję i nie generuje własnej
  ścieżki zapisu. To tania heurystyka, nie mocny, zweryfikowany planer.
  Nie traktuję samych progów 19–24 ani losowego ryzyka jako dowodu błędu.
- Zapis, lokalne odtworzenie, import dla drugiego klienta i następny ruch
  przeszły te same asercje wspólnego testu zapisu, skierowane tylko na tę grę.
  Wszystko odbyło się na lokalnym brokerze, nie na kontach użytkownika.
- Pięć nagrań to faktycznie Opus, 48 kHz, stereo, nominalne ramki 20 ms,
  zmienne rozmiary pakietów. Same metadane nie potwierdzają docelowych 144 kb/s
  ani complexity enkodera. Nie wykonano odsłuchu ani kolejnego kodowania.
  Nowe pliki przechodzą wspólną kontrolę listy plików wykonawczych.

## Testy i granice

Przeszły skrypty PR-a `cat_head_tail_test`, `game_sounds_test`,
`packaged_rules_encoding_test` oraz celowane wspólne `game_option_encoding_test`,
`rulebook_authoring_test`, `rules_live_help_test`, `saved_game_boundaries_test`.
Dodatkowe dwie próby w `../diagnostics/pr12-review/` sprawdzają opisane
kontrprzykłady, słownik hosta i zapis/odtworzenie nowej gry. Pierwszy start
próby zapisu wymagał poprawienia kolejności inicjalizacji testowego hosta
przed załadowaniem gry; nie był to błąd PR-a ani zmiana asercji.

Nie uruchamiano pełnego runnera, nie rozgrywano setek partii, nie było testu
na żywym serwerze ani nowego instalatora. Kontrola binarna korzystała z
symulacji binarnego wczytywania źródeł. Przejście siedmiu skryptów nie
oznacza pokrycia każdego nowego stanu gry: do testu autora trzeba dopisać
potwierdzoną końcówkę bota oraz polskie podsumowanie.
