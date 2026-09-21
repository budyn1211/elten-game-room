# Pong, historia i F1 — wykonanie planu

21 września 2026. Wersja 2.0.1.1/build 232 zgodnie z poleceniem użytkownika.
Poprzednia podpisana paczka 2.0.2/build 231 pozostaje zachowana.

## Zmiany w Pongu

- Pierwsza opcja to lista Classic/Arcade. Zachowano klucz `arcade` i wartości
  logiczne, więc samo zastąpienie kontrolki nie zmienia zapisanych ustawień.
- Shift+E i potwierdzenia nazywają dodatkowe wskazówki „Brzmienie band”.
  Funkcja nadal ma stany wyłączone, szum, tony. Nie dodano Showdown.
- Kolejka wyniku czeka na koniec poprzedniego nagrania. Odstępy są minimalnym
  czasem rozpoczęcia, a nie terminem przerywania głosu. Spóźniony krok UI
  nie uruchamia kilku głosów naraz. Koniec próbki jest sprawdzany w ticku,
  bez uśpienia wątku interfejsu. Pełny komunikat zwycięstwa poprzedza
  ponowny odczyt końcowego wyniku.
- Gdy brakuje nagrania liczby (w szczególności od 22), odczytywany jest
  pełny wynik z nazwami graczy przez syntezę ELTEN-a. Nadal obowiązują
  lokalne ustawienia lektora i ogólna głośność Game Roomu.
- Gdy klient przejmuje zapowiedź punktu/wyniku, wspólny prezenter nie
  odczytuje jej drugi raz. Zdarzenia pozostają w historii. Przy wyłączonych
  dźwiękach gry zostaje zwykły odczyt tekstowy.
- Obserwator wybiera 1 lub 2 wyłącznie w polu gry. Wybór wskazuje osobę,
  więc przestawienie kolejności graczy nie zmienia samowolnie perspektywy.
  Jeśli osoba znika, wraca pierwsza perspektywa. Nie zmienia to uprawnień,
  strony sterowania, sieci ani symulacji. Obserwator słyszy nazwę zwycięzcy,
  nie „wygrywasz”/„przegrywasz”.
- Uwzględniono wcześniejszy cykl odtwarzania klienta przy rewanżu opisany
  w PONG_REMATCH_FIX_231.md. Nie zmieniono fizyki, protokołu ani reguł punktacji.

## Wspólna historia i pomoc

Historia gry, pokoju i lobby używa wielowierszowego pola tylko do odczytu.
Wpisy są oddzielone pustym wierszem. Można czytać słowa/litery, zaznaczać
i kopiować tekst. Nowa zawartość aktualizuje istniejący obiekt: zaznaczenie
i pozycja są zakotwiczone w czytanym wpisie. Jeśli kursor śledzi ostatni
wpis bez zaznaczenia, podąża za nowymi. Wewnętrzne indeksy natywnego pola
liczą znaki LF, niezależnie od eksportowania tekstu z CRLF.

Ctrl+przecinek/kropka przechodzi po wpisach bieżącej kategorii,
Ctrl+Shift+przecinek/kropka wybiera kategorię, Ctrl+Home/End wybiera jej
pierwszy/ostatni wpis. Odczytywane jest całe zdarzenie, także wielowierszowe.
Z pola gry skróty nie zmieniają fokusu; w historii ustawiają też kursor.
Nie przejmują natywnej edycji czatu. Dawne skróty historii ze strzałkami
nie są już podłączane, a zwykłe strzałki pozostają tekstowe.

F1 nadal korzysta z rzeczywistych definicji skrótów i dotychczasowej
kolejności kategorii. Prezentacja jest tekstowa, po jednym skrócie na
wiersz; rozdzielono również skróty głośności. Enter/Escape zamyka pomoc
i przywraca poprzednie pole. Nie nadpisano hosta poza Game Roomem ani
nie zmieniono osobnej listy skrótów w sekcji zasad Ctrl+F1.

## Weryfikacja i granice

Nowe regresje: `pong_history_feedback_test`, `pong_spectator_test`,
`history_text_test`, `history_native_text_test`. Obejmują liczby
10/11/20/21/22/57, zakończenie głosów, obie perspektywy, zmianę składu,
brak sterowania przez obserwatora, zaznaczenie Unicode i kopiowanie,
wielowierszowe wpisy, dopisywanie, kategorie, fokus i czat. Sprawdzane są
również wcześniejsze rematche, wspólne UI, binarne źródła i prawdziwy
słownik PL/EN/fallback. Natywna kontrolka tekstowa jest wykonywana lokalnie
bez uruchamiania aplikacji i bez dostępu do schowka urządzenia.

Uaktualniono wyłącznie konfigurację starego testu odzyskiwania quizu
(zegar elapsed i atrapa Base). Nie zmieniono jego asercji ani produkcyjnego
quizu; zgodnie z poleceniem użytkownika to nie jest punkt changelogu.

Końcowe wyniki źródeł i podpisanej paczki są zapisywane osobno poza repo:
`diagnostics/pong-history-release-232/SOURCE.json` i `PACKAGE.json`.
Samo istnienie tego dokumentu nie potwierdza zakończenia pakowania.
Testy kolejki nie zastępują odsłuchu urządzenia ani meczu na żywym łączu.
Bez pełnego runnera, instalacji, publikacji, GitHuba i zmian serwera/profili.
