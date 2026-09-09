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

Formularz stołu i partii ma wspólną kolejność: opcjonalna powierzchnia gry,
użytkownicy, rozpoczęcie partii, restart, czat, zdarzenia i przycisk zasad gry.
Przyciski zależą od fazy i uprawnień: rozpoczęcie jest dostępne przed pierwszą
partią, restart po jej zakończeniu, oba tylko dla właściciela. Nową sesję tworzy
standardowe repozytorium, a kontroler stołu otwiera jej ekran.
Wejście do oczekującego stołu ustawia fokus na użytkownikach. Rozpoczęcie
lub restart partii przenosi go na pierwsze pole powierzchni gry, również
po otrzymaniu nowej sesji od innego klienta. Gdy powierzchni nie ma, fokus
pozostaje na użytkownikach. Zakończenie partii przenosi fokus na użytkowników,
pozostawiając planszę dostępną przez Shift+Tab. Nie ma osobnego przycisku ani
trybu podglądu. Próby wykonania akcji nadal przechodzą przez `action_for`, które
odrzuca je z komunikatem zakończonej gry. Zwykłe aktualizacje tej samej partii zachowują
aktywną sekcję, tożsamość zaznaczonej osoby, szkic i zaznaczenie czatu oraz
przeglądaną pozycję historii.

`GameRoomLayout::Screen` zachowuje formularz, listy, przyciski i edytor czatu;
zmienia jedynie potrzebną powierzchnię gry. Identyfikator sesji pozwala zachować
zaznaczenie planszy po ponownym wejściu i wyczyścić je dla nowej partii.
Powiązania zdarzeń są wymieniane
bez mnożenia natywnych handlerów, a timery usuwane przy opuszczeniu widoku.
Zasady gry otwiera przycisk na końcu formularza lub Ctrl+F1; nie występują
w menu użytkowników. Powrót z zasad zachowuje fokus i szkic czatu.
`GameRoomParticipantMenu` wiąże natywne menu listy użytkowników: zapraszanie
użytkownika online przez Ctrl+I, zapraszanie z kontaktów przez Ctrl+Shift+I,
dodawanie komputera przez Ctrl+O i Delete na wskazanym komputerze. Skróty działają
wyłącznie na tej liście, także podczas partii i po jej zakończeniu. Menu i skróty
wywołują te same operacje. Zmiana składu sprawdza aktualny stan i uprawnienia
również po otwarciu menu.

Przyjmowanie i odrzucanie zaproszeń jest dostępne w menu kontekstowym listy
menu głównego, przez Ctrl+J i Ctrl+Shift+J. Pozycja „Zaproszenia” nadal otwiera
standardową ścieżkę przyjmowania. Powiadomienie pozwala przyjąć lub odrzucić
konkretne zaproszenie, z weryfikacją jego aktualności i usunięciem powiadomienia
po obsłużeniu. Formularze nie przechwytują globalnie skrótów zaproszeń;
nie są one dostępne z planszy, czatu ani historii.

`RoomPresentation` przechowuje identyfikator uczestnika oddzielnie od etykiety.
Gra udostępnia `participant_scores(replay)`: mapę uczestników na punkty albo
`nil`, jeśli nie prowadzi punktacji. Farkle, Tysiąc, Spades i Państwa-miasta
zwracają wyniki z odtworzonego stanu. Spades przypisuje wynik drużyny jej
członkom. Zero jest wynikiem; obserwator ani gra bez punktacji nie dostają
sztucznej etykiety punktów. Wyniki zakończonej partii pozostają przy obecnych
uczestnikach do rozpoczęcia kolejnej.

Gra opisuje powierzchnię i akcje. Nie powinna bez potrzeby tworzyć własnego
formularza, przechwytywać systemowych klawiszy ani ręcznie sterować pętlą UI.

### Stoły, uczestnicy i cykl partii

`game_room_screens.rb`, `game_lifecycle.rb`, `game_participants.rb` oraz
repozytoria lobby i aktywności obsługują tworzenie stołu, dołączanie, boty,
rozpoczęcie, zakończenie i następną partię.

Komputery w pokoju nadal wynikają z `bot_count` i mają numery od 1 do N.
Delete na dowolnym zaznaczonym komputerze wywołuje istniejącą operację
zmniejszenia ich liczby o jeden. Numeracja pozostaje ciągła, a lista zachowuje
bieżącą pozycję, o ile nadal istnieje. UI sprawdza uprawnienia, fazę partii,
limit graczy i obecność wskazanego komputera przed wywołaniem repozytorium.
Protokół Game Room pozostaje w wersji **2**, z dotychczasowym formatem danych,
discovery i zaproszeniami; refaktor interfejsu nie wymaga zmiany pozostałych
klientów.

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
