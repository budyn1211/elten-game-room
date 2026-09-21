# Pong: zestawianie Communications i opóźnienie bramki

21 września 2026. Zmiany w źródłach, na polecenie użytkownika.
Następnie zatwierdzono ponowne zbudowanie i podpisanie tej samej
2.0.2/build 231, API 3.0.3, bez zmiany changelogu PL/EN.
Potwierdzeniem ukończenia jest raport
`../diagnostics/pong-connection-recovery-release-231/PACKAGE.json`
(ścieżka względem repozytorium). Poprzednia paczka 30d12a13… zostaje
zachowana jako before-connection-recovery-signed.eltsetup.
Bez instalacji, publikacji, GitHuba, zmian serwera, restartów
i prób na żywych kontach.

## Co naprawiono

- Rejestracja endpointu zaczyna się przed ładowaniem nagrań. Nie wymaga
  jeszcze wybrania protokołu partii; sesja powstaje dopiero po jego ustaleniu.
- Nieudane zaproszenie ponawiane jest po 0,5 s, następnie 1 s i maksymalnie
  co 2 s. Po wysłaniu czekamy 2 s na przyjęcie, zanim ponowimy. Nie jest to
  zaproszenie użytkownika do stołu ani powiadomienie; dotyczy prywatnego
  kanału Communications. `PeerUnavailable` nie jest trwałym zakazem prób.
- Pierwsze zestawienie ma limit również przed powstaniem sesji/epoch.
  Brak potwierdzeń przy pozornie otwartym połączeniu uruchamia odtworzenie
  endpointu i sesji. Reconnect nie jest już blokowany przez `Work.busy?`.
- Operacje rejestracji, tworzenia, przyjmowania i wysyłania są nadzorowane
  terminem 8 s. Zamknięcie endpointu zwalnia natywne oczekiwanie. Spóźnione
  wyniki poprzedniej generacji są ignorowane, ich zasoby zwalniane.
  Każda kolejka może mieć najwyżej jeden opuszczony i jeden bieżący worker;
  nie zabijamy wątków i nie tworzymy nieograniczonej liczby nowych.
- Przyjęta sesja dostaje obsługę przed opuszczaniem starej. Błąd lub
  zawieszenie starego `leave` nie odbiera nowego, działającego połączenia.
- Niezawodna wysyłka sprawdza obiekt Delivery: sam powrót RPC nie dowodzi
  doręczenia. Brak potwierdzenia, błąd lub luka w kolejności zdarzeń
  uruchamia odzyskiwanie. Niedostępny obserwator nie zrywa partii graczom.
- Opcjonalny adapter `Tasks.run` podtrzymuje klienta Ponga podczas odczytu
  i zapisu LiveSessions, również kiedy aktualizowane jest tylko pole czatu.
  Korzysta z pętli zadań ELTEN-a; nie pompuje UI samodzielnie i nie wywołuje
  UI z workerów. Nie pobiera sterowania grą z okna oczekiwania ani czatu.
  Zachowuje ciche zadania oraz opóźnione okno oczekiwania i Escape.
  Pozostałe gry bez tego hooka używają dokładnie dotychczasowej ścieżki.

## Bramki i spójność wyniku

Po potwierdzeniu tego samego końca wymiany przez wymaganych graczy gospodarz
wysyła uporządkowane zdarzenie `point` i uruchamia jednorazowy odgłos bramki.
Klient przyjmuje tę prezentację wyłącznie od gospodarza, dla bieżącej wymiany
i zgodnego lokalnego końca piłki. Nie wystarcza dowolny datagram pozycji.

To nie zapis wyniku. Wynik, jego odczyt i zwycięstwo nadal pochodzą wyłącznie
z zaakceptowanego `pong_point` przez action_for, GameRepository i replay.
Do tego czasu nie zaczyna się kolejna wymiana. Ponowienie zapisu oraz replay
nie mogą podwoić punktu ani nagrania. Uzgodnionej bramki oczekującej na
utrwalenie nie rozgrywa się ponownie przy wymianie kanału.

Trzysekundowa pauza nagrania jest liczona od faktycznego odgłosu bramki,
nie rozpoczyna się ponownie po zapisie. Jeżeli zapis trwa dłużej, odczyt
wyniku zaczyna się dopiero po potwierdzeniu, a następnie pozostaje zwykły
czas 2,7 s na sekwencję i gotowość. Wczesna prezentacja nie ogłasza wygranej
ani nie pokazuje nieutrwalonych punktów pod S.

Ruchy z sąsiedniej wymiany mogą dowodzić, że połączenie nadal działa, gdy
jedna osoba wcześniej otrzymała zapis. Nie zastępują jednak aktualnego
stanu ani nie umożliwiają przedwczesnego serwisu. Pozostały czas gotowości
gospodarza jest przekazywany względnie, bez porównywania zegarów komputerów;
po rozpoczęciu wymiany nie przesuwa już zegara fizyki.

Rozszerzenie pozostaje zgodne z protokołem `pong-local-1`. Starszy klient
ignoruje dodatkową prezentację i odtwarza nagranie po trwałym zdarzeniu.
Aby obie strony korzystały z wszystkich napraw, obie potrzebują nowych źródeł
w paczce. Nie zmieniano fizyki, botów, dźwięków, zasad punktacji ani LiveSessions.

## Dowody i granice

Celowane testy regresji:

- `realtime_recovery_test`: szybkie ponowienia, praca bez odpowiedzi,
  ograniczenie liczby workerów, spóźniona rejestracja i sprzątanie zasobów;
- `realtime_delivery_test`: brak potwierdzenia doręczenia, błąd, luka,
  zawieszona wysyłka i niedostępny obserwator;
- `realtime_two_clients_test`: rzeczywiste klasy Channel/EventChannel/Client,
  z atrapą publicznego API relay, a nie samym licznikiem reconnect;
- `axel_pong_connection_recovery_test`: brak pierwszej sesji i cichy kanał;
- `axel_pong_network_wait_test`: ponad 6 s oczekiwania na zapis, nadal działające
  potwierdzenia, brak powtórek, zachowanie czatu i anulowania;
- `axel_pong_goal_latency_test`: nagrania przy zapisie opóźnionym o 1 i 6 s;
- `realtime_native_tasks_test`: faktyczna implementacja Tasks.run z lokalnego
  źródła ELTEN-a, z izolowaną pętlą testową, bez uruchamiania klienta/usług;
- istniejące regresje Ponga, binarne wczytanie źródeł PL/EN/fallback,
  GameSync, transport i symulacje LiveSessions.

W deterministycznej próbie dwóch klientów: start po 3,744 s, w tym oryginalne
3 s gotowości, mimo początkowo niedostępnego endpointu gościa. Przy ignorowaniu
zaproszeń do 14 s automatyczna wymiana sesji i gotowość po 17,808 s, 9 prób
zaproszenia i 2 sesje. Są to wyniki symulacji, nie obietnica czasu w sieci.

Logi obejmują etapy i błędy Communications oraz czas między uzgodnioną bramką
a potwierdzonym punktem. Nie zawierają wiadomości, haseł ani treści pakietów.
Wcześniejszego rzeczywistego utknięcia nie odtworzono jeden do jednego;
usunięto potwierdzone w kodzie mechanizmy, a nie ustalono z pewnością
jednej przyczyny tamtego incydentu. Całkowicie zatrzymana pętla całego ELTEN-a
nie może wykonywać nadzoru. Przy trwale zawieszonych natywnych wywołaniach
limit workerów chroni proces, zamiast mnożyć wątki bez końca.
