# Pojemność zapisu partii na koncie — pomiar 17 września 2026

Podstawa: Game Room 1.1.10/build 226. To wynik diagnostyki, nie wdrożenie.
Pierwsza część była wyłącznie odczytem i pomiarem offline. Następnie
użytkownik zatwierdził eksperyment na serwerze i usunięcie starych tabel,
potwierdził konto deweloperskie `papierek` oraz wykluczył kopię starych danych.
Nie zmieniono kodu aplikacji. Nie budowano, nie podpisywano, nie instalowano
i nie publikowano paczki. Bieżący wynik rzeczywistych prób jest poniżej;
starsze sekcje dokumentują etap przed uzyskaniem zgody.

## Aktualizacja: osobny magazyn plików aplikacji

Na kolejne polecenie użytkownika sprawdzono `AppResources`, nie załączniki
wiadomości ani publikację paczek. Bieżące źródła ELTEN-a udostępniają
`list`, `info`, `upload`, `delete` i `download_url`; `Program.server_resources`
jest zwykłym delegatem. Limit pola tabeli nie jest limitem takiego pliku.

Rzeczywista próba na koncie `papierek` i UUID Game Roomu, zakończona
17 września 2026 o 00:17 UTC:

- przed próbą: `maxsize: 0`, `used_size: 0`, zero zasobów;
- zwykłe `upload` sztucznego pliku 128 bajtów zwróciło `network_error`;
- źródło `src/eapi/http.rb:1201` pokazało, że standardowa ścieżka binarna
  odrzuca treść odpowiedzi innych niż 2xx, maskując także odmowę serwera;
- ponowienie po potwierdzeniu pustej listy, tym samym typowanym API,
  z zachowaniem odpowiedzi HTTP tylko w oddzielnym kliencie diagnostycznym,
  dało **HTTP 422**, `apps.resources.quota_exceeded`,
  `App resource storage limit exceeded`;
- po próbach nadal zero zasobów i zero zajętego miejsca. Żaden plik nie
  powstał, więc nie było czego usuwać; nie zmieniono globalnego transportu,
  schematu aplikacji, limitu ani rzeczywistych zapisów użytkownika.

Dla tej aplikacji zero nie oznacza nieograniczonego miejsca. Wariant
„jeden skompresowany plik oraz mały rekord opisowy” wymaga najpierw
przydzielenia miejsca po stronie serwera. Sprawdzone publiczne metody
`Apps.register/update` nie mają argumentu ustawiającego `maxsize`.
Nie próbowano nieudokumentowanej zmiany limitu. Nadal nie potwierdzono
uprawnień zwykłego użytkownika do własnych plików, pobrania, odtworzenia
ani retencji — przesłanie zostało zatrzymane przez limit.

Wynik poza repo: `diagnostics/server-save-feasibility-2026-09-17/`
`server-file-resource-results.json`. Nie wdrażano funkcji ani nie wydawano
paczki. Pozostałe ustalenia i plany, w tym brak lokalnej kopii awaryjnej,
pozostają bez zmian.

## Aktualizacja: rzeczywiste próby serwerowe i sprzątanie

### Najważniejszy wynik

Nie można uznać modelu „dowolna partia w jednym rekordzie” za sprawdzony.
Serwer przyjmuje `string:4096`, a odrzuca `string:4097`, `string:8192`,
`string:16384`, `string:65535`, `string:4194304` i próbny typ `text`.
Rzeczywisty zapis 4095 oraz 4096 znaków przeszedł bez zmian. Zapis 4097
został odrzucony jako `apps.tables.value_too_long`, bez cichego obcięcia.
To potwierdzona granica pola sprawdzonego typu, nie całego rekordu.

W jednym rekordzie udało się zapisać, odczytać nowym klientem i porównać
12 288 znaków ASCII rozłożonych na trzy pola `string:4096`. Rekord miał
także metadane opisane niżej. Tworzenie wariantu z czterema takimi polami
oraz z 256 polami zwróciło `common.internal`. Nie znamy dokładnego powodu
po stronie bazy serwera; nie przedstawiać tego jako udokumentowanej,
globalnej granicy 12 KB. Nie wykonywać kolejnych dużych migracji na
tabeli zawierającej prawdziwe zapisy.

Wariant 256 pól ujawnił niebezpieczny efekt odrzuconej zmiany schematu:
deklaracja pozostała stara, ale odczyt pustej tabeli testowej zwracał błąd
wewnętrzny. Usunięto wyłącznie tę diagnostyczną tabelę ze schematu i
utworzono ją ponownie w działającym wariancie trzech pól. Tabele produkcyjne
pozostały dostępne, a ich deklaracje nie zmieniły się. Wszystkie próby
dotyczyły oddzielnej tabeli, nie rekordów lobby.

### Archiwa wszystkich 15 gier

Wykorzystano wygenerowane, legalne archiwa Alice/Bob/Carol/Dave, nie zapisy
użytkowników. Jednopolowy wariant przyjął i poprawnie odtworzył 11 z 15
próbek. Cztery większe próbki odrzucił:

| Gra | Zdarzenia | Zlib + Base64 w tej próbie | Jedno pole |
| --- | ---: | ---: | --- |
| Spades | 815 | 13 748 | odrzucone |
| Farkle | 800 | 13 524 | odrzucone |
| UNO | 801 | 12 980 | odrzucone |
| Monopoly | 300 | 6 516 | odrzucone |

Monopoly następnie przeszło zapis w kilku polach **tego samego rekordu**,
walidację i odtworzenie bez zmiany stanu. Pozostałe trzy próbki przekraczają
nawet potwierdzone 12 288 znaków. To próbki, nie maksymalne wielkości gier.

Udane próby obejmowały: nowy uchwyt klienta do odczytu, zgodność całej
zawartości i sumy kontrolnej, serwerowego autora rekordu, pobranie samych
metadanych bez archiwum, zmianę jednego pola opisu bez naruszenia archiwum,
dekompresję i porównanie stanu po odtworzeniu z innym ID stołu. Nie uruchamiano
nowej prawdziwej LiveSession ani klienta na drugim komputerze.

W długiej serii wystąpiło ograniczenie tempa żądań. Przerwano serię,
po przerwie uzgodniono pozostawiony syntetyczny rekord o ID 12 i usunięto
go, a następnie dokończono dwie ostatnie gry. Ten przypadek potwierdza,
że brak odpowiedzi nie oznacza braku zapisu. Późniejsze wdrożenie wymaga
idempotentnego identyfikatora, ograniczonego tempa i obsługi niepewnego
wyniku zapisu. Nie powtarzać całej serii diagnostycznej bez przerw.

### Co usunięto i co zostało

Po kontroli kodu, uruchomionego oraz opublikowanego builda 226 usunięto:
`tables`, `table_members`, `game_sessions`, `game_events`, `invitations`
i `invitation_responses`. To dawny transport; bieżąca aplikacja tworzy
`GameRoomLiveSessionStore` i używa go także dla zaproszeń. Pozostałe
odwołania do tych tabel w kodzie są gałęziami starego transportu.

API po zmianie zwraca dla wszystkich sześciu `apps.tables.not_found`.
Zgodnie z poleceniem **nie wykonano kopii ich danych**. Nie ma lokalnej
kopii pozwalającej przywrócić usunięte rekordy. Nie ustalano możliwości
odzyskania ich z kopii administratora serwera.

Pozostają niezmienione `game_room_users` i `table_activity` oraz pusta
`saved_games_capacity_probe`. Ta ostatnia jest tabelą eksperymentalną,
nie gotową funkcją zapisu. Jej pola to `save_id`, `game`, `name`, `saved_at`,
`format`, `codec`, `archive_bytes`, `checksum`, `archive`, `archive_0002`,
`archive_0003`. Pozwala na select/insert/update/delete, bez udostępniania.
Wszystkie dane testowe usunięto. Nie dotykano rzeczywistych zapisów lokalnych,
LiveSessions, powiadomień, rejestru graczy ani historii lobby.

### Ochrona i następny wybór projektowy

Użytkownik doprecyzował, że chodzi o przełącznik `protected: true/false`.
Nie dodano osobnego trybu prywatności. Wartość `tables_protected: false`
pozostała taka jak przed eksperymentem; deklaracja runtime została po
każdej operacji przywrócona. Próby nazw widoczności `protected` i `private`
serwer odrzucił przed dodaniem tabeli. Syntetyczne dane nie zawierały
prywatnych kart użytkowników. Nie sprawdzano odczytu z drugiego konta;
nie przedstawiać kontroli pieczęci klienta jako potwierdzonej kontroli
odczytu własnych rekordów.

Rzetelny wariant dalszych prac to podział większych zapisów na oznaczone
części z jednym manifestem zapisu albo potwierdzone rozszerzenie API o
duże pole. Żaden z tych wariantów nie jest wdrożony ani zatwierdzony tym
eksperymentem. Nadal bez lokalnej kopii awaryjnej i bez zamykania gry przed
potwierdzonym pełnym zapisem. Jeden rekord nie może stać się założeniem
wyłącznie na podstawie udanego zapisu małej partii.

Raporty poza repozytorium: `server-payload-results.json`,
`server-multiple-fields-schema.json`, `server-cleanup-results.json`,
`server-final-state.json` w `diagnostics/server-save-feasibility-2026-09-17/`.
`server_probe.rb` jest diagnostyką wywoływaną świadomie, nie częścią programu.
`synthetic-archives.json` zawiera wyłącznie wygenerowane scenariusze testowe.

## Wniosek z pierwszego etapu offline

Obecny format archiwum można bezstratnie skompresować, przenieść i odtworzyć
bez starej LiveSession. Potwierdzono to na zapisach wszystkich 15 gier
obsługujących zapis. Nie potwierdzono natomiast maksymalnego rozmiaru pola,
wiersza i żądania po stronie serwera. Dlatego nie ma jeszcze podstaw,
żeby obiecać, że każda możliwa partia zmieści się w jednym rekordzie.

## Co zmierzono

Diagnostyka używa produkcyjnego `SavedGames#put`, `validate` i
`restored_data` oraz silników gier, z magazynem wyłącznie w pamięci.
Nie czyta istniejących zapisów użytkownika. Generuje legalne ruchy bez
uruchamiania kosztownych planistów botów. Nie jest pełnym testem gier
ani oceną strategii komputerów. Krótkie gry zapisuje przed zakończeniem.

Format transmisji próbnej: zwykły JSON archiwum, zlib na domyślnym poziomie,
następnie Base64 bez nowych linii. Ostatnia kolumna uwzględnia więc narzut
kodowania do tekstu, nie jest samym rozmiarem danych binarnych.
Wszystkie rozmiary w tabelach są w bajtach; Base64 ma tyle samo znaków.

| Gra | Zdarzenia w zapisie | JSON | Kompresja + Base64 |
| --- | ---: | ---: | ---: |
| Cztery w rzędzie | 19 | 2 044 | 640 |
| Kółko i krzyżyk | 4 | 698 | 432 |
| Szachy | 100 | 10 080 | 2 088 |
| Warcaby | 46 | 4 979 | 1 276 |
| Reversi | 59 | 5 855 | 1 216 |
| Chińczyk | 100 | 9 721 | 1 884 |
| Spades | 815 | 77 487 | 13 748 |
| Farkle | 800 | 77 832 | 13 520 |
| 99 | 105 | 11 501 | 2 356 |
| Tysiąc | 104 | 10 701 | 2 224 |
| Monopoly | 300 | 32 821 | 6 512 |
| Yahtzee | 100 | 10 349 | 2 208 |
| UNO | 801 | 77 612 | 12 976 |
| Poker | 24 | 3 158 | 1 232 |
| Makao | 111 | 10 902 | 2 364 |

Każda próbka przeszła: zgodność bajtów JSON po kompresji/dekompresji,
zgodność odczytanego obiektu, walidację archiwum, odtworzenie z nowym ID
stołu i późniejszym czasem oraz porównanie odtworzonego stanu silnika.
To nie jest test zapisu/odczytu przez serwer ani pełnego importu do nowej
rzeczywistej LiveSession. Taki test pozostaje osobnym krokiem.

Obecny limit archiwum to 40 880 zdarzeń, obliczany jako
`(4096 - 8) * 10`. Dotyczy odtworzenia przez stos nowej LiveSession,
nie pojemności tabeli serwerowej. W samym formacie dopuszczone są wartości
zdarzenia do 64 znaków, nazwy akcji do 32 i graczy do 64. Znak nie zawsze
jest jednym bajtem UTF-8. Rozmiar rośnie z historią, nie tylko z liczbą
graczy lub bieżących kart.

## Duże próbki syntetyczne — nie udawać rozegranych partii

Do pomiaru rozmiarów, nie walidacji zasad, powielono rozkład rzeczywistych
zdarzeń i nadano nowe ID, sekwencje oraz rosnące znaczniki czasu.
Te powielone historie **nie są legalnymi pełnymi partiami**. Wynik pokazuje
skalę zapisu, a nie górną granicę dla wszystkich prawidłowych gier.

| Rozkład zdarzeń | Liczba zdarzeń | JSON | Kompresja + Base64 |
| --- | ---: | ---: | ---: |
| Spades | 10 000 | 966 034 | 161 312 |
| UNO | 10 000 | 980 883 | 150 288 |
| Monopoly | 10 000 | 1 098 608 | 182 984 |
| Spades | 40 880 | 4 016 354 | 654 644 |
| Farkle | 40 880 | 4 109 451 | 651 168 |
| UNO | 40 880 | 4 076 118 | 608 208 |
| Monopoly | 40 880 | 4 558 104 | 755 652 |

Osobna sztuczna próbka 40 880 zdarzeń z losowymi 64-znakowymi wartościami
zajęła 7 060 706 bajtów JSON i 3 341 076 po kompresji oraz Base64.
Nie jest to prawidłowa partia ani dowód, że obecna gra wytworzy taki zapis.
Pokazuje jedynie, dlaczego nie wolno obiecywać stałego współczynnika
kompresji albo uznawać 756 KB za bezwzględne maksimum.

Próbna otoczka żądania dodawała około 212–222 bajtów do Base64.
Nie obejmuje wszystkich pól technicznych rzeczywistego klienta ELTEN-a,
dlatego nie jest dokładnym pomiarem jego kompletnego żądania HTTP.

## Co zweryfikowano po stronie ELTEN-a

Po restarcie klienta skonfigurowany łącznik miał wygasłą sesję. Zestawiono
nową sesję MCP przez istniejącą lokalną konfigurację, bez zmiany ustawień
ani ujawniania klucza. Odczytano uprawnienia, kontrakt, dokumentację oraz
rzeczywiste źródło `src/eltenlink/apps.rb` z launchera. Jego SHA-256:
`9a68be3bc58e89b8300e9684c41c9352eb9318324ed02042ac7466a1ac28e331`.

Przez odczyt `Apps.schema` i `Apps.info` pobrano aktualny schemat aplikacji
Game Room. API zwraca deklaracje i znormalizowane ustawienia istniejących
tabel w `data.tables` i `data.server.tables`. Cała odpowiedź odczytu schematu
zawiera tylko `app`, bez dodatkowego opisu globalnych limitów.

- Klient `AppTable` obsługuje projekcję kolumn, więc lista może pobierać
  same metadane, a archiwum dopiero po wybraniu zapisu.
- Klient ma zwykłe operacje wierszy i udostępnianie, ale nie deklaruje
  maksymalnej długości nowej kolumny ani całego wiersza.
- Schemat obecnych tabel zawiera konkretne `string:N`, m.in. 64, 256,
  512 i 1024; nie wskazuje maksymalnego dozwolonego `N` dla nowej tabeli.
- `max_select_limit` ogranicza liczbę odczytywanych wierszy, nie bajty
  archiwum. Nie utożsamiać go z pojemnością zapisu.
- Pole aplikacji `maxsize` zwróciło 0. Nie jest dokumentacją limitu wiersza;
  źródło używa też tej nazwy dla zasobów aplikacji. Nie interpretować zera
  jako potwierdzenia nieograniczonej pojemności zapisów.
- Odczytany serwer zwrócił `tables_protected: false`, chociaż źródłowa
  deklaracja Game Roomu ma `protected: true`. Nie zmieniano tego ustawienia.
  Jest to ochrona dostępu do tabel pieczęcią klienta, nie to samo co
  widoczność rekordów własnych, o której mówi użytkownik. Wszystkie obecne
  tabele w odczytanym schemacie są publiczne; nie ma jeszcze tabeli zapisów.

Dokumentacja pakietu i dostępne źródła klienta nie opisują globalnej granicy
`string:N`, większego typu tekstowego, limitu bajtów wiersza ani żądania.
Odczyt własnej konfiguracji istniejących tabel nie zastępuje takiego limitu.
Nie wykonano próbnej rejestracji, zmiany schematu ani żadnego zapisu na serwer.

## Bezpieczna decyzja przed wdrożeniem

Preferowany model pozostaje: jeden rekord na jedną partię, skompresowany
JSON w polu archiwum i krótkie metadane w osobnych kolumnach. Bez lokalnej
kopii, bez zmiany transportu bieżącej gry i bez zależności od starej sesji.

Przed zatwierdzeniem jednego rekordu dla całego zakresu trzeba uzyskać
rzeczywiste ograniczenia z dokumentacji/od autora serwera albo wykonać
uzgodnioną próbę w odrębnej tabeli testowej. Próba wymagałaby zmiany
schematu i jawnego zatwierdzenia konta właściciela aplikacji. Samo obecne
polecenie analizy nie jest taką zgodą. Nie testować na rekordach lobby.

Sprawdzić: dozwolony typ i długość pola, rozmiar całego wiersza/żądania,
limity łącznego miejsca, zachowanie odczytu na drugim urządzeniu i odmowę
dostępu z innego konta. Testy rozmiaru muszą uwzględnić wartości graniczne,
a nie tylko to, że jeden mały zapis przeszedł.

Każdy zapis należy mierzyć **przed** wysłaniem; stół można zamknąć dopiero
po potwierdzonym odczycie kompletnego rekordu i sumy kontrolnej. Brak miejsca
lub sieci nie może zamknąć stołu. Jeżeli potwierdzony limit okaże się
niewystarczający, potrzebny będzie uzgodniony podział na części lub większy
typ po stronie API — nie ciche obcinanie historii i nie plik awaryjny.

Pełne pomiary i powtarzalny skrypt diagnostyczny w katalogu roboczym:
`diagnostics/server-save-feasibility-2026-09-17/measurements.json` i
`diagnostics/server-save-feasibility-2026-09-17/measure.rb` (poza repozytorium).
UUID zapisu jest losowy, więc kompresja między uruchomieniami może różnić
się o kilka bajtów. Nie uruchamiano pełnego runnera testów.
