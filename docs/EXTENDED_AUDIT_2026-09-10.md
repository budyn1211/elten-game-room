# Celowany audyt: równoczesne operacje, długa gra i odtwarzanie

Data: 10 września 2026. Badano bieżące robocze źródła po buildzie 202, wraz
z wcześniejszymi poprawkami audytu i synchronizacji. W tej turze nie zmieniano
kodu programu, numeru wersji ani istniejących testów projektu. Dodano wyłącznie
lokalne reprodukcje i ten raport. Nie używano serwera, MCP ani profili ELTEN-a.

## Potwierdzone problemy

### 1. Dodanie bota może przekroczyć limit po równoczesnym dołączeniu człowieka — P2

Miejsce: `lib/lobby_repository.rb:553–568`, w zestawieniu z
`lib/live_session_store.rb:398` (`admit_joined_session`).

W pokoju jest siedem osób. Dodawanie bota sprawdza liczbę miejsc na podstawie
snapshotu. Jeżeli ósma osoba dołączy przed zapisaniem nowej liczby botów, jej
dołączenie jest jeszcze poprawne: wtedy botów nie ma. Następnie zapis bota
korzysta z wcześniejszego sprawdzenia i również kończy się sukcesem.

Odtworzono oba warianty:

- przekazany do `add_bot` snapshot powstał przed dołączeniem ósmej osoby;
- nawet bez przekazywania snapshotu ósma osoba dołącza **między świeżą kontrolą
  a zatwierdzeniem zapisu bota**.

W obu przypadkach rzeczywisty stan to 8 ludzi + 1 bot, czyli 9/8 miejsc.
Limit natywnej sesji nie pomaga, ponieważ liczy ludzi, a nie wirtualne boty.
Zabezpieczenia rozpoczęcia gry odrzucają zbyt liczny skład; nie oznacza to
uszkodzenia trwającego replayu, ale użytkownik może dostać sprzeczne rezultaty:
dołączenie i dodanie bota udały się, a rozpoczęcie gry już nie.

Kierunek naprawy: kontrolować końcowy przyjęty skład po zmianach i rozstrzygać
konflikt dodania bota z dołączeniem człowieka, bez wyrzucania poprawnie
przyjętego użytkownika. Sam dodatkowy odczyt przed zapisem nie zamyka tego
wyścigu. Nie przywracać starego transportu ani ogólnego okresowego odpytywania.

### 2. Pamięć klienta zachowuje ruchy starych gier także po zamknięciu pokoju — P2

Miejsca: `lib/live_session_store.rb:189`, `:384`, `:670`, `:728` i `:298`.

`stack_trim` ogranicza dane na serwerze, lecz nie czyści lokalnych `@records`
i `@record_keys`. Zamknięcie usuwa mapowanie aktywnej sesji, ale pozostawia te
kolekcje. Nie chodzi wyłącznie o celowo zachowany tekst czatu: pozostają pełne
zdarzenia dawnych partii, ich rozpoczęcia i potwierdzenia.

Pomiar po 40 zastąpionych partiach testowych, po 25 zdarzeń ruchu w każdej
(syntetyczne komendy sprawdzają tutaj magazyn, nie reguły gry):

- serwer: 2 wpisy (checkpoint pokoju i początek nowej partii);
- lokalna pamięć magazynu: 1083 wpisy, w tym 1000 starych ruchów;
- po zamknięciu pokoju: nadal 1083 wpisy w kolekcji magazynu.

To potwierdzenie narastania danych, a nie pomiar konkretnego zużycia RAM ani
czasu opóźnienia interfejsu. Skutek wydajnościowy wynika też z tego, że
`game_events` i projekcja stołu przeglądają kolekcję obejmującą poprzednie gry.
Wcześniejsza poprawka stosu serwera jest potrzebna, ale nie rozwiązuje tej
oddzielnej kwestii lokalnej pamięci.

Kierunek naprawy: rozdzielić zachowaną historię prezentacji od zdarzeń potrzebnych
do odtworzenia bieżącej gry. Po nowym starcie zwolnić niepotrzebne stare replaye,
a po zamknięciu pokoju również jego indeksy i pamięć pomocniczą. Uwzględnić późne
callbacki, żeby nie odtworzyły dopiero usuniętego stanu.

### 3. Ujawnione odpowiedzi gościa w Państwach-Miastach pozostają w schowku — P3

Miejsca: `games/categories.rb:499–542`, `lib/hidden_submissions.rb:75–101`
i `:148`.

Usunięcie koperty z odpowiedziami znajduje się w `automatic_action`, w gałęzi
wykonywanej, kiedy ujawnienie już dotarło. Jednak dla gracza niebędącego masterem
`automatic_action_allowed?` odmawia wykonania tej metody właśnie wtedy, gdy jego
ujawnienie jest już obecne. Ścieżka sprzątania nie jest więc uruchamiana.

Odtworzono pełne wysłanie i ujawnienie odpowiedzi Boba, ocenę, zamknięcie rundy
i rozpoczęcie nowej partii. Poprzednia koperta nadal pozostaje w magazynie.
Test używa `MemoryStorage`, bez dostępu do profilu. Produkcyjne `ProgramStorage`
zapisuje ten sam stan w lokalnym `hidden_submissions.json`.

Nie jest to dowód wycieku do innych graczy ani nowa przyczyna utknięcia fazy
oceniania. To brak sprzątania lokalnych danych i rosnąca ilość treści, które
trzeba odczytywać i zapisywać przy następnych odpowiedziach.

Kierunek naprawy: sprzątać dopiero po potwierdzonym ujawnieniu, ale niezależnie
od prawa do wykonania kolejnej akcji automatycznej. Nie usuwać odpowiedzi
przy samym rozpoczęciu wysyłki — muszą przetrwać jej niepewny wynik.

## Ponownie potwierdzone wcześniejsze ograniczenie

### Zapełnienie stosu podczas jednej gry blokuje ruchy i nowy start — P2

Miejsca: `lib/live_session_store.rb:14`, `:236` i `:384`.

To ograniczenie było już zapisane w poprzednim raporcie, nie jest nowym
odkryciem. Obecna próba wypełniła rzeczywisty skonfigurowany limit 4096 wpisów
poprawnymi wiadomościami czatu przy rozpoczętej grze w Czwórki. Potem legalny
ruch został odrzucony przez `StackFull`. Próba rozpoczęcia następnej gry również
została odrzucona — nie mieści się nawet checkpoint poprzedzający czyszczenie.

Nie usunięto zapisanych danych. Gra jest jednak zablokowana na zapis w tym
pokoju. Sam limit częstotliwości żądań nie ma tu znaczenia: chodzi o całkowitą
liczbę przechowywanych wpisów. Próba nie mierzy, jak często rzeczywiści gracze
osiągają tę granicę.

Kierunek naprawy wymaga osobnego projektu: bezpieczne ograniczenie logu przed
zapełnieniem, z zachowaniem stanu potrzebnego nowemu klientowi. Nie wolno po
prostu obciąć początku aktualnej gry, ponieważ z niego odtwarzane są karty,
plansza i wyniki. Wcześniejsze trzy usterki z raportu synchronizacji także
pozostają niezmienione.

## Scenariusze, które przeszły

1. **Dołączenie podczas startu** — przed checkpointem, przed `game_started`
   i po nim. Skład rozpoczętej partii pozostaje jeden i nie zmienia się przez
   dołączenie trzeciej osoby. Jej klient widzi ten sam replay jako obserwator.
2. **Dwa ruchy przygotowane na tej samej kolejce** — dwa legalne wcześniej
   zamiary jednego gracza, po nich prawidłowy ruch przeciwnika i powtórzone
   powiadomienia. Drugi nieaktualny zamiar nie staje się dodatkowym legalnym
   ruchem; oba klienty odtwarzają ten sam stan Czwórek.
3. **Odtwarzanie po przerwanym wielostronicowym odczycie** — wykonano 260
   rzeczywistych akcji Ninety-Nine, włącznie z rozdaniami i atomowym play/draw.
   Świeży magazyn klienta przerwał odczyt na drugiej stronie. Po ponowieniu
   odtworzył identyczny stan: ręce, stos, punkty i kolejkę, bez pominiętych ani
   powielonych zdarzeń.

Nie traktować tych wyników jako dowodu bezpieczeństwa dowolnej kolejności
zdarzeń lub wszystkich gier. Nie przywracano celowo wycofanych zasad przerywania
partii po wyjściu gracza ani migracji mastera.

## Reprodukcje i ograniczenia weryfikacji

Skrypt poza repozytorium: `diagnostics/audit-2026-09-10/extended_sync_probes.rb`.
Uruchamia produkcyjne klasy z lokalnym brokerem, który rozdziela zapis,
potwierdzenie, powiadomienia oraz stronicowane odczyty. Znacznik `PASS` oznacza
oczekiwane prawidłowe zachowanie, a `REPRODUCED` — potwierdzenie nadal
istniejącego problemu. Nie są to testy stwierdzające naprawienie tych usterek.

Nie mierzono dostępności rzeczywistego serwera, transmisji przez sieć ani
zachowania czytnika ekranu. Rzeczywiste klienty są nadal potrzebne zwłaszcza
do weryfikacji zdarzeń hosta, rozłączeń i zachowania aktywnego pola tekstowego.
