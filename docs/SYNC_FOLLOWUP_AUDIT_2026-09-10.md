# Dalszy audyt synchronizacji — 10 września 2026

Stan: po czterech uzgodnionych poprawkach synchronizacji, na roboczych źródłach
po buildzie 202. Poniższe trzy usterki są odtworzone lokalnie, lecz **nie zostały
jeszcze naprawione**. Nie instalowano paczki ani nie zmieniano serwera.

## 1. Ruch w chwili zamknięcia pokoju może wywołać nieobsłużony wyjątek — P2

Miejsca: `lib/live_session_store.rb:635`, `lib/game_screen.rb:968` i `:1604`.

Scenariusz: drugi gracz ma swoją kolej i legalny ruch. Właściciel zamyka pokój,
callback usuwa aktywną sesję, ale gracz zdąży zatwierdzić ruch przed obsłużeniem
zamknięcia przez ekran. Zapis zgłasza `ArgumentError: The room is no longer
active`. Granica obsługi sieci celowo nie przechwytuje ogólnego `ArgumentError`,
więc ten wyjątek wydostaje się z `submit_action`.

Odtworzono na prawdziwej logice Czwórek i repozytorium produkcyjnym, z dwoma
symulowanymi klientami. Zwykłe zamknięcie bez równoczesnej akcji przechodzi
obecny test; nie pokrywa jednak tego wyścigu. To nie jest problem własności
tabel ani wycofanej migracji mastera.

Proponowana naprawa: brak aktywnej sesji przy operacji powinien być rozpoznawalnym
stanem zamknięcia pokoju, a ekran powinien kierować go do istniejącego
`room_closed`. Nie przechwytywać wszystkich `ArgumentError`, bo ukryłoby to
błędy programistyczne. Analogicznie obsłużyć natywny błąd zamknięcia sesji,
gdy zamknięcie nastąpi już po lokalnym sprawdzeniu, podczas wysyłki.

## 2. Kolejność historii może różnić się między klientami — P2

Miejsca: `lib/live_session_store.rb:652`, `:690`,
`lib/table_activity_repository.rb:82` i `:185`.

Własny zapis po potwierdzeniu otrzymuje czas lokalnego komputera. Zdalne wpisy
otrzymują czas serwera. Jeżeli potwierdzenie przyjdzie przed własnym
powiadomieniem, późniejszy odczyt lub callback jest uznawany za duplikat i nie
uzgadnia czasu. Historia sortuje najpierw po czasie, dopiero później po ID.

Odtworzenie: oba komputery są dwie minuty za serwerem. Alice wysyła `first`,
potem Bob wysyła `second`; powiadomienia docierają po potwierdzeniach zapisów.
Serwer ma jeden prawidłowy porządek, lecz:

- Alice widzi `first`, `second`;
- Bob widzi `second`, `first`.

To potwierdzony błąd prezentacji chronologii. Nie wykazano w tym scenariuszu
innych wyników lub innej planszy: odtwarzanie ruchów korzysta z kolejności
stosu, nie z tego sortowania historii.

Proponowana naprawa: wspólną historię w obrębie jednej natywnej sesji porządkować
według pozycji stosu, zachowując kolejność podzdarzeń pojedynczego ruchu.
Metadane czasu własnego wpisu uzgadniać z serwerem, zamiast bezwarunkowo
ignorować je przy duplikacie. Nie dodawać odczytu serwera po każdym ruchu.

## 3. Nieudany odczyt aktywności wygląda jak pusta historia — P2

Miejsca: `lib/table_activity_repository.rb:96`, `lib/game_screen.rb:1067`
i `:1079`.

`entries_for` przechwytuje błąd odczytu i zwraca `[]`. Kod wyżej nie potrafi
odróżnić awarii od prawdziwego braku wpisów. Uaktualnienie może usunąć z widoku
dotychczasowy czat i zdarzenia pokoju, nie zgłaszając potrzeby ponownego odczytu.
Nie oznacza to usunięcia danych ze stosu serwera ani usunięcia ruchów gry.

Odtworzenie: snapshot pokoju udał się, następnie doszedł nowy wpis. Odczyt
aktywności, wykonywany chwilę później, kończy się timeoutem. Rzeczywiste
`fetch_room_snapshot` zwraca `:updated` i pustą historię, a synchronizator
nie ma zaplanowanego odzyskiwania (`next_reconcile_at` pozostaje nieskończone).
`apply_room_snapshot` bezwarunkowo zastępuje dotychczasowe wpisy tym wynikiem.

Proponowana naprawa: nie przedstawiać błędu jako `[]`; zachować ostatnią
poprawnie odczytaną historię, przekazać błąd do wspólnej obsługi i zaplanować
odzyskiwanie tylko po awarii. Nie odbudowywać formularza ani nie odczytywać
ponownie starych komunikatów przy udanym ponowieniu.

## Dowody i zakres

Lokalny skrypt `diagnostics/audit-2026-09-10/followup_sync_probes.rb` znajduje się
obok repozytorium, w katalogu projektu. Korzysta z produkcyjnych klas Game Roomu
i lokalnego brokera LiveSessions. Nie łączy się z ELTEN-em ani serwerem.
Skrypt potwierdza **obecność** tych trzech błędów, a nie ich naprawienie; po
przyszłej naprawie odpowiednie scenariusze należy przekształcić w regresje
sprawdzające prawidłowe zachowanie.

Wynik reprodukcji:

```text
REPRODUCED: valid user move after remote closure escapes the network boundary: ArgumentError: The room is no longer active
REPRODUCED: identical server log has different histories: {"Alice" => ["first", "second"], "Bob" => ["second", "first"]}
REPRODUCED: activity timeout is returned as updated + empty history; no recovery is scheduled
```

Testy czterech uzgodnionych poprawek przechodzą niezależnie od powyższych
reprodukcji. Ten przegląd nie jest dowodem braku innych usterek w całej
aplikacji ani zastępstwem rozgrywki na rzeczywistych klientach ELTEN-a.

Kolejny, osobno zlecony etap przeglądu opisuje
[audyt równoczesnych operacji, długich gier i odtwarzania](EXTENDED_AUDIT_2026-09-10.md).
Zawiera dalsze reprodukcje, bez naprawiania tych trzech usterek.
