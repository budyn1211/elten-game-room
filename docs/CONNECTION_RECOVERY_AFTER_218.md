# Odzyskiwanie połączenia po buildzie 218

Zakres: wspólny transport i ekran gry, bez zmiany zasad Quiz Party, innych
gier, strategii botów, tempa ruchów ani ponownego wprowadzania Signals.
Poprawki Monopoly i podział Wiedźmina pozostają zachowane.

## Zachowanie

1. Nieudany odczyt nie oznacza zamkniętego pokoju. Gra zachowuje ostatni
   kompletny stan oraz pole czatu. Nie potwierdza ani nie odrzuca nowego ruchu
   na podstawie tej starej kopii. Przed pierwszym poprawnym odczytem czeka
   w formularzu z możliwością powrotu. Jawne zamknięcie sesji nadal zamyka
   ekran i nie wymaga zgody na dobrowolne opuszczenie stołu.
2. Zapis ruchu człowieka, bota i automatycznego przejścia używa tej samej
   granicy `append_game_action`. Odrzucenie przez serwer nie trafia do kolejki
   ponowień. Timeout, 429, przejściowy błąd lub niejednoznaczne potwierdzenie
   pozostawiają wynik nieznany. Odebranie własnego zdarzenia może potwierdzić
   zapis nawet przy utracie odpowiedzi HTTP.
3. Niepewny ruch zachowuje cały pakiet, UUID, identyfikatory składowych
   zdarzeń, aktora i wynik losowania. Odzyskiwanie najpierw czyta stos; jeżeli
   operację znajdzie, nie wysyła jej ponownie. W przeciwnym przypadku ponawia
   dokładnie ten sam pakiet i UUID. Brak operacji w odczycie nie jest uznawany
   za dowód, że pierwsze żądanie nie może jeszcze dotrzeć. Odtwarzanie pomija
   powtórzenia według uwierzytelnionego nadawcy i UUID, również gdy duplikat
   otrzyma inną pozycję stosu. Obowiązuje pierwsza pozycja tej operacji.
   Zapis znaleziony po awarii nadal podlega walidacji zasad przy replay;
   odrzucony ruch człowieka korzysta z dotychczasowego komunikatu ponownego
   wyboru. Wyjście ze stołu lub nowa partia usuwa nieaktualne oczekiwanie.
4. Odzyskiwanie uruchamia rzeczywisty błąd lub luka, nie sam upływ czasu bez
   ruchu. Pozostaje normalny odbiór natywnych zdarzeń ELTEN-a. Dodano obsługę
   błędów endpointu i wspólne respektowanie przerwy 30 s / 60 s dla 429
   (dłuższe `Retry-After` ma pierwszeństwo). Powiadomienia pokoju, czatu i
   kolejne luki nie skracają tej przerwy. Nie dodano okresowego odpytywania,
   własnego `LiveSessions.tick`, wątku, watchdogów faz ani zaproszeń naprawczych.

## Pliki

- `lib/live_session_store.rb`: zachowanie niepewnego pakietu, odczyt i
  ponowienie tego samego zapisu, deduplikacja, błędy endpointu, jednoznaczne
  potwierdzenie pozycji własnego wpisu (nie dowolnego końca stosu).
- `lib/game_room_transport.rb`, `lib/game_repository.rb`: przekazanie
  odzyskiwania i potwierdzonych po awarii zdarzeń do wspólnej warstwy.
- `lib/network_errors.rb`, `lib/game_sync.rb`: klasyfikacja błędów,
  współdzielone opóźnienie prób i łączenie powiadomień o konieczności naprawy.
- `lib/game_screen.rb`, `__app.rb`: zachowanie ostatniego poprawnego widoku,
  wspólna granica obsługi błędów ruchów i rozróżnienie niedostępności od
  potwierdzonego zamknięcia stołu.

## Testy i ograniczenia

Celowany runner: `tools/run-connection-recovery-tests.rb`. Obejmuje awarie
przed zapisem, po zapisie, brak powiadomienia, ponowne 429 podczas naprawy,
spóźniony oryginał przed i po ponowieniu, niejednoznaczną odpowiedź serwera,
zamknięcie pokoju, zmianę partii, zachowanie czatu oraz brak dodatkowych
odczytów w zdrowym połączeniu. Quiz z dwiema osobami, bez botów, przechodzi
automatycznie do kolejnego pytania. Próba obejmuje także pytanie, którego czas
upłynął podczas awarii: istniejące zasady zamykają je i przechodzą dalej.

To testy z wstrzykiwanymi błędami i niezależnymi czytelnikami natywnego stosu
w pamięci, a nie rozgrywka prawdziwych klientów. Obsługa zgubionego końcowego
powiadomienia nadal opiera się na mechanizmie kontrolnym hosta. Nie dowodzą,
że konkretna wcześniejsza partia utknęła właśnie z powodu przytoczonego 429.
Ten wpis logu poprzedzał zaobserwowany zastój. Nie odtworzono pierwotnej sesji.

Niezakończony zapis jest trzymany w pamięci aktywnego transportu, nie w nowym
pliku na dysku. Ponownie otwarty ekran przejmuje takie oczekiwanie, respektując
przerwę wymaganą po błędzie. Nie daje to gwarancji odzyskania niezapisanego ruchu po awarii
całego procesu. Podczas przerwy sieciowej nie obiecujemy natychmiastowych
odświeżeń; poprawka zapobiega myleniu przerwy z końcem pokoju i utracie
oczekującego ruchu. Ponowienie dotyczy ruchów gry, nie transakcji tworzenia
stołu, zaproszeń czy wieloetapowego uruchamiania partii.

Poprawki weszły do podpisanej paczki 1.1.8/build 219. Nie instalowano
i nie publikowano paczki w ramach tej poprawki.
