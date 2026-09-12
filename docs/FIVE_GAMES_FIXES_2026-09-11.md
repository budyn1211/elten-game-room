# Poprawki pięciu gier po audycie buildu 206

Stan: poprawki przygotowane do testowego wydania 1.1.6/build 207, wraz
z regionalnymi planszami Monopoly. Paczka 206 nie zawiera tych poprawek.
Nie zmieniano transportu ani tabel. Publikacja i instalacja pozostają
oddzielnymi czynnościami, niewchodzącymi w przygotowanie paczki testowej.

## Naprawione przypadki

Wszystkie 28 odtworzonych przypadków poprzedniego audytu mają teraz przechodzące
testy regresji w `test/five_games_regression_test.rb`.

- UNO: zwykła szóstka nie jest karą; deklaracja po przedostatniej karcie jest
  dostępna również poza kolejką. Przyłapanie wskazuje konkretnego gracza i nie
  pozwala złapać siebie. Ruletka dobiera także po przetasowaniu. Eliminacja
  resetuje licznik dobrań i czas następnej osoby, a anulowanie ostatniej kary
  domyka oczekujące rozdanie. Wild +6 nie uruchamia reguł zwykłej szóstki.
- Poker: ante nie jest zakładem bieżącej ulicy; A2345 jest stritem. All-in
  respektuje strukturę i limit podbić. Krótkie all-in nie otwiera ponownie
  podbijania, dopóki skumulowany wzrost nie osiągnie pełnego minimum.
  Wymiana porównuje zbiory kart, odzyskuje dostępne odrzuty przy braku talii
  i nie pomija osoby all-in. Nie oddaje graczowi jego właśnie odrzuconych kart.
- Yahtzee: lista uczestników pokazuje bieżącą kartę wyników, a zakończona karta
  nie jest doliczana drugi raz w ogłoszeniu. Zaznaczenie/odznaczenie odczytuje
  wszystkie kości zachowane i wybrane do rzutu. Spacja tylko powtarza stan.
- Makao: walidowana pojemność rozdania i zachowana karta początkowa; legalny
  pakiet zachowuje kolejność zaznaczenia. Deklaracja Makao działa po
  przedostatniej karcie, as jest uniwersalny w odpowiednim wariancie, Joker
  zachowuje zadeklarowaną wartość. Dobranie jest pojedyncze, można następnie
  spasować. Wyłączenie kumulowania czwórek nie usuwa samej kary.
- Monopoly: pełne standardowe tabele czynszów, rozróżnienie wierzyciela i
  banku, wypłacanie wierzycielowi tylko realnie pokrytych należności. Sprzedaż
  może uratować ujemne saldo. Bankructwo rozlicza majątek z wierzycielem.
  Dublet wychodzący z więzienia nie daje kolejnego rzutu; przejście kartą
  na Start zalicza okrążenie. Zarządzanie nie zaśmieca głównej listy rzutu.

## Dodatkowe uzgodnione funkcje i poprawki

- Poker: R otwiera istniejące pole liczbowe, nie listę gotowych zakładów.
  Wpisuje się podbicie ponad wyrównanie. Pole podaje oba zakresy: podbicia
  i łącznego kosztu. Przykład: wyrównanie 20 + podbicie 37 = wpłata 57.
  Przy zerowym wyrównaniu jest to zakład otwierający. No-limit, pot-limit,
  half-pot i fixed mają ten sam walidator w przygotowaniu ruchu i replayu.
  Boty mogą nadal wybierać skończony zestaw sensownych propozycji; nie ogranicza
  to człowieka. Zmiana kwoty wyrównania podczas otwartego pola powoduje odmowę
  starej propozycji, a nie cichą zmianę jej kosztu.
- Monopoly: osobne skończone talie Szansy i Kasy Społecznej, zwracane karty
  wyjścia z więzienia, 32 domy i 12 hoteli. Gdy brak domów uniemożliwia
  rozmienienie hotelu, lista jawnie oferuje sprzedaż zabudowy całej grupy.
  Formularz E pozwala wskazać kilka nieruchomości i dowolne nieujemne kwoty
  po obu stronach. Nie zmieniono zakazu wymian zastawionych nieruchomości
  i zabudowanych grup.
- Wspólny szkielet: pola liczbowe przyjmują także przedział bez tworzenia
  olbrzymiej listy wszystkich liczb; formularze działań wykorzystują istniejące
  kontrolki i deklaratywne warunki widoczności. Wysyłana jest jedna gotowa akcja.
- Dźwięki: rzut, zagranie, dobranie/wymiana i działania Monopoly korzystają z
  istniejących plików Audio. Dla rozdania UNO win1 jest tylko dla zwycięzcy,
  lose1 dla pozostałych uczestników. Końcowy wynik całej partii ma pierwszeństwo
  nad dźwiękiem rundy, zgodnie ze wspólną zasadą jednego głównego efektu zdarzenia.

## Boty

- Yahtzee porównuje oczekiwane wartości przerzutów z zapisem w kategorii,
  uwzględnia pozostałe rzuty i wartość zachowania kategorii na później.
  Pamięć wyników obejmuje bieżący kontekst planowania, nie całą historię partii.
- Poker ocenia wymiany i szanse układu na próbkach nieznanych kart. Uwzględnia
  koszt sprawdzenia, pulę i ryzyko dużego zakładu. Nie korzysta z rzeczywistych
  kart przeciwnika ani kolejności przyszłej talii.
- Makao wybiera również pakiety; dobiera kolor pod własną pozostałą rękę
  i uwzględnia rozmiar ręki następnej osoby.
- UNO preferuje legalne zagrania nad zbędnym dobieraniem, pilnuje deklaracji,
  bierze pod uwagę pozostałe kolory, kary i publiczne liczby kart.
- Monopoly uwzględnia rezerwę gotówki, grupy nieruchomości i opłacalność
  zabudowy. W zadłużeniu szuka sprzedaży/zastawu/wymiany. Nie powtarza
  bez końca już odrzuconej oferty zamiast ostatecznie zbankrutować.

To poprawa konkretnych błędnych decyzji, nie pomiar rankingu ani gwarancja
optymalnej gry. Nie dodawano opóźnień botów ani dodatkowego ruchu sieciowego.

## Weryfikacja

`ruby tools/run-five-game-tests.rb` uruchamia wyłącznie pięć wskazanych gier:

- dotychczasowy test 1.1.6 z wyłączonym fragmentem Państw–Miast;
- 28 prób regresji z audytu;
- 36 dodatkowych grup sprawdzeń reguł, własnych kwot, decyzji botów i dźwięków;
- interfejs Yahtzee, formularz wymian Monopoly i numeryczny skrót R obu Pokerów;
- dotychczasowe symulacje pełnych partii oraz dłuższych sekwencji ruchów;
- kontrolę obecności polskich tłumaczeń nowych komunikatów.

Wszystkie przeszły w lokalnym Ruby 4.0.6. Nie uruchamiano pełnego zestawu
projektu, klientów ELTEN-a ani testów serwera. Kontrolki w testach UI są
zastąpione atrapami. Sprawdzono mapowanie i obecność plików dźwiękowych,
nie odsłuch na żywo.

## Granice zakresu

Po dalszym odczycie QC osiemnaście regionalnych plansz Monopoly ma odrębne
układy, kapitały i skalę ekonomii; sześć ma 60 pól. Polska pozostaje własną
edycją. Zakres danych zaobserwowanych i nadal przyjętych jako adaptacja opisuje
`MONOPOLY_REGIONAL_BOARDS.md`. Nadal nie deklarujemy odwzorowania QC 1:1.
Nie zmieniono poza tym
odłożonych wcześniej usterek transportu/pamięci ani polityki zapamiętywania
wyboru profilu Makao (zapamiętywane są własne wartości ustawień).
