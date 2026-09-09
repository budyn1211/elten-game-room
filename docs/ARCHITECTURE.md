# Architektura

## Przepływ danych

ELTEN uruchamia `EltenGameRoom` z pliku `__app.rb`. Program tworzy repozytoria
stołów i partii nad jednym magazynem LiveSessions. Każdy widoczny stół jest
publiczną sesją, a jej stos jest autorytatywną, uporządkowaną historią pokoju,
czatu, rozpoczętych partii i ruchów.
Stan partii nie jest przechowywany jako jeden mutowany obiekt. Serwer zawiera
uporządkowane zdarzenia, a klasa danej gry odtwarza z nich `Replay`.

Typowy ruch przechodzi następującą drogę:

1. wspólna powierzchnia gry tworzy opis akcji;
2. gra waliduje akcję w `action_for` i zwraca `ActionPlan`;
3. `GameRepository` dopisuje cały plan ruchu jako jeden atomowy wpis stosu;
4. LiveSessions dostarcza ten sam wpis pozostałym uczestnikom;
5. każdy klient odtwarza stan i aktualizuje formularz dopiero po rzeczywistej
   zmianie.

To rozdzielenie jest ważne: interfejs nie ustala zasad, a transport nie
interpretuje ruchów.

## Warstwy

### Manifest i składanie programu

`__app.rb` zawiera metadane ELTEN-a, deklarację dwóch trwałych tabel pomocniczych,
rejestr gier i główną klasę programu. Tabele służą wyłącznie rejestracji
użytkowników Game Roomu i krótkim ogłoszeniom globalnego lobby; nie przechowują
stołów, członkostwa, zaproszeń, partii ani ruchów.

### Dostęp do tabel pomocniczych

Każde wywołanie `program_main` oraz wejście przez powiadomienie ponownie
sprawdza dostęp do `game_room_users` minimalnym odczytem dla bieżącego konta.
`GameRoomServerTables` współdzieli wynik z istniejącymi uchwytami tabel.
Detekcja korzysta z odpowiedzi serwera: kod
`apps.tables.stamp_required` oznacza tryb deweloperski bez tabel.

Po odmowie nie są wykonywane dalsze odczyty ani zapisy tabel pomocniczych.
Nie uruchamia się odpytywanie globalnej historii lobby, a próba wysłania
zaproszenia kończy się informacją o ograniczeniu. Discovery, rozgrywka,
odbieranie zaproszeń oraz historia i czat pokoju nadal korzystają z LiveSessions.
Timeout i inne błędy również wstrzymują operacje tabelowe do kolejnego wejścia,
ale są przedstawiane jako problem sprawdzenia dostępu, nie tryb deweloperski.
Ponowne uruchomienie maina może przywrócić funkcje tabelowe bez tworzenia
nowej instancji aplikacji.

### Modele gier

`GameRoomGames::Base` definiuje wspólną umowę: identyfikator, nazwę, zasady,
liczbę graczy, opcje, walidację, start partii, replay, akcje, powierzchnię,
historię i opcjonalną strategię bota. `TurnBasedBoardGame` dodaje standardowy
model ruchu figura–pole dla planszowych gier turowych.

Każda gra musi deterministycznie odtworzyć ten sam stan z tych samych zdarzeń.
Losowość powinna być reprezentowana przez zdarzenie lub kontrolowane źródło z
`game_random.rb`.

### Wspólny interfejs

`GameScreen`, `GameRoomLayout`, `GameRoomShortcuts` i `GameSurfaces` budują
dostępny formularz partii. Powierzchnie obejmują między innymi planszę z
figurami, tor pionków, rękę kart, tacę kości, panel poleceń, arkusz odpowiedzi i
widok oceniania.

Gra opisuje powierzchnię i akcje. Nie powinna bez potrzeby tworzyć własnego
formularza, przechwytywać systemowych klawiszy ani ręcznie sterować pętlą UI.

### Stoły, uczestnicy i cykl partii

`game_room_screens.rb`, `game_lifecycle.rb`, `game_participants.rb` oraz
repozytoria lobby i aktywności obsługują tworzenie stołu, dołączanie, boty,
rozpoczęcie, zakończenie i następną partię.

Skład rozpoczętej partii jest utrwalany w zdarzeniu `game_started` na stosie
sesji, dzięki czemu miejsca graczy są stabilne przez całą partię.

### Transport

`GameRoomLiveSessionStore` używa natywnego API ELTEN-a 3.0.3. Publiczne
wyszukiwanie sesji zastępuje tabelę stołów, bezpośrednie dołączenie do odkrytej
sesji zastępuje bootstrap przez Signals, a natywne zaproszenia zastępują własne
tabele zaproszeń. Zmiany pokoju, czat, start partii i ruchy trafiają do jednego
stosu i mają wspólną kolejność. Zamknięcie sesji usuwa stół z listy bez osobnego
sprzątania rekordu.

Widoczna historia nadal jest dzielona na `Wszystko`, `Gra`, `Czat` i
`Zdarzenia pokoju`. Podział jest wyłącznie filtrem prezentacji nad jednym
chronologicznym strumieniem i nie rozdziela ponownie danych na osobne magazyny.

`GameRoomSync::Controller` zbiera powiadomienia i uruchamia kontrolowane
odzyskanie stanu po błędzie lub luce. Nie należy zastępować tego częstym,
okresowym odpytywaniem serwera.

### Boty

`game_bots.rb` definiuje wspólną rejestrację i uruchamianie strategii.
Planowanie nie zapisuje ruchu bezpośrednio: wybiera legalną akcję, która
przechodzi przez tę samą walidację gry i repozytorium co akcja człowieka.
Specjalizowane strategie znajdują się w plikach `*_strategy.rb`; wspólny
przeszukiwacz drzewa w `game_tree_search.rb`.

### Treści i języki

`game_content.rb` oraz `content/languages.rb` obsługują wersjonowane pakiety
treści i warianty językowe. Komunikaty interfejsu korzystają z funkcji `_()` i
są dostarczane w `locale/PL.mo`.

## Niezmienniki, których trzeba pilnować

- stos LiveSessions jest źródłem prawdy dla pokoju i partii;
- każdy ruch jest ponownie walidowany przy odtwarzaniu;
- klient nie zapisuje uczestnika przed potwierdzeniem LiveSessions;
- formularz odświeża się tylko po rzeczywistej zmianie stanu;
- bot nie omija reguł ani ścieżki zapisu człowieka;
- zmiana wspólnego szkieletu wymaga testu co najmniej jednej gry z każdej
  dotkniętej rodziny.
