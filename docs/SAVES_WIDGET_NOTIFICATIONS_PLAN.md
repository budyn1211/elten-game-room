# Plan poprawek — widget, powiadomienia, opóźnienie botów i Reversi

Stan aktualny, 17 września 2026: wszystkie cztery punkty wdrożone lokalnie
na późniejsze polecenie użytkownika i sprawdzone celowanymi testami.
Zaakceptowana mała próba serwerowa została zakończona i posprzątana;
szczegóły w `TABLE_WATCH_2_VERIFICATION.md`. Wydanie użytkownik wstrzymał
do dodania kolejnych gier. Kontrola punktów:
`IMPLEMENTATION_2_0_VERIFICATION.md`. Poniższe zastrzeżenia „tylko plan”
i opisy kodu sprzed wdrożenia zachowują historyczne uzasadnienie projektu.
Podstawa: Game Room 1.1.10/build 226 i bieżące źródła klienta ELTEN-a
odczytane przez MCP.

## Aktualny zakres

1. Widget bez pobierania listy przy strzałkach.
2. Powiadomienia o nowych publicznych stołach wybranych gier.
3. Wspólne ustawienie opóźnienia bota we wszystkich grach: 0–5 sekund.
4. Reversi: dobrowolny pas i opcjonalny obowiązek bicia, również dla botów.

Na polecenie użytkownika usunięto z bieżącego zakresu zapisywanie partii
na serwerze (dawny punkt 3 podsumowania rozmowy; dawniej sekcja 1
tego dokumentu). Obecne zapisy lokalne działają bez zmian. Nie usuwać
plików użytkownika, tabel ani wyników wcześniejszych prób.
Raport historyczny pozostaje w `SAVED_GAME_STORAGE_FEASIBILITY.md`.
Nie szukać dalej magazynu ani nie wdrażać dzielenia zapisów na rekordy
bez nowego polecenia.

Projekty gier pozostają osobne: `RUMMY_DESIGN.md`, `DOMINO_DESIGN.md`
i `MEXICAN_TRAIN_DESIGN.md`. Nowy punkt 3 ujednolica ich opóźnienie botów,
nie zmienia pozostałych uzgodnień ani zasad rozgrywki.
Ten dokument nie upoważnia do zmian kodu, schematu serwera, wysyłania
rzeczywistych powiadomień, budowania, podpisywania ani publikowania.
Użytkownik zaakceptował ten kierunek jako plan, w tym osobną tabelę
subskrypcji z jednym małym rekordem na konto. Akceptacja nie jest zgodą
na implementację ani testowe zmiany serwera; zachowuje opisane ograniczenia
i potrzebę weryfikacji. Dopisanie opóźnienia botów również jest wyłącznie
zmianą planu, bez zgody na implementację. Tak samo dopisane później
warianty Reversi są na razie tylko planem.

## 1. Widget bez pobierania listy podczas naciskania strzałek

### Ustalona przyczyna w kodzie

`GameRoomWidget::TableList#focus` w `lib/game_room_widget.rb` wywołuje
`refresh` z ograniczeniem około 0,5 sekundy. Ładowanie prowadzi przez
`load_widget_table_snapshots` w `__app.rb` do wyszukiwania aktywnych sesji.

W sprawdzonym kodzie ELTEN-a `ListBox#update` wywołuje `focus` również
podczas poruszania się po pozycjach. Nie jest to wyłącznie wejście do
kontrolki Tabulatorem. Z tego wynika możliwość ponownego pobierania
przy strzałkach. Nie każde bardzo szybkie naciśnięcie musi wysłać żądanie;
obecne ograniczenie czasowe nie usuwa jednak niewłaściwego powiązania.
To ustalenie z kodu, nie pomiar na rzeczywistym kliencie w tej sesji.

### Uzgodnione wejście i R; propozycja odświeżania przy aktywnym widgecie

- Strzałki i pozostała nawigacja poruszają się tylko po już pobranej liście:
  zero żądań wywołanych samym przeglądaniem pozycji.
- Zgodnie z odpowiedzią użytkownika rzeczywiste wejście do widgetu
  odświeża listę. Zachować także ręczne odświeżenie pod R. Zastępuje to
  wcześniejszą propozycję 30-sekundowego wieku pamięci przy wejściu.
- Na pytanie użytkownika proponujemy dodatkowo pobieranie co 5 sekund,
  ale wyłącznie wtedy, gdy widget jest aktualnie obsługiwaną kontrolką
  głównego ekranu. Samo wyświetlanie widgetu nie wystarcza. Po przejściu
  Tabulatorem gdzie indziej, otwarciu gry, forum lub okna dialogowego
  nie rozpoczynać kolejnych automatycznych pobrań. Proponujemy również
  wstrzymanie ich przy zminimalizowanym lub nieaktywnym oknie ELTEN-a.
- Sprawdzony `Scene_Main#update_current_main_control` wywołuje `update`
  jedynie kontrolki bieżącej sekcji. Tam można lekko sprawdzić upływ czasu,
  bez żądania przy każdej klatce. Rzeczywiste pobranie zlecać zarządzanemu
  zadaniu poza pętlą UI. Nie podłączać tego do każdego `focus`, który nadal
  może być wywoływany przez strzałki. Nie zakładać zdarzenia `blur`:
  sprawdzony główny ekran nie emituje go przy każdym przejściu sekcji.
- Powrót ze stołu jest ponownym wejściem. Wejście, R i termin automatyczny
  korzystają z jednego mechanizmu, bez dwóch równoczesnych pobrań.
  Po odświeżeniu wyznaczyć nowy termin; nie nadrabiać w serii terminów
  pominiętych podczas nieobecności na widgecie.
- Jedno pobieranie naraz, z łączeniem powtórnych zleceń i ograniczeniem
  częstotliwości. Gdy sieć jest wolna lub zwraca ograniczenie żądań,
  nie uruchamiać nowych co 5 sekund mimo trwającego pobierania: poczekać
  lub wydłużyć odstęp. Wyjście z widgetu nie cofnie już wysłanego żądania,
  ale zatrzymuje planowanie następnych i odczyty jego późnego wyniku.
- Po otrzymaniu wyniku zachować stół zaznaczony w chwili zastosowania
  wyniku, nie sprzed rozpoczęcia pobierania, według jego tożsamości.
  Nie odtwarzać niezmienionej kontrolki, nie przejmować fokusu i nie
  wypowiadać od nowa całej listy. Automatyczny cykl nie przerywa mowy
  i nie gra dźwięku. Gdy wybrany stół zniknie, wskazać najbliższy.
- Błąd pobrania nie czyści ostatniej poprawnej listy. Rozróżniać brak
  stołów od braku świeżych danych.
- Enter sprawdza aktualną dostępność i uprawnienia przed dołączeniem;
  zapis w pamięci widgetu nie gwarantuje, że stół nadal istnieje.

Naprawa ma dotyczyć Game Roomu, nie zmieniać działania wszystkich list ELTEN-a.
Pięć sekund oznacza około 12 automatycznych cykli pobierania na minutę
pozostawania na widgecie, niezależnie od liczby strzałek. To nie gwarancja
12 żądań HTTP: wyszukiwanie sesji może mieć kilka stron; wejścia i R
są dodatkowymi wyzwalaczami objętymi tą samą kontrolą częstotliwości.
Plan nie uruchamia takiego odpytywania do obsługi powiadomień z punktu 2.

## 2. Powiadomienia o nowych publicznych stołach

### Wniosek ze sprawdzenia API

Jest wykonalny kierunek bez nowej usługi serwerowej i bez okresowego
pobierania stołów przez każdego odbiorcę: klient, który właśnie utworzył
publiczny stół, wysyła zwykłe powiadomienia aplikacji do zapisanych osób.
Nie wdrożono ani nie przetestowano jeszcze całego takiego przepływu.

Potwierdzone w aktualnych źródłach:

- `EltenLink::Apps.notify` przyjmuje jednego użytkownika, typ, metadane
  i `expires_in`; `Program.send_notification` jest jego publicznym wrapperem.
- Nie ma w tej metodzie listy odbiorców, subskrypcji gier, klucza
  idempotencji ani zwracanego ID powiadomienia; wrapper zwraca true.
  Nie zakładać serwerowego „wyślij raz do wszystkich obserwujących”.
- `Programs.receive_app_notification` i `map_app_notification` kierują
  zdarzenie do załadowanej klasy programu, nie tylko aktywnego okna gry.
  Dzięki temu odbiór może działać na forum lub głównym ekranie ELTEN-a.
- `AppTable.select/insert/update` obsługują małe rekordy preferencji.
  Ograniczenie miejsca na pliki AppResources nie wyklucza takich rekordów.
- `EltenLink::Users.online(client)` daje zbiorczą listę kont online.
  Nie trzeba pytać o każdą osobę oddzielnie.
- Game Room już ma własne powiadomienia zaproszeń, dźwięk notice,
  kontrolę głośności i standardowe dołączanie do publicznego stołu.

Nie znaleziono gotowego serwerowego abonamentu na tworzenie LiveSessions
ani nasłuchiwania zmian tabeli dla wszystkich zainteresowanych. Obecna
historia lobby odpyta tabelę `table_activity`; nie jest strumieniem,
który sam dociera do osób poza oknem programu. Nie rozszerzać tego
odpytywania na wszystkich w tle ani nie zastępować go Signals.

### Ustawienia i zachowanie dla użytkownika

- W „Ustawieniach powiadomień”: „Powiadamiaj o nowych stołach” i lista gier
  z polami wyboru, obsługiwana strzałkami i Spacją. Domyślnie nic nie
  zaznaczone. Pusta lista wyboru wyłącza funkcję.
- Wybór jest niezależny od listy widgetu, mówionych komunikatów lobby
  oraz filtra nadawców zaproszeń. „Zaproszenia tylko od kontaktów”
  nie oznacza automatycznie „nowe stoły tylko kontaktów”.
- Propozycja: wybór gier zapisywany na koncie jako mała konfiguracja
  subskrypcji, a nie archiwum partii. Ustawienia odczytują ją przy
  otwarciu i zapisują dopiero po „Zapisz”; Anuluj nie wysyła zmian.
- Po zapisaniu nowych ustawień nie ogłaszać stołów już istniejących.
- Propozycja: powiadamiać osoby wskazane jako online przy tworzeniu
  stołu. Jest to chwilowy stan, nie obietnica, że użytkownik nadal jest
  przy komputerze. Osoba logująca się później korzysta z widgetu/listy,
  bez zaległego dzwonienia za stoły sprzed jej logowania.
- Przykładowy wpis: „Nowy stół: Tysiąc, papierek”, z `notice.ogg`.
  Respektować głośność wszystkich dźwięków i powiadomień Game Roomu
  oraz zwykłe ustawienia powiadomień/nieprzeszkadzania ELTEN-a.
- Nowe powiadomienie nie otwiera gry, nie przesuwa kursora i nie wymusza
  osobnej mowy przerywającej partię; odbiorca używa zwykłego mechanizmu
  powiadomień hosta. Nie dublować tego samego ogłoszenia z komunikatem
  „utworzono stół” w lobby, gdy oba filtry są włączone.
- Enter na wpisie sprawdza ten konkretny stół i przechodzi zwykłą
  ścieżką dołączania. Jeśli użytkownik jest przy innym stole, zachować
  obecne pytanie o opuszczenie; nigdy nie przenosić go automatycznie.
- To nie jest zaproszenie: nie rezerwuje miejsca, nie nadaje uprawnień
  i nie otwiera prywatnej sesji. Nie dodawać „Przyjmij/Odrzuć” ani
  technicznej odpowiedzi dla właściciela.

### Mała lista subskrypcji

Proponowana osobna tabela `table_watch_preferences` (nazwa projektowa,
obecnie nie istnieje). Jedna logiczna konfiguracja na konto: nazwa
użytkownika, tablica stabilnych ID wybranych gier zakodowana jako krótki
JSON oraz wersja formatu. Właścicielem i podstawą tożsamości jest
serwerowe `__insertion_user`, nie samo edytowalne pole username.
Aktualizować tylko zmienioną konfigurację, nie pisać przy każdej strzałce,
wejściu do gry czy odebraniu powiadomienia.

Lista musi być czytelna dla aplikacji tworzącej publiczny stół, bo to ona
ustala odbiorców. To jawny koszt tego rozwiązania: zainteresowanie daną
grą nie będzie tajne przed innymi klientami Game Roomu. Nie obiecywać
prywatnych subskrypcji przy rozsyłaniu z cudzych klientów ani nie
utożsamiać `protected` z ukrywaniem odczytu. Opisać tę cechę przy opcji.

Wybrano jeden mały rekord na konto zamiast osobnego wiersza dla każdej
zaznaczonej gry. Klient tworzący stół pobiera stronicowaną listę tych
małych konfiguracji i lokalnie wybiera zainteresowanych konkretną grą.
Nie twierdzić, że serwer filtruje zawartość JSON-a, ani nie dopisywać
niepotwierdzonych operatorów do `where`. Nie jest to lista wszystkich
zarejestrowanych użytkowników ELTEN-a; są to zapisy funkcji subskrypcji.

Przy tworzeniu pierwszego rekordu użyć wzorca kontroli autora z
`GameRoomUserRegistry`. Nie zakładać, że samo `upsert` gwarantuje jeden
rekord na konto. Jeśli równoczesny zapis z dwóch urządzeń stworzy
duplikaty, odczyt wybiera deterministycznie ten sam rekord (najmniejsze
serwerowe ID dla danego autora), a właściciel przy zapisie uzgadnia
konfigurację w tym rekordzie i sprząta wyłącznie własne nadmiarowe wpisy.
Odbiorców zawsze deduplikować po nazwie konta bez uwzględniania wielkości
liter. Nie opierać rozstrzygnięć na zegarze komputera.

Przy starcie załadowanej aplikacji pobrać własną konfigurację raz, poza UI,
nie nadpisując serwera dawną lokalną kopią. Odczyt przy otwarciu ustawień
ponawia synchronizację. Nie wprowadzać stałego odpytywania preferencji.
Niemodyfikowane otwarcie ustawień niczego nie zapisuje. Zmiana na jednym
komputerze wpływa na dobór odbiorców kolejnych stołów, ale bez serwerowych
rewizji/CAS nie obiecywać scalania dwóch równoczesnych edycji ani idealnie
natychmiastowego wyciszenia drugiego już działającego klienta.

### Dokładny przebieg utworzenia stołu

1. Standardowa ścieżka tworzy stół i LiveSession. Dopiero potwierdzone
   utworzenie nowego publicznego stołu zleca jedną pracę w tle, oznaczoną
   trwałym identyfikatorem tej sesji. Nie zlecać po zwróceniu „już masz stół”.
2. Wykluczyć prywatny stół i wznowienie zapisanej partii czekające na dawny
   skład. Nie alarmować po dołączeniu gracza, dodaniu bota, nowym rozdaniu,
   ponownym otwarciu pokoju po partii ani odtworzeniu połączenia.
3. Praca pobiera krótkie konfiguracje subskrypcji i raz zbiorczą listę
   online. Wybiera pasujące, poprawne wpisy, odejmuje twórcę stołu
   i usuwa powtórzenia. Brak zainteresowanych kończy pracę bez wysyłki.
4. Wysyła osobne `Apps.notify` do wybranych kont przez klienta
   niezależnego od pętli UI. Nowy typ: `game_room.table_created`.
   To nazwa projektowana w Game Roomie, nie istniejący typ systemowy.
5. Metadane: wersja formatu, stabilne ID gry, identyfikator LiveSession,
   identyfikator stołu i czas ważności. Klucz zdarzenia wynika z
   „utworzenie + identyfikator sesji”, a nie z nazwy właściciela.
   Wyświetlaną nazwę gry tłumaczy odbiorca z ID. Nadawca pochodzi
   z uwierzytelnionego obiektu powiadomienia, nie z dowolnego tekstu.
6. Jedna ograniczona kolejka aplikacji, bez uruchamiania wątku na odbiorcę.
   Nie przytrzymywać blokady synchronizacji pokoju i nie czekać na wysyłkę,
   żeby pozwolić właścicielowi grać. Zmiana okna nie kończy pracy, natomiast
   zamknięcie stołu, rozpoczęcie partii lub zakończenie ELTEN-a zatrzymuje
   rozsyłanie pozostałych nieaktualnych ogłoszeń.
7. Propozycja początkowego tempa: najwyżej 2 wysłania na sekundę w skali
   tej kopii aplikacji, z możliwością zmniejszenia po pomiarach. To nasz
   limit ochronny, NIE poznany limit serwera. Odpowiedź 429 wymaga przerwy;
   respektować dostępny czas ponowienia, bez serii natychmiastowych prób.
   Błąd powiadomień nie może przerywać tworzenia stołu ani partii.

Praca przy jednym stole to w przybliżeniu P odczytów stron preferencji,
1 odczyt online i N wysłań do N zainteresowanych osób. Nie „jedno
żądanie do wszystkich”. Odbiorca nie odpytuje cyklicznie listy stołów;
wykorzystuje istniejący odbiór powiadomień ELTEN-a. Widgetowy cykl
5 sekund pozostaje zupełnie osobnym mechanizmem.

### Odbiór, powtórzenia i wejście

- Walidować typ, wersję, długości, grę, identyfikatory, nadawcę i termin.
  Nie wykonywać kodu ani nie używać dowolnego URL-a z metadanych.
- Odbiór wykorzystuje załadowaną klasę programu także poza Game Roomem.
  Ciężka praca i odczyty sieciowe nie mogą trafić do synchronicznego
  `map_notification`, wywoływanego także przy przeglądaniu listy.
- Raz zaakceptowane ogłoszenie danej sesji nie może ponownie brzęczeć
  po odświeżeniu listy lub ponownym dostarczeniu. Zachować ograniczoną
  pamięć ostatnich kluczy zdarzeń oddzielnie dla kont; przy restartach
  wykorzystać mały lokalny zapis identyfikatorów, nie danych partii.
  Na dwóch jednocześnie działających komputerach to samo konto może
  usłyszeć po jednym sygnale na każdym — brak gwarancji jednego dźwięku
  w skali wszystkich urządzeń.
- `Apps.notify` nie udostępnia potwierdzonej idempotencji. Po niepewnym
  wyniku wysyłki nie obiecywać dostarczenia dokładnie raz ani bezmyślnie
  ponawiać do wszystkich. W pierwszej wersji nie ponawiać wysyłki,
  która mogła już zostać przyjęta; jawne odrzucenie przez limit można
  ponowić dopiero po przerwie, o ile ogłoszenie jest nadal aktualne.
  Deduplikacja odbiorcy jest dodatkową ochroną, nie serwerową gwarancją.
- Przy wejściu użyć aktualnego publicznego discovery i zweryfikować
  zgodność sesji, gry oraz właściciela. Nie przyłączać fikcyjnie klienta
  do wielu sesji w celu sprawdzenia powiadomień.
- Obsłużyć „stół zamknięty”, „brak miejsc”, błąd sieci i już trwającą grę
  tak samo jak przy zwykłym dołączaniu. Nie zakładać, że `can_join?`
  oznacza oczekiwanie na graczy albo że liczba miejsc jest nadal aktualna.
- Po udanym wejściu z powiadomienia, widgetu lub listy rozliczyć ogłoszenia
  tej konkretnej sesji. Nie ruszać innych powiadomień ani zaproszeń
  do pozostałych stołów; obecna obsługa zaproszeń zachowuje swoje reguły.
- Nie zmieniać scen ani lokalnych wyborów użytkownika samym nadejściem
  powiadomienia. Zachować dotychczasowy sposób wychodzenia z innego stołu.

### Aktualność i wygasanie — propozycja

Proponowany termin: 5 minut od utworzenia stołu, z `expires_in` ustawionym
na pozostały czas, nie na nowe 5 minut dla każdej opóźnionej wysyłki.
Nie ponawiać/rozsyłać po terminie ani po rozpoczęciu partii.
Nie wysyłać nowego ogłoszenia tylko dlatego, że poprzednie wygasło.
Termin przyjmować i sprawdzać względem czasu serwera używanego w aplikacji,
nie wyłącznie zegara systemowego nadawcy.

Obecne źródła zawierają kontrolę expiration, ale wcześniejsze zgłoszenie
starych zaproszeń na głównym ekranie nie jest zamknięte. Dlatego samo
ustawienie expires_in nie jest dowodem, że wpis na pewno zniknie po
dokładnie 300 sekundach. Test gotowej funkcji ma objąć tę ścieżkę.

Dla NOWEGO typu ogłoszeń projekt zakłada filtrowanie wygasłych wpisów
i duplikatów przed zbudowaniem listy/pobraniem dźwięku, bez pustych pozycji.
Nie wystarcza zwrócić nil z `map_notification`: host ma wtedy prezentację
zastępczą. Oprzeć wąski filtr tylko tego typu na istniejącym wzorcu mostu
Game Roomu, sprawdzając bieżące źródła NotificationGroups przy wdrażaniu.
Gdy wpis wygaśnie podczas pobytu na liście, odświeżyć ją lokalnie bez
odpytywania stołów, przesuwania fokusu i blokowania UI. Osobno sprawdzić
ponowne wejście, ręczne odświeżenie i historię; stare historyczne zdarzenie
może pozostać historią, lecz nie aktywną zachętą do dołączenia.

Nie poprawiać przy tej okazji globalnego wygasania wszystkich powiadomień
ELTEN-a ani wcześniejszego odłożonego błędu zaproszeń. Zamknięcie stołu
przed terminem nie gwarantuje natychmiastowego usunięcia wpisu u wszystkich:
API wysyłania nie zwraca listy ID do wycofania. Aktualność jest ostatecznie
sprawdzana przy dołączaniu; krótki termin ogranicza stare ogłoszenia.

### Granice rozwiązania

- Wymaga zaktualizowanego klienta tworzącego stół. Starsze wydania nie
  wyślą ogłoszenia; bez odpytywania lub zmian serwera nie wykryjemy
  niezawodnie ich stołów.
- Twórca wysyła po jednym żądaniu na odbiorcę. To sensowny kandydat dla
  niewielkiej społeczności, nie równoważnik serwerowego masowego abonamentu.
  Przy większej skali, limitach i potrzebie pewnej dostawy potrzebna jest
  obsługa po stronie serwera, nie więcej odpytywania u klientów.
- Awaria/zamknięcie klienta nadawcy może zostawić niedostarczone ogłoszenia.
  Nie powstaje trwały, niezależny serwerowy dyspozytor. Błąd nie rusza gry.
- Lista online może być opóźniona i nie oznacza uruchomionego Game Roomu
  w kompatybilnej wersji. Nie gwarantować dostarczenia do każdego online.
- Dźwięk jest możliwy przy działającym ELTEN-ie i załadowanym rozszerzeniu.
  Nie jest to powiadomienie systemowe działające przy wyłączonym programie.
- Subskrypcje są odczytywane przez klienta zakładającego stół. Użytkownik
  musi wiedzieć, że to nie jest prywatna lista zainteresowań.

## 3. Opóźnienie bota we wszystkich grach

### Uzgodniony zakres

- Wszystkie gry obsługujące boty mają wspólne liczbowe ustawienie stołu:
  „Opóźnienie bota w sekundach (0–5); 0 wyłącza opóźnienie”.
- 0 oznacza brak celowej pauzy, a nie wyłączenie bota. Pozostaje rzeczywisty
  czas obliczenia i przesłania ruchu; nie obiecywać natychmiastowej reakcji.
- W UNO i Makao wartość domyślna nadal wynosi 1 sekundę.
- Dla pozostałych gier proponowana wartość domyślna to 0 sekund, aby samo
  dodanie ustawienia nie narzucało dodatkowego oczekiwania. Użytkownik
  osobno wskazał domyślne wartości tylko dla UNO i Makao.
- Opcja ma obejmować również przyszłe gry korzystające ze wspólnego
  szkieletu, w tym Rummy, Domino i Mexican Train. Nie oznacza dodawania
  botów do gier, które ich nie obsługują, ani trybu wszechwiedzącego.

### Wspólny mechanizm i zgodność

Przegląd obecnego kodu potwierdził wspólne planowanie oczekiwania w
`lib/game_screen.rb` i metodę `Base#bot_move_delay`, obecnie zwracającą 0.
UNO i Makao definiują własne pole `bot_delay` z zakresem 1–5, domyślnie 1.
Ich walidacja i wykonanie wymagają rozszerzenia: samo dopuszczenie zera
w formularzu nie wystarczy, bo wykonanie obecnie podnosi minimum do 1.

Przy przyszłym wdrażaniu ujednolicić definicję, walidację i obsługę tej
opcji w szkielecie. Nie tworzyć osobnych kopii pola ani mechanizmu zegara
w każdej grze. Ustawienie ma trafiać do rzeczywistej konfiguracji stołu,
zapisu/wznowienia i wspólnego opisu pod Ctrl+R; nie dodawać drugiej,
niezależnej preferencji lokalnej. Uaktualnić opisy zasad oraz PL/EN.
Zachować poprawne zapisane wartości 1–5 w UNO i Makao; brak pola oznacza
wartość domyślną danej gry, natomiast jawne 0 musi pozostać zerem.

Pauza nie może blokować interfejsu, czatu, synchronizacji ani dozwolonych
reakcji ludzi podczas ruchu bota, w tym UNO/intercepcji i zgłoszenia Makao.
Nie dodawać odpytywania serwera ani zdarzeń sieciowych dla odliczania.
Nie zmieniać strategii, budżetu obliczeń ani jakości wyboru ruchu.
To regulacja tempa, nie rozwiązanie osobnego problemu ciężkich obliczeń.

W grach z limitem czasu zachować ochronę przed przekroczeniem terminu
przez samą pauzę: walidować ją względem thinking time i skracać oczekiwanie
przy zbliżającym się terminie. Nie przedłużać przy tym tury ani nie
gwarantować terminowej dostawy przy dowolnie wolnej sieci. Po zmianie
rzeczywistego ruchu/stanu sprawdzić aktualność planu przed wysłaniem;
zwykłe odświeżenie UI nie może rozpoczynać odliczania od nowa.
Zachować uzgodnione wyjątki faz, np. bez dodatkowej pauzy przed wyborem
koloru przez bota UNO i bez pauzy przed każdą kartą jednego planu Rummy.

## 4. Reversi — pasowanie i obowiązek bicia

### Dwa niezależne pola wyboru

- „Zezwalaj na pasowanie” (`Allow passing`), domyślnie zaznaczone,
  zgodnie z przekazanym ustawieniem. Pozwala świadomie oddać turę także
  wtedy, gdy istnieje legalne postawienie pionka. Po wyłączeniu nie wolno
  dobrowolnie pasować, mając ruch; brak legalnego ruchu nadal powoduje
  automatyczny pas, niezależnie od tego pola.
- „Obowiązkowe bicie” (`Mandatory capture`), domyślnie zaznaczone.
  Przy włączonej opcji postawienie pionka musi odwrócić co najmniej jeden
  pionek przeciwnika. Po wyłączeniu wolno postawić pionek bez odwracania,
  ale wyłącznie na pustym polu bezpośrednio obok już istniejącego pionka.
  Nie wolno stawiać w dowolnym, odizolowanym miejscu planszy.

Interpretacja sąsiedztwa do planu: jedno z ośmiu pól wokół, czyli poziomo,
pionowo lub po przekątnej, przy pionku dowolnego koloru. To doprecyzowanie
określenia użytkownika „obok innego pionka”, nie osobna zweryfikowana
reguła QC. Nie wymagać sąsiedztwa wyłącznie z własnym pionkiem.
Wyłączenie obowiązku bicia nie wyłącza samego odwracania: jeżeli ruch
zamyka pionki przeciwnika, nadal odwraca je we wszystkich właściwych
kierunkach. Nie dodawać wyboru „odwróć / nie odwracaj”.

### Zasady, interfejs i odtwarzanie

- Użyć istniejących definicji opcji stołu; opisać oba pola krótko w PL/EN,
  zasadach i wspólnym odczycie ustawień Ctrl+R. Uzgodniony skrót P pomija
  własną turę, gdy pas jest dozwolony. Uwzględnić go w dynamicznym F1;
  działa w polu gry, nie przechwytuje litery podczas pisania na czacie.
- Ta sama definicja legalności ma obowiązywać człowieka, listę ruchów
  bota, symulację i odtwarzanie zdarzeń. Nie wystarczy zmienić formularza:
  obecny `games/reversi.rb` odrzuca brak odwróconych pionków zarówno
  w `action_for`, jak i `apply_events!`; tak samo filtruje `available_fields`.
- Pas musi przechodzić zwykłą walidację i historię gry, nie być wyłącznie
  lokalnym przestawieniem tury. Komunikat dobrowolnego pasa nie może
  twierdzić, że gracz nie miał ruchu. Przy dołożeniu bez bicia nie ogłaszać
  odwrócenia pionków, którego nie było.
- Brak ruchów i koniec partii sprawdzać według wybranego wariantu.
  Przy wyłączonym biciu brak możliwych bić nie oznacza braku ruchu.
  Dopuszczalny dobrowolny pas nie może z kolei sam uniemożliwiać wykrycia
  końca na pełnej planszy albo gdy żaden gracz nie może nic postawić.
  Sposób liczenia pionków, wygrana przewagą liczby i remis bez zmian.
- Użytkownik doprecyzował: dobrowolnie pasować można bez limitu liczby
  własnych tur. Dwa kolejne pasy, ani dowolna dłuższa ich seria, nie kończą
  partii i nie ogłaszają remisu, jeżeli nadal istnieje legalne postawienie.
  Każdy pas przekazuje turę przeciwnikowi; następny własny pas jest możliwy
  dopiero po powrocie tury. Nie utożsamiać odmowy ruchu z jego brakiem.
  Rzeczywisty brak postawień u obu graczy nadal kończy grę według zasad.
- Nowe opcje muszą przetrwać zapis i wznowienie. Stare archiwa bez tych
  pól odtwarzać według dawnych reguł: obowiązkowe bicie i brak dobrowolnego
  pasa. Domyślne zaznaczenie nowych stołów nie może zmieniać historii
  już zapisanej partii ani legalności jej zdarzeń.

### Boty i planowanie

Bot ma grać według tych samych dwóch ustawień, w każdej z czterech
kombinacji, a nie tylko nauczyć się nowego przycisku pasa. Generator
ruchów i całe przeszukiwanie muszą uwzględniać sąsiednie ruchy bez bicia
oraz dobrowolny pas, gdy jest dozwolony. Ruch bez bicia nie może zostać
odrzucony tylko dlatego, że nie zwiększa liczby odwróconych pionków.
Bot powinien porównywać jego pozycję wynikową z biciami i pasem, np.
zdobycie narożnika, udostępnienie dobrego pola przeciwnikowi i mobilność.

Nie zakładać, że pas jest zawsze zły, ani pasować bez porównania z ruchami.
Dotychczasowe założenia heurystyki o wymuszonych ruchach i parzystości
końcówki sprawdzić także przy opcjonalnym biciu i dobrowolnym pasowaniu.
Ograniczyć koszt dotychczasowym budżetem węzłów/czasu; większa liczba
legalnych pól nie może oznaczać nieograniczonego przeszukiwania.
Uwzględnić oba ustawienia i gracza na ruchu w kluczach pamięci ruchów
i wyszukiwania, żeby nie użyć wyniku innego wariantu. Pas nie zmienia
planszy, więc sprawdzić również cykle i zmianę gracza w planerze.
Ograniczenie przeszukiwania powtarzających się pozycji jest wyłącznie
zabezpieczeniem obliczeń bota: nie może ogłaszać końca rzeczywistej partii,
wymuszać remisu ani zakazywać kolejnych legalnych pasów.

## Weryfikacja przed wdrożeniem i wydaniem

Na tym etapie wykonano wyłącznie przegląd kodu i dokumentacji. Nie wysłano
nowych powiadomień, nie utworzono tabeli subskrypcji ani nie zmieniono
serwera. Przed uznaniem funkcji za gotową potrzebne są:

- Mały, osobno zaakceptowany test na dwóch kontach: własny rekord
  preferencji, odczyt przez nadawcę, odmowa zmiany cudzych ustawień,
  wysłanie i odebranie nowego typu na zwykłym koncie, nie tylko autora.
  Sprawdzić rzeczywiste ograniczenia serwera; nie testować masowego spamu.
- Test konta na dwóch urządzeniach: brak ponownego zapisu starej kopii
  przy logowaniu; równoczesne pierwsze rejestracje; deterministyczna
  obsługa duplikatów; jawna zmiana ustawień, błąd zapisu i ponowne pobranie.
- Tylko wybrane gry i osoby; brak prywatnych/własnych/wznawianych stołów;
  brak alarmów po włączeniu filtra dla starych stołów.
- Odbiór przy forum, innym programie, aktywnej grze i wyłączonym widgecie;
  działanie notice i głośności; brak podwójnej mowy lobby/powiadomienia.
- Brak pustych pozycji, powtórek dźwięku oraz aktywnych wygasłych wpisów;
  sprawdzenie głównego ekranu, R, ponownego wejścia i obu klientów.
- Dołączanie przez nową instancję programu, pełny/zamknięty stół,
  trwająca partia, błąd sieci i ręczne dołączenie przed kliknięciem wpisu.
- Częściowa wysyłka, niepewna odpowiedź, 429, zerwanie sieci, zamknięcie
  stołu/klienta i starszy twórca bez tej funkcji; brak wpływu na partię.
- Widget: wejście/R/5 sekund to osobne przyczyny odświeżenia, strzałki
  nie zlecają pobrań, jedno pobranie naraz, zatrzymanie poza widgetem,
  bieżący kursor po wolnej odpowiedzi, brak przerywania mowy,
  brak czyszczenia poprawnej listy po błędzie sieci.
- Opóźnienie: każda gra z botami ma jedno wspólne pole; 0/1/5 działają,
  wartości spoza zakresu są odrzucane, UNO/Makao nadal domyślnie mają 1.
  Sprawdzić zachowanie istniejących ustawień oraz zapis i wznowienie z 0.
- Oczekiwanie bota: działające UI, czat, synchronizacja i reakcje ludzi;
  brak dodatkowych żądań odliczania, ponownego czekania po odświeżeniu
  oraz wykonania nieaktualnej decyzji po zmianie stanu. Sprawdzić krótkie
  thinking time, zmianę aktora, wyjątki faz i kilka kolejnych ruchów botów.
- Reversi: wszystkie cztery kombinacje ustawień; dobrowolny pas z legalnym
  ruchem dozwolony/zabroniony; automatyczny pas przy rzeczywistym braku
  ruchu; koniec na pełnej planszy i obustronny brak postawień.
- Reversi/P: jeden pas przekazuje własną turę, nie działa za przeciwnika
  ani w polu czatu. Dwa i wiele kolejnych dobrowolnych pasów nie kończą
  partii, nie zmieniają planszy i są zgodne po replayu oraz wznowieniu.
- Reversi bez obowiązku bicia: sąsiedztwo poziome, pionowe i ukośne, własny
  i przeciwny kolor, odrzucenie zajętego/odizolowanego pola, legalne zero
  odwróceń i nadal obowiązkowe odwrócenie prawidłowo zamkniętych pionków.
- Reversi/boty: legalność i symulacja zgodne z wykonaniem, wybór korzystnego
  ruchu bez bicia, porównanie pasa z ruchem, brak cyklu przeszukiwania,
  poprawne klucze dla różnych opcji i ograniczony koszt. Celowane pozycje,
  nie setki pełnych partii. Sprawdzić replay, wznowienie i stare archiwa.

## Źródła przeglądu

Kod Game Roomu: `__app.rb` (server_app, create_table, map_notification,
notification_action), `lib/lobby_repository.rb`,
`lib/table_activity_repository.rb`, `lib/game_room_user_registry.rb`,
`lib/game_room_server_tables.rb`, `lib/invitation_notifications.rb`,
`lib/invitation_receipts.rb`, `lib/game_room_preferences.rb`,
`lib/game_room_widget.rb`.

Punkt 3: `games/base.rb`, `games/uno.rb`, `games/makao.rb`
i `lib/game_screen.rb` — odczyt obecnego planowania i walidacji opóźnienia.

Punkt 4: wymagania użytkownika oraz `games/reversi.rb` — odczyt obecnej
legalności, odtwarzania, generatora ruchów, kluczy i heurystyki bota.
Nie wykonywano testów ani nie sprawdzano tych wariantów na kliencie QC.

Aktualne wbudowane źródła ELTEN-a przez MCP, 17 września 2026:
`src/eltenlink/apps.rb` (AppTable, notify: linia 543),
`src/eltenlink/notifications.rb`, `src/eltenlink/users.rb` (online),
`src/eapi/program.rb` (AppNotification, NotificationActionScene,
map_app_notification/receive_app_notification: linie 2950–3000,
send_notification: linia 3422), `src/eapi/notifications.rb`
(wyszukane ścieżki odbioru, deduplikacji i expiration).
Dokumenty MCP `mcp`, `programming`, `api_overview`.

Źródła wyjaśniają istniejące kontrakty klienta, nie dowodzą wszystkich
zasad i limitów rzeczywistego serwera. Dlatego powyższe testy nadal
warunkują wdrożenie, mimo pozytywnego wyniku przeglądu API.
