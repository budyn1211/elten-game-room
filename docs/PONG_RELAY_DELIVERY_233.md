# Pong: dostarczanie akcji przez relay — poprawki po buildzie 233

Stan: 22 września 2026. Wdrożenie lokalne, bez nowej paczki, instalacji,
publikacji lub zmian w działających sesjach. Dotychczasowy instalator 233
nie zawiera tych poprawek.

## Co ustalono

Zgłoszenie dotyczyło czterech ludzi w deblu: serw czasem nie ruszał,
a próba obrony nie dawała dźwięku odbicia. Nie uznano samego tego opisu
za dowód gubienia pakietów przez serwer.

W dotychczasowym kodzie znaleziono i odtworzono dwa problemy:

1. Akcja gościa docierała do pozostałych gości dopiero po przetworzeniu
   i ponownym wysłaniu przez komputer gospodarza. Relay nie usuwał tego
   dodatkowego etapu w aplikacji. Opóźnienie gospodarza lub jego kolejki
   mogło wydłużać dostawę mimo sprawnego serwera.
2. Listę wymaganych odbiorców wyliczano z aktualnie widocznych uczestników
   kanału. Chwilowo nieobecny gracz znikał więc także z listy tych, od których
   wymagano potwierdzenia. Akcja mogła zostać uznana za dostarczoną, choć
   w ogóle nie została do niego skierowana. Zastępowalne pozycje paletek
   nie odtwarzają pominiętego odbicia.

Wartości 200–300 ms przy `point_confirmed` opisywały oczekiwanie na trwałe
potwierdzenie punktu w LiveSessions, nie ping Communications. Ctrl+F4 nadal
mierzy HTTP RTT. Żaden z tych pomiarów nie określa opóźnienia samego relay.

## Zmiany w transporcie

`EventChannel` ma opcjonalne `routing: :peers`. Każda akcja człowieka jest
teraz kierowana przez relay bezpośrednio do pozostałych uczestników.
Gospodarz nie odsyła kopii cudzego serwu, odbicia ani pudła. Nadal odpowiada
za wspólne efekty Arcade, sygnały band, karę za brak serwu i uzgodnienie
punktu. LiveSessions pozostaje źródłem trwałego wyniku i stanu pokoju.

Domyślny tryb współdzielonego kanału nadal prowadzi akcje przez gospodarza.
Nową trasę wybiera Pong grany wyłącznie przez ludzi, zarówno Single,
jak i Debel. Warianty z botami zachowują dotychczasowy model sterowania
przez gospodarza; otrzymują wspólną kontrolę dostarczenia i diagnostykę.
Transport zastępowalnych pozycji pozostaje bez zmian.

Wymagani odbiorcy są zapamiętywani według kont, niezależnie od chwilowej
listy natywnej sesji. Ich aktualne identyfikatory są rozwiązywane przed
wysyłką, także ponownie w krótkim zadaniu roboczym. Jeśli brakuje wymaganej
osoby, akcja czeka w ograniczonej kolejce zamiast zostać wysłana tylko
do części graczy. Krótki powrót członka pozwala wysłać tę samą akcję raz;
przekroczenie istniejącego limitu 8 sekund uruchamia odzyskiwanie kanału.

Potwierdzenia sprawdzamy dla każdego wymaganego identyfikatora. Brak wpisu
w wyniku natywnej dostawy oznacza oczekiwanie, a nie sukces. Nie wymagamy
potwierdzeń od zwykłych obserwatorów; gospodarz-obserwator nadal jest
wymagany, bo koordynuje rozgrywkę. Nie wysyłamy do pustej listy odbiorców.

Zachowano limit 128 wpisów, ograniczenie pakietu do 1100 bajtów,
sprawdzanie nadawcy, meczu, generacji i numerów sekwencji oraz ograniczoną
liczbę pracowników. Anulowany stary wynik nie może zerwać nowego połączenia.
Nie dodano sond HTTP, oczekiwania na sieć w klatce gry ani pętli UI
w zadaniu roboczym.

## Kolejność i odzyskiwanie

Różni nadawcy nie mają jednej wspólnej kolejności dostaw. Odbicie może
dotrzeć do trzeciej osoby przed poprzedzającym je serwem. Po sprawdzeniu
uprawnień akcje porządkujemy według rozdania/wymiany i licznika ruchu;
przedwczesna akcja czeka na poprzednika w ograniczonym buforze.
Przyszły efekt lub sygnał bandy nie wyprzedza właściwego odbicia.

Tylko rzeczywisty uczestnik wskazanego miejsca może nadać swój serw,
odbicie lub pudło. Inny gracz ani obserwator nie może podszyć się pod niego.
Efekty wspólne, ponaglenie, potwierdzony timeout i potwierdzenie punktu
pochodzą tylko od gospodarza. Wyścig pierwszego serwu z potwierdzoną karą
czasu ma ten sam wynik u każdego odbiorcy; kara nie nadpisuje już
wymienionego odbicia.

Dodano też zabezpieczenie wtórne: jeżeli gospodarz dostaje świeże pozycje,
ale ten sam licznik akcji/cel pozostaje niezgodny przez ponad 4 sekundy,
inicjuje odzyskiwanie z przyczyną `PeerActionDisagreement`. Obowiązuje
dotychczasowa przerwa co najmniej 10 sekund między takimi próbami.
Zwykła chwilowa różnica nie wystarcza. Różne rundy podczas potwierdzania
punktu nie są tak traktowane; uzgodniony punkt oczekujący na LiveSessions
nie jest kasowany. To zabezpieczenie nie zastępuje poprawionej dostawy.

## Diagnostyka bez dodatkowych żądań

Nowy `GameRoomRealtime::Metrics` zbiera lokalne czasy monotoniczne.
Zapisuje najwyżej jedno zbiorcze podsumowanie na 10 sekund na kanał:

| Pole | Znaczenie |
| --- | --- |
| `relay_udp_rtt_ms` | Ostatni dostępny pomiar RTT UDP do relay z natywnego cache Endpoint. Tylko gdy aktualna ścieżka UDP jest aktywna. |
| `position_path` | `udp` albo `tcp_or_unknown`; nie zmienia kanału niezawodnych akcji. |
| `tick_gap_max_ms` | Największa przerwa między wywołaniami kanału przez aplikację w tym oknie. To nie jest ping. |
| `queue_wait_max_ms` | Najdłuższy czas od przyjęcia akcji do rozpoczęcia jej natywnej wysyłki. |
| `send_rpc_max_ms` | Najdłuższy czas wywołania natywnego `send_reliable`; nie czas dotarcia i wykonania akcji u przeciwnika. |
| `receive_wait_max_ms` | Najdłuższy czas od callbacku natywnej dostawy do odebrania zdarzenia przez grę. Nie obejmuje nieudostępnionej kolejki przed callbackiem. |

Brak świeżej ścieżki UDP daje `unavailable`, nie fałszywy aktualny ping
TCP. Nie dodano własnego pingowania ani odczytu prywatnych pól API.
Log nie zawiera kart, treści pakietów, nicków, czatu ani kluczy.
Przyczyny odzyskiwania obejmują m.in. brak odbiorcy, niepełną dostawę,
przerwę w sekwencji i utrwaloną rozbieżność akcji.

Stary `elapsed_ms` w wpisie `point_confirmed` otrzymał jednoznaczną nazwę
`durable_confirmation_ms`. Sam przebieg zatwierdzania punktu się nie zmienia.

Mały RTT i wysoki `queue_wait` wskazywałyby kolejkę po stronie aplikacji;
duży `tick_gap` przerwy w jej obsłudze. Wysoki `send_rpc` sam nie dowodzi
problemu lokalnego ani odległości od serwera. Do ustalenia przyczyny
rzeczywistej partii nadal potrzebne są pomiary z tej partii.

## Zgodność klientów

Nowe dialekty zaproszenia Communications to `pong-peer-2` oraz
`pong-doubles-peer-2`. Są celowo inne od starych `pong-local-1` i
`pong-doubles-1`: starego klienta oczekującego przekazywania przez
gospodarza nie wolno bezgłośnie mieszać z bezpośrednim rozsyłaniem.
W kolejnym teście z ludźmi wszyscy muszą używać zgodnej nowej paczki.
Nie zmieniano publicznego numeru wersji ani buildu w tym kroku.

## Sprawdzenie

Przeszło 38 celowanych skryptów, 17 kontroli składni zmienionych/dodanych
plików Ruby oraz `git diff --check`. Nie uruchamiano pełnego runnera.

Kontrolowana próba z 40 ms dostawy w jedną stronę i 120 ms odpowiedzi RPC:

- przed poprawką gospodarz widział odbicie po 48 ms, pozostali goście
  po 104 ms, a pierwotnym adresatem był tylko gospodarz;
- po poprawce wszyscy wymagani odbiorcy widzą odbicie po 48 ms;
  zmierzona kolejka nadawcy w tej próbie to 8 ms.

To pomiar symulacji lokalnej od rozpoczęcia wysyłki, nie rzeczywisty ping
Internetu ani czas od klawisza do fizycznego kontaktu z piłką.

Testy używają rzeczywistych klas kanału i silnika, a kontrolują natywną
warstwę I/O, zegar i czas odpowiedzi RPC. Obejmują brak członka przed
i po zaplanowaniu wysyłki, niepełne potwierdzenia, fałszywego nadawcę,
wcześniejsze odbicie od innego nadawcy, powrót po 400 ms, odzyskiwanie,
rozgrywkę z botami i rewanż. Dodatkowo 32 kontrolowane wymiany sprawdzają
Single, dwie konfiguracje drużyn, Arcade i gospodarza-obserwatora:
wszystkie miejsca serwujące, dostawy 20–220 ms, odpowiedź RPC 120 ms,
zgubienie 1/7 zastępowalnych pozycji i 96 ms przerwy UI gospodarza.
Pozycje piłki na potrzeby odbić/pudła są ustawiane przez scenariusz;
nie były to naturalnie rozegrane mecze ani odsłuch.

Pierwszy przebieg macierzy miał 37/38: test natywnej zapowiedzi serwu
użył starszego lokalnego checkoutu ELTEN-a, bez `speech_indexes_supported?`.
Po wskazaniu istniejącego, właściwego hosta przez `ELTEN_HOST_SOURCE`
ten sam test przeszedł bez zmiany kodu produkcyjnego, testu lub asercji.
Wcześniejsze czerwone regresje dostawy i kolejki zachowano w diagnostyce.

Raport lokalny: `../diagnostics/pong-relay-delivery-233/SOURCE.json`.
MCP zgłaszał wygasłą sesję; nie zebrano rzeczywistego relay RTT ani nie
wykonano próby na kontach użytkowników. Nie deklarujemy, że zniknęły
wszystkie zgłoszone problemy obrony. Nie zmieniono fizyki, obsługi świeżego
naciśnięcia przy samej bramce, dźwięków, celownika ani sygnałów band.
