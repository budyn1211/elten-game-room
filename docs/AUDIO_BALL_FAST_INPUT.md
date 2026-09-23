# Audio Ball: szybkie naciśnięcia — 23 września 2026

## Aktualizacja bez restartu ELTEN-a

Pierwsza paczka tej poprawki miała regresję: `Array#held` w polu Audio Balla.
Po usunięciu starej przestrzeni aplikacji globalny obserwator klawiatury
pozostawał w hoście i zachowywał odwołanie do starej klasy, która zwracała
tablicę. Znacznik `true` blokował instalację nowej wersji. Testy startujące
w czystym procesie tego nie obejmowały; poprawne testy wejścia nie były
wystarczającym testem aktualizacji.

`Keyboard.install` teraz ponownie wiąże ten sam moduł z bieżącą aplikacją,
także po starej instalacji ze znacznikiem logicznym. Nie dokłada kolejnych
obserwatorów ani nie usuwa cudzych rozszerzeń. Odczyt metadanych akceptuje
tylko bieżący format, a stare naciśnięcia nie są odtwarzane. Zachowywane
jest celowe tłumienie przytrzymanych klawiszy; wynik klawiatury hosta i jej
pola nie są zmieniane. Jedyna produkcyjna poprawka tej regresji jest w
`lib/audio_ball/keyboard.rb`.

`test/audio_ball_keyboard_reload_test.rb` używa prawdziwego
`Programs::Execution::RuntimeBackend` do usunięcia/stworzenia przestrzeni
aplikacji przy pozostawieniu klawiatury hosta w tym samym procesie.
Przed poprawką odtwarzał dokładnie `Array#held` w linii 24 powierzchni.
Sprawdza aktualizację starego obserwatora, 20 kolejnych przeładowań,
szybkie naciśnięcia, modyfikatory, tłumienie, niepowielanie zdarzeń i brak
wywołań starej aplikacji. Można podać dwie gotowe paczki jako argumenty:
poprzednią i nową; wtedy oba pliki produkcyjne pochodzą wyłącznie z ich
binarnych rekordów. Standardowa kopia starego obserwatora w fixtures jest
identyczna z commitem `2006bfce` (bez odwołań do repo w trakcie testu).

## Dwa odtworzone problemy

1. Natywna klawiatura ELTEN-a może nie ustawić `pressed`, jeśli prawdziwe
   puszczenie i ponowne naciśnięcie wystąpiły pomiędzy sąsiednimi odczytami.
   Dotyczy to również krótkich, puszczonych naciśnięć w kolejnych klatkach.
2. Odczyt przytrzymania w Windows może wyprzedzać kolejkę naciśnięć.
   Pole Audio Balla zapamiętywało taki nowszy `held` i w następnej klatce
   odrzucało prawdziwe `pressed` jako wcześniejsze przytrzymanie. Odtworzono
   to z botem lokalnym i drugim klientem; nie wymaga awarii Communications.

Nie mamy zapisu fizycznego naciśnięcia konkretnej zgłoszonej partii. Próby
potwierdzają mechanizmy w kodzie, nie dowodzą, który wystąpił u użytkownika.

## Zakres naprawy

Lokalny obserwator `Keyboard` przypina do bieżącego natywnego wyniku tylko
uporządkowane zdarzenia ośmiu klawiszy gry, informację o modyfikatorach
i spójny stan przytrzymania z tej samej próbki. Nie zastępuje wyniku hosta,
nie zmienia jego pól, reguł pozostałych kontrolek ani kodu ELTEN-a.
Nie zapisuje historii klawiatury ani tekstu czatu. Metadane i kolejka są
ograniczone do 32 zdarzeń, zachowują najnowszy wybór i są konsumowane raz.

Nowe fizyczne naciśnięcie po puszczeniu jest rozpoznawane także wtedy,
gdy host nie ustawił `pressed`. Autopowtarzanie i drugi `down` bez `up`
nie są nowym poleceniem. Celowe tłumienie klawiszy przez hosta, modyfikatory,
utrata aktywności, czat, pomoc i ustawienia nadal blokują sterowanie grą.
Backend bez kolejności zdarzeń zachowuje ostrożny, pojedynczy fallback.

Nie zmieniono Client/Engine, fizyki, tolerancji obrony, botów ani sieci.
Wybór toru nadal należy do konkretnego nadlatującego lotu; wcześniejsze
naciśnięcie lub przytrzymanie sprzed lotu nie uzbraja obrony. Poprawny
wybór utrzymuje się do kontaktu. Nowy lot wymaga nowego naciśnięcia.
Nie cofamy bramki po już zakończonym rozstrzygnięciu.

## Regresje

- `audio_ball_fast_input_test.rb`: osiem klawiszy, sąsiednie klatki,
  release/repress, Windows held wyprzedzający kolejkę, focus/suppression,
  granica kolejki i szybko puszczone skróty z modyfikatorem.
- `audio_ball_input_boundary_test.rb`: 284 scenariusze początku lotu,
  obu miejsc, pięciu trudności, strzałek/liter, botów i klientów; ponadto
  korekta toru tuż przed kontaktem i brak cofania już naliczonej bramki.
- `audio_ball_native_field_test.rb`: rzeczywiste Form/Button/EditBox,
  Tab/Shift+Tab, czytnik pomocy F1 i ustawienia, bez utraty tekstu czatu.
- Istniejące keyboard/flight/lane/defense testują zgodność natywnego
  wyniku klawiatury, kolejność, modyfikatory, brak duplikatów i izolację lotów.
  `audio_ball_binary_test.rb` uruchamia regresje również z binarnych źródeł
  lub z przekazanej gotowej paczki, bez zastępowania runtime plikami z dysku.

Testy offline: prawdziwy kod hosta, symulowane urządzenie klawiatury, zegar,
audio i sieć. Nie jest to pomiar fizycznej klawiatury, odsłuch lub nowa
partia na serwerze. Nie zmieniać innych gier przy okazji tej poprawki.
