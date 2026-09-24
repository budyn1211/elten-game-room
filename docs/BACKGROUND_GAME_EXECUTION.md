# Gra turowa za innym oknem ELTEN-a

Wdrożenie w źródłach, 24 września 2026. Nie znajduje się jeszcze w podpisanej
paczce 2.0.3/build 237. Uzupełnia, a nie zastępuje naprawę opisaną w
`PARALLEL_SCENE_EVENTS.md` i wcześniejszy eksperyment
`BACKGROUND_GAME_EXPERIMENT.md`.

## Co zostało oddzielone

Natywne Wiadomości albo forum wstrzymują pętlę przykrytego `GameScreen`.
Odbiór protokołu sam w sobie nie wystarczał: aplikacja musiała jeszcze
dostarczyć callback, odtworzyć stan, wybrać dozwoloną akcję automatyczną
i zapisać ją zwykłą ścieżką. Po zatrzymaniu tej pętli gospodarz nie wykonywał
ruchu bota, a gracz mógł nie ujawnić wcześniej zatwierdzonej odpowiedzi.

`GameRoomSessionRunner` wykonuje tę część bez formularza. To jeden wykonawca
dla widocznej i przykrytej gry, nie dodatkowy bot działający obok starego.
`GameScreen` zachowuje kontrolki, obsługę klawiszy, mowę, dźwięki, fokus,
historię i dialogi. Za obcym oknem nie są aktualizowane kontrolki ani
wywoływana synteza z wątku roboczego. Odczyt i efekty już odebranych zdarzeń
obsługuje jednak aktywny wątek UI, także przed powrotem do gry. Po powrocie
ekran pokazuje potwierdzony replay, bez ponownego odczytywania tych zdarzeń.

Pong i Audio Ball nie korzystają z tego wykonawcy. Ich niezależna symulacja,
protokół pauzy, wejście i Communications pozostają bez zmian.

## Mowa i dźwięki podczas otwartych Wiadomości lub forum

Pierwsze wdrożenie wykonawcy obsługiwało model i boty, lecz prezentacja nadal
czekała na powrót do Game Roomu. Użytkownik odtworzył ten brak. Zapis jego
próby potwierdził przyrost zdarzeń modelu za Wiadomościami przy niezmienionym
kursorze prezentacji. Samo zgodne odtworzenie planszy po powrocie nie było
dowodem działania mowy ani efektów w trakcie przykrycia.

Wykonawca publikuje teraz skopiowany pakiet prezentacji po istniejącym
odczycie stanu; nie odpytuje serwera dodatkowo. `GameRoomBackgroundPresentation`
rejestruje aktywny ekran i korzysta z wąskiego mostu w `EltenAPI::UI#loop_update`.
Oryginalna metoda działa bez zmian; po niej tylko aktualny wątek UI może
przekazać gotowe zdarzenia przykrytej gry do istniejących prezenterów.
Nie jest to drugi `GameScreen#run`, globalny tick rozszerzeń ani ręczne
aktualizowanie formularza gry. Most nie czyta klawiatury i nie zmienia
aktywnego okna, fokusu, szkicu, zaznaczenia lub pozycji w historii.

Używane są te same opisy zdarzeń, przejścia tur, wynik, selektor dźwięków,
ustawienia głośności i wspólne kursory deduplikacji. Mowa ma `stop: false`
i `break_sequence: false`. Sekwencja dźwięków Statków jest kontynuowana
również bez kolejnego zdarzenia sieciowego. Ogłoszenia czasu quizu używają
tego samego zegara sesji i kluczy co widoczny ekran. Komunikaty czatu są
przekazywane tą samą ścieżką; formularz pozostaje nietknięty.

Rewanż może nadejść, gdy gracz nadal przebywa na forum. Kursor prezentacji
rozróżnia sesje, ale nie porównuje ich ID liczbowo: natywne identyfikatory
są losowe. Powrót starego widoku nie może cofnąć ogłoszonej już nowej partii.
Odgłosy wejścia/wyjścia również używają jednej projekcji uczestników, aby
stary bufor ekranu nie generował pozornego wyjścia i ponownego wejścia.

Most hosta nie przechowuje closure ze starej przestrzeni aplikacji. Jest
instalowany raz, a zarządzane rejestracje są usuwane po zamknięciu gry.
Bez aktywnej rejestracji niczego nie odczytuje ani nie odtwarza. Nie zmieniono
plików źródłowych ELTEN-a. Lokalne dialogi Krowy nadal otwiera jej widoczny
adapter, nie prezenter działający za innym oknem.

Testy tej poprawki: `game_background_presentation_test.rb` oraz
`game_background_native_input_test.rb`. Pierwszy obejmuje pełną partię,
rewanż, losowe ID, odczyt wyniku, sekwencję audio, zegar quizu, deduplikację,
czyszczenie rejestracji i 20 binarnych przeładowań przestrzeni aplikacji.
Drugi używa natywnych kontrolek, klawiatury i adaptera mowy hosta z kontrolowanym
źródłem znaków: polski tekst, kursor i zaznaczenie nie ulegają zmianie.

## Granice bezpieczeństwa

- Subskrypcja `GameRoomSessionFeed` ma własne złączane sygnały. Odczyt przez
  wykonawcę nie zużywa sygnału przeznaczonego dla ekranu.
- Dostarczane są tylko gotowe callbacki własnego endpointu. Lokalny przebieg
  co 50 ms nie oznacza odpytywania serwera. Odczyt stanu następuje po zmianie,
  przy istniejącej weryfikacji zapisu lub odzyskiwaniu połączenia.
- Model wykonawcy i model planisty są oddzielone od modelu interfejsu.
  `ActionContext` zawiera skopiowane dane, nie kontrolki. Szkic Państw-miast
  pochodzi z UI i ma identyfikator własnej rundy/fazy.
- Zachowane są `Coordinator`, `Simulation`, `TurnController`, `action_for`
  i repozytorium. Nie dodano heurystyk, kar, wyborów odpowiedzi za człowieka
  ani innej autoryzacji. Seed oraz budżety wyszukiwania bota pozostały takie
  jak w dotychczasowej ścieżce.
- Planowanie bota nie trzyma blokady zapisu. Po obliczeniu decyzji wykonawca
  dostarcza callbacki odebrane podczas obliczeń, ponownie odczytuje stan
  i odrzuca nieaktualny plan. Przechwycenie UNO lub powiedzenie Makao nie
  musi czekać na zakończenie obliczeń bota.
- Zapis akcji, zmiana sesji i operacje sieciowe ekranu mają wspólną krótką
  granicę synchronizacji. Oczekiwanie na nią odbywa się w `Tasks`, nie przez
  zablokowanie pętli UI. Nie obejmuje oczekiwania na formularz ani planisty.
- Kilka otwartych instancji tego samego konta/stołu wybiera jednego
  wykonawcę. Pierwszeństwo ma aktywne okno, a gdy wszystkie są przykryte —
  ostatnie. Przekazanie wykonania uzgadnia stan i nie omija przerwy po
  niepewnym zapisie. Ten mechanizm nie przekazuje gospodarza serwera.
- Zwykły wybór jest związany z wyświetloną rewizją. Gry z równoległym
  wejściem dopuszczają tylko jawnie opisane wyjątki we własnej rundzie/fazie:
  odpowiedzi quizu i Państw-miast, floty Statków, próby wyścigu Krowy,
  przechwytywanie/deklaracje UNO oraz deklaracja Makao. Ostatecznie zawsze
  waliduje je `action_for` na świeżym stanie. Zachowano również karę UNO
  za spóźnioną próbę; stara karta nie przechodzi do kolejnego rozdania.
- Zamrożenie zapisu, przerwanie partii i zamknięcie stołu zatrzymują akcje.
  Rewanż używa nowego ID sesji. Niepewny zapis zachowuje istniejącą ścieżkę
  potwierdzenia, identyfikator wiadomości i backoff; nie jest wysyłany jako
  nowy ruch. Zamknięcie nie zabija wątku w połowie zapisu.
- Nieudana akcja automatyczna jest ponawiana w ograniczonym tempie, również
  gdy dotyczy lokalnego szkicu odpowiedzi. Błąd trafia do adaptera UI dopiero
  z jego własnego wątku. Powrót po zakończonym odzyskiwaniu połączenia nie
  rozpoczyna od nowa historycznej 30-sekundowej przerwy.

## Wskazówki dla nowych gier

Model i polityki automatyczne muszą działać bez UI. Nie wolno w nich otwierać
formularzy, odczytywać aktywnej kontrolki, wołać `loop_update` lub mówić.
Niestandardowe argumenty konstruktora trzeba zachować w `build_session_game`
(przykład: bank słów Krowy). Planista ma własną, trwałą instancję modelu;
nie należy współdzielić jej mutowalnych cache z ekranem.

Termin opisuje `automatic_action_due?`, a legalną operację
`automatic_action`/`action_for`. Nie zakładać, że cała polityka będzie
wywoływana bez końca dla niezmienionej pozycji. Jeżeli potrzebny jest szkic,
zdefiniować `automatic_surface_identity` i bezpieczny snapshot danych.
`concurrent_session_input?` nie może być ogólnym pominięciem kontroli
rewizji; porównuje konkretną tożsamość rundy i rodzaju operacji.

Lokalne usługi prezentacyjne Krowy (dialog definicji, galeria, propozycja
publikacji wyniku i prywatne pokazanie rozwiązania po poddaniu) nadal należą
do adaptera UI. Wykonawca obsługuje stan, ocenę prób i publiczne rozstrzygnięcie,
nie przenosi dowolnej metody `game_client` do wątku roboczego.

## Weryfikacja i ograniczenia

Celowane testy obejmują niezależny odbiór zdarzeń, brak podwójnych ruchów,
widoczną prezentację, powrót do okna, równoległe wejście, planowanie bota,
potwierdzony i niepotwierdzony zapis, opóźnienie i powielenie callbacków,
terminy, ukryte odpowiedzi, freeze/unfreeze, przerwanie, zamknięcie, rewanż,
wiele instancji oraz sprzątnięcie wątku/subskrypcji. Sprawdzono kontrakt
wykonawcy dla wszystkich 23 gier turowych z botami; gry bez botów mają
oddzielne przypadki (Scrabble, Taboo, Państwa-miasta, Krowa).

Żywe próby na dwóch kontach obejmują rzeczywiste natywne listy Wiadomości
i forum, otwierane jedno- i wielokrotnie nad grą. Testy używają normalnych
handlerów akcji, nie fizycznej klawiatury. Nie otwierają prywatnych rozmów
ani nie publikują postów. Kontrolowane przerwy i błędy zapisu dodatkowo
badane są offline; nie jest to próba odcięcia Internetu ani pomiar odsłuchu.

Podczas jednej wczesnej próby host zgłosił rzeczywisty błąd Live Sessions
i odtworzył stream. UI miał aktywny istniejący backoff, podczas gdy model i bot
działały. Tamta próba skończyła się przed upływem backoffu i nie potwierdza
samodzielnego powrotu ekranu. Zachowano jej zapis zamiast zaliczać ją jako
poprawną; dalsze powtórzenia oraz osobna kontrolowana awaria służą odrębnej
weryfikacji. Kontrolowana awaria przeszła: po 30,275 s UI sam pokazał
sześć zaległych zdarzeń, z zachowaniem szkicu i bez dodatkowego wejścia.
Nie naprawiano protokołu HTTP/2 ELTEN-a.

Zestaw poprzedniego etapu wykonawcy: 65/65 celowanych skryptów, dwie dodatkowe kontrole
binarnych źródeł/allowlist i 29 kontroli składni. W 30 żywych próbach
uzyskano 24 zgodne porównania końcowego stanu po przykryciu i dwa poprawne
testy zamknięcia/przerwania; pozostałe cztery próby mają jawnie opisane
ograniczenia pomocnika/warunków. Sondy, workery i wstrzyknięty kod usunięto,
obydwa ELTEN-y pozostawiono na ekranie głównym z zerem zasobów testu.
Nie wykonano instalacji, restartu, nowej paczki, publikacji ani zmian
ustawień profili lub schematów.

Surowe wyniki, błędy pomocników, manifest źródeł i stan po sprzątaniu są
prywatnie w `../diagnostics/session-runner-237/`. Żaden zestaw testów nie
stanowi dowodu dla wszystkich możliwych partii, komputerów i awarii sieci.

Powyższe 30 prób dotyczyło działania modelu i powrotu do ekranu. Nie traktować
ich jako dowodu odczytu podczas otwartych Wiadomości. Nowe próby prezentacji
mają odrębne pliki `PRESENTATION-*` w tym samym prywatnym katalogu. Badają
normalne stoły na obu kontach, otwierają prawdziwe listy Wiadomości/forum
i rejestrują wywołania rzeczywistego adaptera syntezy oraz aktywne uchwyty
audio przed powrotem. Nie zastępują fizycznego odsłuchu; wejście jest
generowane przez normalne handlery. Po tych próbach użytkownik polecił
pozostawić kompletną poprawkę w pamięci obu ELTEN-ów, bez sond testowych.
