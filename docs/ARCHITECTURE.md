# Architektura

## Przepływ danych

ELTEN uruchamia `EltenGameRoom` z pliku `__app.rb`. Program tworzy dostęp do
tabel serwerowych, repozytoria stołów i partii oraz transport LiveSessions.
Stan partii nie jest przechowywany jako jeden mutowany obiekt. Serwer zawiera
uporządkowane zdarzenia, a klasa danej gry odtwarza z nich `Replay`.

Typowy ruch przechodzi następującą drogę:

1. wspólna powierzchnia gry tworzy opis akcji;
2. gra waliduje akcję w `action_for` i zwraca `ActionPlan`;
3. `GameRepository` dopisuje zdarzenia;
4. transport powiadamia pozostałych uczestników przez LiveSessions;
5. każdy klient odtwarza stan i aktualizuje formularz dopiero po rzeczywistej
   zmianie.

To rozdzielenie jest ważne: interfejs nie ustala zasad, a transport nie
interpretuje ruchów.

## Warstwy

### Manifest i składanie programu

`__app.rb` zawiera metadane ELTEN-a, deklarację ośmiu tabel serwerowych, rejestr
gier i główną klasę programu. To miejsce składa zależności, ale reguły gier
powinny pozostać w `games/`.

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

Skład rozpoczętej partii jest utrwalany w `game_sessions.players_json`, dzięki
czemu miejsca graczy są stabilne przez całą partię.

### Transport

`GameRoomTransport` używa natywnego API LiveSessions. Signal pozostał jedynie
jako bootstrap ręcznego dołączania do publicznego stołu: właściciel otrzymuje
prośbę i wysyła natywne zaproszenie do LiveSession. Zmiany stołu, start partii i
ruchy nie powinny wracać do transportu opartego na Signals.

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

- serwerowe zdarzenia są źródłem prawdy;
- każdy ruch jest ponownie walidowany przy odtwarzaniu;
- klient nie zapisuje uczestnika przed potwierdzeniem LiveSessions;
- formularz odświeża się tylko po rzeczywistej zmianie stanu;
- bot nie omija reguł ani ścieżki zapisu człowieka;
- zmiana wspólnego szkieletu wymaga testu co najmniej jednej gry z każdej
  dotkniętej rodziny.
