# Communications: natychmiastowe uruchamianie wysyłki

22 września 2026. Zmiana lokalna po próbie dwóch kopii z diagnostyczną
paczką 233. Dotyczy tylko warstwy Communications Game Roomu. Nowej paczki
nie zbudowano; istniejąca diagnostyczna 233 nie zawiera tej zmiany.

## Przyczyna i poprawka

`EventChannel#send_event` wcześniej dopisywał akcję do kolejki. Zadanie
wysyłające ruszało dopiero podczas kolejnego `tick`, zależnego od obsługi
okna. W pomiarze dwóch klientów maksima tej kolejki dochodziły do 33 ms.

Wolny kanał rozpoczyna teraz ograniczone zadanie w tle bezpośrednio przy
dodaniu akcji. Wywołujący nadal nie czeka na RPC ani potwierdzenia odbiorców.
Zakończone zadanie jest rozliczane przez wspólną ścieżkę, zanim jego miejsce
zajmie następne. Zachowano kolejność, limity, kontrolę kompletu odbiorców,
rozróżnienie wyniku RPC od potwierdzenia dostawy i obsługę odzyskiwania.
Nowa akcja nie dostaje pozornego sukcesu, jeżeli w tym czasie wykryto
błąd wcześniejszej dostawy i unieważniono kolejkę.

Przed wykonaniem zaplanowanego RPC zadanie ponownie sprawdza, czy nie
zamknięto kanału, nie rozpoczęto odzyskiwania ani nie zmieniono sesji lub
generacji. Nie rozpoczyna wtedy starej wysyłki. Trwającej operacji sieciowej
nie zabijamy, ponieważ mogła już zostać przyjęta przez serwer.

Ta sama klasa nadal obsługuje bezpośrednie trasy między ludźmi i model
gospodarza używany przy botach. Nie zmieniono protokołu ani dialektów.
Nie zmieniano odbioru, kodu ELTEN-a, LiveSessions, fizyki, zasad i nagrań.

## Sprawdzenie

Przeszły 23 celowane skrypty i pięć kontroli składni. Nowy test najpierw
odtworzył zwłokę, a kolejny przypadek wykrył start anulowanego zadania.
Test z rzeczywistym wątkiem roboczym i blokowaną atrapą RPC potwierdza,
że wywołujący nie jest blokowany i nie powstają równoległe wysyłki.
Sprawdzono też serię akcji, kolejność, brakującego odbiorcę, zmianę jego
identyfikatora, błąd dostawy, limity, zamykanie i powrót po przerwie.

Pierwsza macierz miała 22/23. Scenariusz ponownego dołączenia usuwał osobę
po dodatkowej klatce, czyli po przyspieszonej wysyłce do pełnego składu.
Przeniesiono kontrolowane zniknięcie na granicę między lokalnym ruchem
a `send_event`, zachowując wymagania kompletnej dostawy i wspólnego stanu.
Wyniki początkowe i ponowienie pozostają w raporcie.

W tym samym kontrolowanym scenariuszu (40 ms w jedną stronę, odpowiedź RPC
po 120 ms, aktualizacja co 8 ms) kolejka spadła z 8 do 0 ms, a czas od
lokalnego ruchu do odbioru u pozostałych z 56 do 48 ms. To symulacja
jednej śledzonej akcji, nie pomiar Internetu ani gwarantowany ping.

Raport: `../diagnostics/pong-immediate-dispatch-233/SOURCE.json`.
Nie wykonywano pełnego runnera, nowego żywego meczu ani odsłuchu.
Przerwa 485 ms po stronie odbiorcy z poprzedniej próby pozostaje osobnym,
niezdiagnozowanym do końca problemem; ta poprawka jej nie dowodzi naprawionej.
