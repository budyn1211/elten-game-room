# Statki i Mankala — integracja do 2.0.1/build 229

18 września 2026. Na polecenie użytkownika włączono obie gry oraz uzgodnione
poprawki. Zachowano wcześniejsze niewydane zmiany. Numer wersji i buildu
pozostaje ten sam; przebudowanie i podpisanie zostało teraz zatwierdzone.
Nie oznacza to instalacji, publikacji, wysłania na GitHub ani scalenia PR-ów.

## Pochodzenie

Autor pierwotnej implementacji obu gier: **Dawid Pieper**.

- [PR #8 — Statki](https://github.com/papierek1997/elten-game-room/pull/8),
  `f19504ba298eaefff14e86ebfda8c6e37bcf312e`.
- [PR #9 — Mankala](https://github.com/papierek1997/elten-game-room/pull/9),
  `4c847c8beb5eb2dd7e4b6f45af0f7587a6ee72cd`.

Przegląd przed wdrożeniem znajduje się w katalogu roboczym
`diagnostics/pr-8-9-review-20260918/REVIEW.md`. Nie zastąpiono całych wspólnych
plików starszymi wersjami z PR-ów.

## Statki: zamknięcie punktów przeglądu

- **B1:** naprawione tworzenie skrótów po odpowiedzi na strzał. L podaje gracza,
  pole i wynik, bez brakującego argumentu ani powtórzenia pola.
- **B2:** ujawnienie floty zachowuje kolejność statków i pól używaną przez
  zobowiązanie kryptograficzne. Zapis `1:` + dwucyfrowe pola base36 rozdzielone
  kropkami między statkami zajmuje maksymalnie 51 znaków dla polskiej floty
  i 40 dla klasycznej. Nonce nadal zajmuje osobne 64 znaki. Sprawdzono
  rzeczywiste `GameRepository.append_events`, bez podnoszenia limitu 64.
- **B3:** zapis tej gry jest jawnie wyłączony. Publiczna historia nie zawiera
  prywatnych flot obu graczy. Mankala pozostaje zapisywalna.
- **B4:** Enter na własnej planszy nie strzela. Wspólna kontrolka przekazuje
  identyfikator planszy; gra go sprawdza. Sprawdzane są również obie współrzędne.
- **B5:** prywatna flota jest wczytywana przed pokazaniem widoku, niezależnie od
  automatycznej odpowiedzi i roli właściciela. Pamięć jest wiązana z graczem
  oraz jego zobowiązaniem, a brak danych nie jest zapamiętywany na stałe.
  Nowy wspólny hook `prepare_view` domyślnie nic nie robi w innych grach.
- **B6:** obserwator widzi dwie nazwane plansze z publicznymi wynikami strzałów,
  bez narzędzia rozstawiania i bez ujawniania prywatnych statków przed końcem.
  Nie może wykonywać akcji gracza. Pełne floty widzi dopiero po zakończeniu.
- **B7:** ujawnienia są sprawdzane przed zmianą stanu: typy, liczebności,
  współrzędne, prostoliniowość, nachodzenie i odstępy zgodne z wariantem.
  Nieprawidłowe dane nie powodują wyjątku podczas replayu.
- **B8:** bot korzysta tylko z publicznych, chronologicznych odpowiedzi.
  Bez stykania odrzuca otoczenie zatopionego statku. Przy stykaniu nie uznaje
  automatycznie sąsiedniego trafienia za część zatopionego okrętu. Ocenia
  pozostałe możliwe położenia, zachowując niepewność; mapę ocen oblicza raz
  dla danego układu odpowiedzi, a nie od nowa dla każdego pola.

## Mankala: zatwierdzona odmiana i poprawki

- **M1/M2:** nie są zmianami reguł. Zachowano Ayoayo autora: własny ostatni
  kamień jest zabierany razem z kamieniami naprzeciwko. Przy zakończeniu
  z braku legalnego ruchu resztę otrzymuje ostatni wykonujący ruch. Nowe
  testy obejmują pusty rząd i niemożność zasilenia pustego rzędu przeciwnika.
- **M3:** klucz pamięci planisty uwzględnia licznik ruchów bez bicia, wariant,
  bicie Kalah oraz fazę. Te same dołki przy liczniku 0 i 119 nie są już
  mylone, mimo różnych skutków następnego ruchu.
- **M4:** historia przechowuje kanoniczny numer dołka, a tekst i współrzędne
  są dopasowywane do odbiorcy. Własny rząd nadal jest na dole. Ruch Boba
  z jego A1 jest dla Alice ruchem z F2, również w historii i odczycie zdarzenia.
- **M5:** S korzysta ze wspólnej kolejności wyników, od najwyższego.
- **M6:** testy planistów używają prawdziwego środowiska symulacji. Wszystkie
  trzy poziomy każdego wariantu wykonują wyszukiwanie, respektują limit węzłów
  i nie zmieniają rozgrywanej pozycji. Test odtworzenia zapisu obejmuje trzy
  warianty. Nie zmieniono istniejących głębokości ani limitów obliczeń.

Uwaga przeglądu o `RELAY_LIMIT` nie była potwierdzonym błędem legalnej pozycji.
Nie wprowadzano nieuzgodnionej reguły remisu ani zmiany rozsiewania w tym
miejscu. Zachowano istniejący bezpiecznik autora; testy nie są dowodem, że
nie istnieje rzadka pozycja osiągająca go. To pozostaje ograniczeniem analizy.

## Czytelne instrukcje i integracja

Nowe zasady napisano osobno w PL/EN, pełnymi zdaniami, z przykładami oraz
oddzielnym objaśnieniem każdej odmiany. Opisują implementację, nie dowolną
odmianę znalezioną w sieci. Źródła pomocnicze:

- [Kurnik: polskie zasady Oware](https://www.kurnik.pl/oware/zasady.phtml)
  — sposób objaśnienia rozsiewania, bicia i zasilania przeciwnika. U nas
  zabezpieczeniem jest 120 ruchów bez bicia, nie trzykrotne powtórzenie.
- [Librus: polska instrukcja Statków](https://files.librus.pl/mrk/25/Rozgrzej_mozg/Librus_Rozgrzej_mozg_i_zagraj_w_statki.pdf)
  — polska flota, rozmieszczenie i stopniowe uszkadzanie statku. U nas
  jest zawsze jeden strzał na turę, również po trafieniu.
- [Polskie zasady Kalah](https://mankala.pl/wp-content/uploads/ZASADY-GRY-MANKALA.pdf)
  — dostępny wynik wyszukiwania; pełny dokument w tej sesji zwracał 403,
  więc nie traktowano go jako przeczytanego w całości.
- [Ayoayo, John Pratt](https://www.johnpratt.com/items/mancala/ayoayo.html)
  oraz [Mancala World](https://mancala.fandom.com/wiki/Ayoayo) — porównane
  podczas przeglądu odmiany różnią się biciem i rozliczeniem końcówki.
  Użytkownik wybrał wariant PR-u potwierdzony w drugim opisie. Ponowny
  pełny odczyt drugiej strony podczas wdrożenia był niedostępny.
- Angielskie instrukcje i kod z obu PR-ów — punkt odniesienia dla zachowanych
  lokalnych wariantów i obsługi klawiatury. Instrukcje nie są kopią ani
  dosłownym tłumaczeniem zewnętrznych tekstów.

Źródła redakcyjne: `docs/rulebooks/battleship.json` i `mancala.json`.
Każdy skrót ma osobny wiersz; podczas gry pomoc nadal korzysta z bieżących
definicji pola gry. Opcje, teksty i liczba kamieni mają polskie tłumaczenia.
Zachowano wspólne ustawienia, opóźnienie bota, Ctrl+R i domyślne włączenie
nowych gier we widgecie bez zmiany wcześniejszych ręcznych odznaczeń.

Dźwięki pochodzą z istniejących zasobów: Statki `play`, `play2`, `skip`,
`hit1`; Mankala `domino_move_tile`, `hit1`. Wyniki partii nadal obsługuje
wspólny mechanizm. Nie dodawano nowych pobrań ani nie zmieniano nagrań.

Changelog 229 zachowuje wcześniejsze 22 punkty i dopisuje dwie pozycje
o nowych grach. Starsze changelogi nie są zmieniane.

## Weryfikacja wydania

Celowane regresje obu gier, rzeczywistej warstwy zapisu, kontrolek i botów
oraz wcześniejszych niewydanych zmian uruchamia skrypt w lokalnym katalogu
`diagnostics/new-board-games-229/verify-source.rb`. Wyniki, składnia i sumy
źródeł: `SOURCE.json`. Kontrola podpisanej paczki, manifestów, autora,
zgodności plików ze źródłami i binarnego wczytania: `PACKAGE.json`.

Nie uruchamiano pełnego runnera ani żywych klientów. Testy odtwarzają API
kontrolek i wykorzystują rzeczywisty słownik ELTEN-a oraz jego ograniczenie
tasowania, ale nie zastępują ręcznej próby na dwóch klientach.
