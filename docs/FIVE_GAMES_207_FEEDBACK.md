# Poprawki po ręcznych testach 207 — 11 września 2026

Zmiany przygotowane do testowego wydania 1.1.6/build 208 na polecenie
użytkownika. Podpisana wcześniej paczka 207 nie została nadpisana i NIE
zawiera poniższych poprawek. Instalacja i publikacja nie należą do pakowania.

## Przyczyny i zmiany

- Yahtzee liczyło tylko kości tworzące pary, jak w innym wariancie Yatzy.
  Zgodnie z przyjętym wzorem QC para i dwie różne pary dają sumę wszystkich
  pięciu kości. Dwie pary nadal wymagają dwóch różnych wartości. Przy tym
  porównaniu ujawniono mizerię 30 zamiast 36 minus suma, również poprawioną.
  Opis zasad i rezerwy kategorii bota odpowiadają nowej skali punktacji.
  Źródło: https://qcsalon.net/en/yahtzee (odczyt także radio.qcsalon.net).
- Monopoly miało kolor w długiej etykiecie zakupu i potwierdzeniu, ale nie
  miało osobnego wpisu oferty przed wyborem, a wymiany podawały same nazwy.
  Oferta jest teraz zdarzeniem historii obejmującym nazwę, grupę i cenę.
  Dotyczy także wejścia na nieruchomość wskutek karty. Główna lista pozostaje
  na istniejącej kontrolce: „Kup” / „Nie kupuj”, bez dodatkowego dialogu.
  Etykiety i opisy wymian podają grupy. Po akcjach zmieniających właścicieli
  porównywane są komplety kolorów przed/po: zakup, aukcja, wymiana, bankructwo.
  Nowy komplet tworzy jeden wpis historii, odczytywany przez describe_event.
- Regionalne pola Monopoly wcześniej kopiowały nazwy wprost ze źródeł QC.
  Pola zasad dostają lokalną nazwę według typu; nazwy ulic, stacji,
  przedsiębiorstw i pól neutralnych przechodzą przez katalog tłumaczeń.
  Dodano polskie tłumaczenia stacji/przedsiębiorstw/pól neutralnych, nie
  zastępowano nazw własnych ulic. Surowe odczyty QC pozostają niezmienione.
  Polska plansza otrzymała diakrytykę. Nie zmieniono regionalnej ekonomii.
- UNO wykluczało dobranie kary z warunku kończenia tury przy pustym zbiorze
  legalnych zagrań. Teraz warunek sprawdza całą rękę po rozliczeniu kary.
  Pozostaje ustawienie bezwarunkowego pomijania po karze i reguła ruletki.
  Gdy istnieje legalna karta, wyłączone pomijanie nadal pozwala grać.
  Wynik rozdania daje oddzielny wpis zwycięzcy i wpisy punktów z tego rozdania,
  nie myląc ich z sumą całej partii; zwycięzca dostaje jawne 0.
- Sortowanie UNO było zawsze rosnące. Wspólna kontrolka kart przyjmuje
  opcjonalne przełączanie kierunku i zachowuje go lokalnie w stanie widoku.
  UNO włącza je dla Shift+C i Shift+H. Zmiana kryterium zaczyna od rosnącego,
  kolejne naciśnięcia tego samego skrótu odwracają kolejność. Kursor zostaje
  na tej samej karcie. Shift+D przywraca kolejność rozdania, C bez Shift
  pozostaje odczytem wierzchniej karty. Bez dodatkowych żądań sieciowych.
- Poker zmieniał fazy oraz karty wspólne bez wpisów historii. Teraz każde
  przejście dopisuje komunikat do tego samego przyjętego zdarzenia, również
  flop/turn/river rozłożone w ramach jednego all-in. W dobieranym zachowano
  kolejność licytacja → wymiana (również graczy all-in) → licytacja → showdown;
  dodano brakujące ogłoszenia. Prywatne karty podczas wymiany nie są ujawniane.

## Weryfikacja

Nowy test `test/five_games_207_feedback_test.rb`: 17 grup regresji, obejmujących
punktację, UNO +2/+4 bez i z legalną kartą, wyniki rozdania i partii,
zakup/wymianę/aukcję/bankructwo Monopoly, brak powtarzania kompletu, oba
Pokery normalnie i z all-in, zgodność replayu i mowy oraz rzeczywisty katalog
polskich nazw pól. Test UI sprawdza oba skróty sortowania w trzech kolejnych
naciśnięciach, kierunek po odbudowie, zachowanie wybranej karty i Shift+D.

Przeszedł cały ograniczony runner `tools/run-five-game-tests.rb`, w tym nowe
próby i dotychczasowe 28 regresji, 36 grup, UI, regionalne plansze, symulacje
oraz rozszerzony sprawdzian tłumaczeń. Przeszedł również wymagany dla zmiany
wspólnej kontrolki `test/surface_framework_test.rb`. Pełnego zestawu projektu
nie uruchamiano. Nie testowano na żywych klientach ani na serwerze.

Nie zmieniano transportu, botowego wykonawcy, tabel, zasad Makao ani mechanizmu
odświeżania formularzy. Testy symulacyjne nie są gwarancją jakości strategii.
