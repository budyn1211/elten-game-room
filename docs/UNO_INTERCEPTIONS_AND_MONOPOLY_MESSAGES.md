# UNO i komunikaty Monopoly — poprawki po buildzie 210

Poprawki wdrożono lokalnie po buildzie 210, 11 września 2026. Na późniejsze
polecenie użytkownika przeznaczono je do podpisanej paczki 1.1.6/build 211.
Paczka 210 pozostaje bez zmian i nie zawiera opisanych tu poprawek.
Potwierdzenie pakowania i kontroli znajduje się poza repozytorium, w
`diagnostics/build-211/README.md`. Nie instalowano ani nie publikowano zmian.

## Intercepcje UNO

Odtworzono blokadę na rzeczywistej kontrolce kart i ekranie gry uruchomionych
w testowym środowisku UI: `bot_actor != nil` odrzucał Enter także wtedy, gdy
bot dopiero oczekiwał 5 sekund na rozpoczęcie obliczeń. Same reguły dopuszczały
poprawną intercepcję. Ustalenie użytkownika dotyczy tury każdego przeciwnika,
zarówno człowieka, jak i komputera.

Wspólny ekran respektuje teraz deklarację `actions_during_bot_turn?` gry.
Domyślnie jest wyłączona; tylko UNO ją włącza. Działania nadal przechodzą przez
`action_for`, wspólny zapis i walidację replayu. Przy wybraniu ruchu człowieka
anulowane są niewysłane obliczenia bota. Nie zmieniono transportu, nie dodano
odpytywania ani blokujących pauz. Skróty U, F i B również podlegają zwykłej
walidacji gry, a nie blokadzie wynikającej z obecności oczekującego bota.

Uzgodnione „Za późno” to nie wykrywanie czasu reakcji. Przy włączonych
intercepcjach Enter na posiadanej, niepasującej karcie poza własną turą daje
3 punkty karne. Zwykła intercepcja wymaga zgodności koloru i figury, super
intercepcja tylko figury. Nie rozróżnia się pomyłkowego i zamierzonego Entera.
Karta zostaje w ręce, a kolejka, talia, stos i termin ruchu pozostają niezmienione.
Komunikat trafia do mowy i wspólnej historii bez wymieniania próbowanej karty;
nie towarzyszy mu dźwięk faktycznego zagrania. Niepasująca dzika karta nie
otwiera zbędnego wyboru koloru.

Zapis pozostaje pojedynczym zdarzeniem `play`. O wyniku próby rozstrzyga
uporządkowany replay: wcześniejszy ruch może sprawić, że intercepcja stała się
spóźniona albo że jest już zwykłą własną turą gracza. Własna tura, wyłączone
intercepcje, brak danej karty w ręce, obserwator, gracz wyeliminowany, zakończona
runda i aktywna faza reakcji na buzzer nie są traktowane jako ta kara.
Przekroczenie limitu punktów jest rozliczane przy zakończeniu rundy, jak dotąd.
Bot wybiera wyłącznie legalne działania, nie planuje celowo kary.

Sama kara nie rozpoczyna ponownie czasu oczekiwania bota. Deklaracja
`bot_delay_revision` UNO pomija takie zdarzenia wyłącznie dla lokalnej pauzy.
Obliczanie ruchu korzysta z nowego stanu, a zapis i potwierdzenie bota nadal
używają pełnej aktualnej rewizji zdarzeń. Pozostałe gry nie zmieniają klucza pauzy.

## Monopoly

Odtworzony komunikat korzystał bezpośrednio z etykiety listy zarządzania,
np. „Alice: Build on Mediterranean avenue, pink group; buildings: 0; cost: 50.”
Potwierdzenia mają teraz osobne krótkie zdania: gracz buduje/sprzedaje dom
lub hotel na nieruchomości, zastawia ją lub wykupuje zastaw. Przy sprzedaży
wszystkich budynków z grupy z powodu braku domów w banku komunikat nadal
poprawnie opisuje całą operację, nie sprzedaż jednego domu.

Mowa i historia korzystają z tego samego tekstu. Nie zmieniono list pod
H/Shift+H/K/Shift+K, cen, liczby budynków, pozostawania na liście, zasad
równomiernego budowania ani rozliczeń finansowych. Nowe zdania mają polskie
tłumaczenia w `PL.mo` i plikach źródłowych JSON.

## Weryfikacja

Przed poprawkami nowe regresje wykazywały blokowanie Entera i brak kary UNO
oraz powtarzanie etykiety listy w Monopoly. Po zmianach przeszły:

- `test/uno_interceptions_test.rb` — 9 grup: ludzie i boty, rzeczywista
  kontrolka i ekran, oczekiwanie/obliczenia bota, anulowanie niewysłanego planu,
  wspólny replay trzech czytelników, kolejność konkurujących zdarzeń, wyjątki
  kary, skróty i nieprzedłużanie pauzy;
- `test/monopoly_property_messages_test.rb` — wszystkie potwierdzenia,
  mowa trzech odbiorców, szczegóły list i niezmienione kwoty;
- `test/monopoly_management_ui_test.rb`;
- `test/bot_turn_controller_test.rb`, `test/bot_submission_test.rb`;
- `test/room_interface_test.rb`, `test/surface_framework_test.rb`;
- `test/game_rules_test.rb`, `test/game_rules_translation_test.rb`;
- `test/packaged_rules_encoding_test.rb` — binarne ładowanie bieżących źródeł;
- `tools/check-five-game-translations.rb`.

Nowe regresje dodano również do przyszłych uruchomień ograniczonego runnera
pięciu gier. Nie uruchamiano pełnego zestawu ani rzeczywistych klientów ELTEN-a.
Test kolejności zdarzeń nie zastępuje testu opóźnień sieci i reakcji na żywym
stole; do ręcznej próby należy potem przygotować nowy build dla uczestników.
