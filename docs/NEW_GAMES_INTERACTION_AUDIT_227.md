# Interfejs nowych gier — 17 września 2026

## Zakres i stan

Na zgłoszenie D/Shift+D poprawiono Rummy. Późniejsze polecenie
„poszukaj błędów w innych grach, co je wprowadziłeś” rozszerzyło przegląd
o Domino, Mexican Train, Scrabble i Taboo. Dla tych czterech gier wykonano
audyt i odtworzenia. Następnie użytkownik doprecyzował G/D w Domino
i polecił „popraw od razu resztę”: wszystkie osiem opisanych niżej punktów
obsłużono w źródłach. D1 ma nowe, zatwierdzone zachowanie, a nie wcześniejszą
propozycję naprawiania menu stron. Szczegóły wdrożenia poniżej.
Nie zmieniano przy okazji ich zasad ani strategii. Osobne późniejsze
polecenie użytkownika objęło krótsze opisy Mexican Train: nagłówek C to
„Pociągi”, bez stacji, a wiersze i wybory celów to np. „papierek, 9,
otwarty”, bez słowa „koniec”. Tę zmianę wdrożono po polsku i angielsku.
Nie usuwa ona stacji ze stanu ani szczegółowego łańcucha; zachowuje
otwartość oraz oznaczenie dubletu. Same krótsze etykiety nie naprawiały
M1/T1/T2/T3; ich późniejsze naprawy są osobnym krokiem opisanym poniżej.

Testy celowane używają atrap kontrolek i transportu, nie działającego
ELTEN-a. Nie wykonywano pełnego runnera, rzeczywistych partii ani ponownego
audytu całych słowników Scrabble i 1000 kart Taboo. Nie zmieniano wersji,
manifestów, changelogu, serwera; bez budowania, podpisywania, instalacji
i publikacji. Podpisana paczka 2.0/227 o SHA-256 c8dd0b8c… pozostaje
niezmieniona i NIE zawiera najnowszych poprawek Rummy, opisów pociągów
ani wdrożonych po audycie napraw Domino, Mexican Train i Scrabble.

## Naprawy po zatwierdzeniu audytu — 17 września 2026

- D1: G ustawia lewą, D prawą stronę, bez zagrywania i bez żądania do
  serwera. Enter przy obu legalnych końcach używa wyboru bez pytania;
  przy jednym gra na jedyny pasujący koniec, nie zmieniając preferencji.
  Początkowo wybrana jest prawa strona; wybór przeżywa odświeżenia,
  odtworzenie powierzchni, podgląd stołu, cudze tury i kolejne rozdania.
  Z zachowuje dotychczasową ostrożność przy dwóch legalnych stronach.
  Zmiana dotyczy tylko Domino; Mexican Train nadal pyta o pociąg.
- D2: wiersze łańcucha mają ID fizycznych kostek. Podgląd pozostaje na
  tym samym egzemplarzu po dołożeniu z lewej, również w zestawach 2×/4×.
- T1: podgląd publicznego stołu bezpiecznie anuluje otwarty wybór celu,
  zapamiętując właściwą kostkę, nie indeks opcji celu. Nie zostaje
  niewidoczne menu ani nie jest wykonywany ruch. W Domino dodatkowe
  menu końca zostało usunięte zgodnie z nowym wymaganiem.
- M1: podgląd korzysta z ID pociągu i kostki, nie numeru wiersza. Po nowym
  rozdaniu wraca do aktualnej ręki; nie podmienia Boba na Carol. Rozdanie
  identyfikuje osobna epoka podglądu. Stacja i krótkie nazwy bez zmian.
- T2: odtworzenie i odświeżenie podglądu nie czyta niewidocznej ręki,
  ale jej kursor nadal śledzi ostatnią dobraną kostkę na późniejszy powrót.
- T3: Escape z wyboru pociągu czyta tylko wskazaną kostkę, bez nagłówka
  ręki. Zmiana jest w adapterze kostek, nie w ogólnej obsłudze karcianek.
- S1: Backspace wraca na faktyczne pole ostatniej usuniętej płytki
  i odczytuje to pole bez nagłówka planszy. Działa w pionie, poziomie,
  po ominięciu zatwierdzonej litery oraz z blankiem i przy brzegu.
- S2: pusty szkic wymaga położenia co najmniej jednej płytki w celu
  utworzenia/przedłużenia słowa. Minimalna długość słowa nadal wynosi
  dwie litery; pojedyncza nowa płytka przy istniejącej literze jest legalna.

Nie zmieniono zasad, punktacji, botów ani formatu zdarzeń. Uaktualniono
pomoc, opis sterowania i tłumaczenia PL. 16/16 celowanych skryptów przeszło,
w tym nowe `tile_interaction_test` (10 przypadków) i `scrabble_editing_test`
(5 przypadków), dotychczasowe testy modeli, powierzchni, kursora, odczytów,
tłumaczeń i binarnego ładowania bieżących źródeł. Symulacja ograniczonej
liczby tur potwierdza replay, archiwa i brak dodatkowych zapisów ruchu.
Nie jest to test nowej paczki ani żywego interfejsu. Nowe wyniki i
odtworzenia sprzed poprawek: `../diagnostics/new-games-interaction-fixes-227/`.

## Rummy — poprawione w źródłach

- D jest odczytem, nie otwiera żadnego okna. Single discard i wariant bez
  zabierania odrzutów udostępniają tylko wierzchnią kartę, multiple wszystkie
  od najnowszej. Nie usunięto starszych kart potrzebnych do recyklingu stosu.
- Shift+D od razu dobiera przy jednej legalnej możliwości. Przy kilku
  otwiera listę kart. Nadal obowiązuje własna tura, dobieranie tylko raz,
  odpowiedni wariant i pierwsze wyłożenie.
- Bezcelowe menu zawierające tylko „Anuluj” zastąpiono wyjaśnieniem, np.
  „Najpierw dobierz kartę”. W wariancie bez odrzucania Enter nie wysyła
  niepoprawnej surowej nazwy karty jako ruchu.
- Rutynowe odświeżenie i odtworzenie powierzchni zachowują otwarty wybór
  odrzutu lub edycję przygotowanych układów. Zmiana tury usuwa nieaktualne
  akcje; nowa runda nie przywraca starego podglądu.
- C uruchomione podczas wyboru zagrania nie pozostawia niewidocznego menu
  z błędnym indeksem. Podgląd układów śledzi ich trwałe ID, nie numer wiersza.
- Powrót do ręki odczytuje kartę bez „Twoja ręka”. Zabranie kart ze stołu
  wraca do ręki i ustawia kursor na ostatniej zabranej. Zmiana ukrytej ręki
  nie odczytuje karty zamiast aktualnie oglądanego układu.
- P podaje rzeczywistą sumę i brak do pierwszego wyłożenia; informuje
  również o niepoprawnym układzie. Po pierwszym wyłożeniu nie wymienia
  niepotrzebnie minimum zero. Sortowanie podaje kierunek.
- Układy mają numery w podglądzie i wyborach dołożenia. Publiczne ruchy
  wskazują konkretny układ; wymiana jokera podaje także kartę, która go
  zastąpiła. Wymuszone dobranie po czasie jest jawnie ogłaszane bez
  ujawniania karty. Końcowe podsumowanie zwykłej rundy podaje sumę każdego
  gracza; w eliminacji mnożnik poprzedza wynikające z niego punkty.
- Uzupełniono polskie tłumaczenia, katalog PL.mo, zasady i testy. Nie zmieniano
  punktacji ani warunków legalności ruchów w celu naprawienia samych komunikatów.

Nowy `test/rummy_interaction_test.rb`: 23 scenariusze. Pierwszych 18
odtwarzało problemy sprzed poprawki; końcowych pięć sprawdza podgląd,
brak odrzucania i komunikaty. Wszystkie 23 przechodzą po zmianach.

## Odtworzone problemy sprzed napraw (materiał audytu)

### D1. Domino: G/D nie działa w otwartym wyborze strony

Enter na kostce pasującej na oba końce otwiera „Lewo/Prawo”. Naciśnięcie
G albo D w tym momencie mówi „Ten ruch jest niedostępny”, mimo że dany
koniec jest legalny. Skróty działają dopiero z samej ręki.

Przyczyna: `lib/game_surfaces/tile_hand.rb`, `handle_command`, odrzuca
wszystkie komendy, gdy istnieje `@pending_choices`, przed obsługą `tile_side`.
Pierwotna propozycja: w tym konkretnym wyborze G/D powinno wybierać legalny koniec
wybranej wcześniej kostki, z ponowną walidacją po stronie gry.
Nie zastępować kostki tą wskazaną indeksem opcji „Lewo/Prawo”.
Ta propozycja została zastąpiona przez późniejsze wymaganie użytkownika:
G/D to zapamiętany przełącznik, Enter nie otwiera menu stron. Wdrożono
to zachowanie, opisane w sekcji napraw, zamiast poprawiania starego menu.

### D2. Domino: po dołożeniu z lewej podgląd wskazuje inną kostkę

Przeglądając V kostkę 1–2, po dołożeniu 4–1 z lewej użytkownik nadal
znajduje się w wierszu zero, ale odczytuje już 4–1. Kursor śledzi numer
wiersza, nie oglądaną kostkę.

Przyczyna: `games/domino.rb#table_rows` nie przekazuje ID, a
`TileHandSurface#update_spec` przywraca tylko indeks. Zachowywać tożsamość
fizycznej kostki, również przy identycznych kopiach w zestawach 2×/4×.

### T1. Domino i Mexican Train: podgląd stołu zablokowany podczas wyboru

Po otwarciu wyboru końca albo pociągu V w Domino lub C w Mexican Train
zwraca „Ten ruch jest niedostępny”, chociaż chodzi o odczyt publicznej
informacji, nie zagranie. Trzeba najpierw nacisnąć Escape.

Przyczyna: `TileHandSurface#open_table` odrzuca otwarte `@pending_choices`.
Propozycja: jawnie zapamiętać i zawiesić wybór albo bezpiecznie go anulować
przed podglądem, nie nakładać dwóch list na jeden indeks. Jest to problem
dostępności/nawigacji; nie wykazano zmiany zasad ani utraty kostek.

### M1. Mexican Train: szczegóły mogą po cichu zmienić właściciela

Jeśli podgląd pociągu pozostaje otwarty do kolejnego rozdania, a jego
właściciel odpada, usunięcie jego wiersza powoduje otwarcie szczegółów
następnego gracza. W odtworzeniu szczegóły Boba stały się szczegółami Carol,
bez informacji o zmianie. Dotyczy także odczytywanego miejsca w łańcuchu.

Przyczyna: `TileHandSurface` zachowuje `tile_detail` jako indeks, również
między rundami; `games/mexican_train.rb#table_rows` nie przekazuje ID pociągu.
Zachowywać ID wewnątrz rundy, a na nową rundę zresetować stary podgląd
albo jawnie przenieść na bieżącą listę pociągów. Nie podmieniać właściciela.

### T2. Obie gry z kostkami: odczyt ręki zamiast otwartego podglądu

Przy odtworzeniu powierzchni z zachowanym podglądem stołu i zmienioną ręką
kolejka mowy może zawierać nową kostkę z ręki. W odtworzeniu wyświetlany
był łańcuch/pociągi, a komunikat kursora brzmiał „4–4” z ukrytej ręki.
Zwykłe `update_spec` już czyści tę kolejkę, lecz konstruktor jej nie czyści.

Przyczyna: `TileHandSurface#initialize` po `super` otwiera podgląd,
zachowując `@cursor_announcements`. Odczyt kursora musi uwzględniać
aktywny widok. Ręka nadal powinna zachować ostatnią dobraną kostkę
na późniejszy powrót. Odtworzono w lokalnej kontrolce; nie ustalono
częstotliwości takiej rekonstrukcji w rzeczywistym kliencie.

### T3. Obie gry z kostkami: zbędny nagłówek przy anulowaniu wyboru

Escape z wyboru końca/pociągu wywołuje pełny fokus „Twoje kostki” zamiast
samej nazwy wybranej kostki. Dla zwykłego zamknięcia podglądu stołu jest
już poprawny cichy powrót, ale menu celów dziedziczy pełny odczyt z CardTable.

Naprawić w adapterze kostek, bez zmiany odczytów innych gier i czatu.
To zbędny komunikat, nie błąd zasad ani uszkodzenie ręki.

### S1. Scrabble: Backspace zostawia kursor za usuniętą literą

Po wpisaniu CAT z G8 kursor jest na J8. Backspace usuwa T z I8, ale kursor
nadal pozostaje na J8. Ponowne wpisanie T umieszcza je na J8, tworząc
„CA_puste_T”; zatwierdzenie zgłasza lukę. Trzeba ręcznie wrócić strzałką.

Przyczyna: `lib/game_surfaces/word_board.rb`, gałąź `word_undo`, wykonuje
tylko `@draft.pop`. Cofnięcie powinno wrócić na faktyczne pole usuniętej
płytki, także po przeskoczeniu zatwierdzonych liter i w pionie.
Walidator poprawnie odrzuca lukę — problem leży w edytorze, nie punktacji.

### S2. Scrabble: mylący komunikat o minimum dwóch nowych liter

F na pustym projekcie mówi „Umieść co najmniej dwie połączone litery…”.
Tymczasem pojedyncze T do istniejącego A tworzy legalne AT. Dwie litery
są minimalną długością słowa, nie minimalną liczbą nowych płytek w turze.

Przyczyna: `games/scrabble.rb#move_error`, `empty_move`. Doprecyzować tekst,
bez zwiększania minimalnej liczby płytek w walidacji ruchu.

## Taboo i sprawdzone reguły

Nie potwierdzono nowego błędu Taboo w zbadanych scenariuszach. Sprawdzono
role i ukrywanie karty, przypisanie Enter/B/P do konkretnej karty, czas,
korekty mastera, mastera-obserwatora, aktualizację kontrolek, punktację,
rotację i dogrywkę. Dotychczasowy celowany test pięciu klientów przechodzi.
Nie oznacza to gwarancji braku błędów ani weryfikacji całych talii słowo po słowie.

Testy reguł Domino i Mexican Train obejmują zestawy i rozdania, opcje
dobierania, drużyny, blokadę, punktację, kolejność dubletów i zatwierdzony
wyjątek autora serii. W tych próbach nie znaleziono nowej usterki reguł.
Testy Scrabble obejmują premie, blanki, nielegalne słowa, wymianę,
rozliczenie i replay; opisany błąd Backspace nie zmienia naliczania punktów.

## Dowody i weryfikacja etapu audytu (przed poleceniem napraw)

19/19 celowanych skryptów przechodzi: `rummy_test`, `rummy_surface_test`,
`rummy_edges_test`, `rummy_save_strategy_test`, `rummy_variants_test`,
`rummy_interaction_test`, `plan_2_localization_test`, `domino_test`,
`mexican_train_test`, `mexican_train_labels_test`, `tile_hand_test`, `scrabble_test`,
`scrabble_surface_test`, `taboo_test`, `taboo_surface_test`,
`taboo_network_test`, `card_hand_cursor_test`, `new_games_2_announcements_test`
i `packaged_rules_encoding_test` (tryb binarnego wczytania aktualnych źródeł,
nie test starego artefaktu jako zawierającego nowe poprawki).

Osobna diagnostyka poza repozytorium:
`../diagnostics/new-games-interaction-227/audit.rb`. Osiem scenariuszy
potwierdza usterki D1/D2/T1/M1/T2/S1/S2/T3. To NIE jest osiem przechodzących
testów poprawnego zachowania; raport jawnie porównuje oczekiwanie z błędnym
wynikiem. Nie pomylić tego z 19 przechodzącymi skryptami powyżej.
Wyniki w `AUDIT.json` i `TESTS.json` w tym samym katalogu diagnostyki.
