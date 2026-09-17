# Wdrożenie czterech planów — wersja 2.0

Nowszy punkt wznowienia: `RELEASE_2_0_PROGRESS.md`. Po ukończeniu
tych czterech planów użytkownik zlecił kolejne trzy oraz wydanie 2.0/227.
Poniższe wstrzymanie wydania opisuje wcześniejszą decyzję. Wyniki
pierwszego etapu zachowuje `IMPLEMENTATION_2_0_VERIFICATION.md`,
a drugiego `RELEASE_2_0_VERIFICATION.md`.

Polecenie użytkownika z 17 września 2026: wdrożyć plany po kolei,
następnie zbudować i podpisać paczkę 2.0. Bez instalacji i publikacji.
Punktem wyjścia są źródła 1.1.10/build 226 oraz zapisane projekty.
Zapisy serwerowe nie należą do zakresu; lokalne archiwa pozostają.

**Aktualizacja polecenia:** użytkownik wstrzymał budowanie i podpisywanie:
„jeszcze nie buduj nowego buildu, dodamy nowe gry”. Następnie doprecyzował:
dokończyć obecne cztery plany, a wstrzymać tylko wydanie. Nie zmieniono
wersji 1.1.10/build 226, nie utworzono nowej paczki. Kolejne gry i wydanie
wymagają dalszego polecenia.

## Kolejność i kontrola wykonania

- [x] Rummy: deterministyczne zasady wszystkich wariantów; pierwszy meld,
  joker i manipulacje; punktacja, kary, limity, blokada; uzgodniona ręka
  i robocze układy; zwykły bot; zasady, PL/EN, zapis i testy.
- [x] Wspólne poprawki: widget bez pobierania przy strzałkach; odświeżanie
  przy wejściu, R i co 5 s tylko przy aktywnym widgecie; subskrypcje nowych
  publicznych stołów; opóźnienie botów 0–5 s; oba warianty Reversi,
  nieograniczony dobrowolny pas, zgodny planer i stare archiwa.
- [x] Domino: zestawy/pojemność, warianty dobierania, jedna akcja sieciowa
  dla serii, drużyny istniejącym mechanizmem, punktacja i eliminacje;
  wspólna ręka kostek, bot, zasady, PL/EN, zapis i testy.
- [x] Mexican Train: rozdanie, stacje/pociągi, serie dubletów i ich stos,
  dobieranie/otwieranie, blokada, punktacja; interfejs, bot, zasady,
  PL/EN, zapis i testy.
- [x] Kontrola integracji: dotknięte mechanizmy pozostałych gier, czat/fokus/kursor, pomoc,
  protokół, celowane regresje, zgodność każdego punktu projektów.
- [ ] Wersja 2.0 i nowy build; changelog PL/EN; podpis i binarne
  wczytanie paczki, manifest/runtime/liczba plików/zawartość Ruby/hash.
  **Wstrzymane przez użytkownika, nie brak wykonania obecnych planów.**

Wdrożenie lokalne i celowana weryfikacja zakończone. Powyższe zaznaczenia
nie oznaczają testu gry na żywych klientach ani podpisanej paczki.
Szczegółowa kontrola punktów: [IMPLEMENTATION_2_0_VERIFICATION.md](IMPLEMENTATION_2_0_VERIFICATION.md).

## Dziennik

- Rozpoczęto od odczytu wszystkich projektów, instrukcji i architektury.
  Stan wyjściowy zachowany; bez instalacji i publikacji. Implementacja
  rozpoczęta od silnika Rummy. Brak wyników testów na tym etapie.
- Rummy: dodano silnik, bezpieczne fragmentowanie dużego wyłożenia w jednym
  ActionPlan, planer własnej ręki, edytor układów oparty na wspólnej ręce,
  menu stołu, reguły EN i rejestrację gry. Przechodzą rummy_test,
  rummy_surface_test, rummy_variants_test, rummy_edges_test oraz stare
  card_hand_cursor_test i playable_card_navigation_test. Pomiar planera:
  14 kart 0,5 ms, 32 karty 10,5 ms, 70 kart 251,6 ms (lokalny runtime,
  nie gwarancja szybkości prawdziwego klienta). Pozostają przegląd jakości
  strategii manipulacji, tłumaczenia PL, zapis/integracja i końcowa kontrola
  wszystkich punktów. Nie oznaczono jeszcze pełnego etapu jako zakończony.
- Rummy: dopisano tłumaczenia PL, kontrolę szkicu przed zapisem, test zapisu
  i wznowienia z mapowaniem botów oraz celowane decyzje strategiczne. Bot
  odrzuca niepotrzebne zabieranie układów i ostrożnie ocenia czekanie na rummy.
  Przechodzą wszystkie pięć skryptów Rummy oraz game_option_form_test.
  Etap 1 wdrożony; końcowa integracja i paczka nadal do sprawdzenia.
- Rozpoczęto etap 2. Wspólne bot_delay 0–5 trafia do definicji, walidacji,
  wykonania i zasad. UNO/Makao zachowują domyślne 1, inne gry 0. Reversi
  obsługuje oba warianty, P, stare archiwa i klucze planera. Celowany test
  czterech wariantów i ograniczonego wyszukiwania przechodzi. Konto papierek
  zostało ponownie odczytane przez MCP; użytkownik potwierdził zgodę na
  dodanie tabeli preferencji. Żadnej zmiany serwera jeszcze nie wykonano.
- Etap 2: wdrożono asynchroniczny widget, preferencje subskrypcji,
  ograniczoną kolejkę wysyłki, filtrowanie/odczyt nowych ogłoszeń oraz
  dołączanie zwykłą ścieżką. Wykonano zaakceptowaną próbę serwera na dwóch
  kontach i posprzątano dane próbne. Szczegóły: TABLE_WATCH_2_VERIFICATION.md.
  Celowane testy widgetu, subskrypcji, nowych wariantów Reversi, opóźnienia,
  zaproszeń, Makao i UNO przechodzą. Rozpoczęto etap 3: Domino.
- Etap 3: silnik Domino i jawna wspólna ręka kostek wdrożone. Celowane
  testy 11 zestawów, rozdań, dobierania, limitów, blokady, drużyn,
  punktacji, powtórzeń, czasu i podstaw strategii przechodzą. Test ręki
  potwierdza wybór stron, kursor, Z oraz zachowanie kontrolki przy zmianie
  stanu. Tłumaczenia, pomiar transportu i zapisy w końcowej integracji.
- Etap 4: dodano Mexican Train, osobne zasady pociągów i stos dubletów.
  Testy rozdań 2–8, cyklu stacji, starszego/środkowego dubletu, dobierania,
  prawdziwej blokady, punktacji i decyzji bota przechodzą. Użytkownik
  dodatkowo sam sprawdził w QC i potwierdził możliwość zamknięcia starszego
  dubletu we własnej serii. Krótką pauzę na jego sprawdzenie zakończono.
- Uzupełniono polskie tłumaczenia Domino/Mexican Train; kompilacja katalogu
  przeszła (2502 komunikaty z 27 plików). Ostatnia poprawka uzupełnia
  hand_epoch nowych rąk o właściciela, reset podglądu szczegółów pociągu
  po C oraz ponowny start mechanizmu powiadomień po zatrzymaniu rozszerzenia.
  Dodano test podglądu pociągów. Te ostatnie zmiany wymagają jeszcze
  uruchomienia testów — nie raportować ich jako sprawdzonych.

- Zakończono integrację: ręka kostek zachowuje kursor i szczegóły pociągu;
  zapis/wznowienie wszystkich trzech gier zachowuje fizyczne karty/kostki,
  mapowanie botów i obowiązki dubletów. Ponad 200 dobieranych kostek
  Domino oznacza jeden krótki zapis ruchu; największe wyłożenie Rummy
  (208 kart) mieści się w jednym wywołaniu z 12 ograniczonymi fragmentami.
- Sto kolejnych strzałek widgetu nie zleca pobierania. Start/stop
  rozszerzenia nie zachowuje zamkniętego nadawcy. Terminy nowych ogłoszeń
  korzystają z otrzymanego przez hosta czasu serwera i lokalnego zegara
  monotonicznego, bez dodatkowego odpytywania; przed pierwszą próbką
  hosta pozostaje zastępczy czas lokalny.
- Poprawiono ostatnią decyzję bota Domino w wariancie kończenia całą
  drużyną: własna ostatnia kostka nie jest traktowana jak wygrana, gdy
  partner nadal gra. Wybór końca uwzględnia publiczne informacje o partnerze,
  bez zaglądania w jego rękę. Uzupełniono 12 brakujących tłumaczeń.
- Wynik końcowy: 48/48 celowanych skryptów, składnia 53 plików Ruby,
  git diff --check. Katalog PL: 2514 wpisów; kontrola 203 wpisów nowych
  źródeł tłumaczeń i 194 tekstów nowych gier/interfejsu. Nie uruchamiano
  pełnego runnera. Raporty poza repo: diagnostics/implementation-2-0/.

## Punkt wznowienia

Obecne cztery plany są wdrożone i celowanie sprawdzone. Czekać na zakres
kolejnych gier. Nie rozpoczynać wydania z dawnego polecenia: użytkownik
chce dołożyć gry przed nową wersją i paczką. Manifest, numery w __app.rb,
changelog i podpisana paczka 226 pozostały bez zmian. Przed przyszłym
wydaniem powtórzyć kontrolę na ostatecznych źródłach, przygotować wspólny
changelog i zweryfikować binarne wczytanie dopiero z nowej paczki.

## Doprecyzowania wykonawcze w ramach zatwierdzonych planów

Nie są osobnym potwierdzeniem reguł QC. Przyjęto propozycje projektów:
dobrowolne dobranie zachowuje legalne starsze kostki; opóźnienie nowych
gier 0; czas Domino 0, a timeout nie daje drugiej kostki po dobraniu,
przy zakazie lub pustym stosie. Domino wybiera startera najwyższym
rozdanym dubletem w każdym rozdaniu, a bez dubletu najwyższą sumą oczek;
remisy rozstrzyga rotująca kolejność miejsc. 0–0 bada się osobno dla
każdej ręki, eliminacja dotyczy całej drużyny. Mexican Train losuje
pierwszego startera, potem rotuje; po zagranym dublecie zaczyna się nowa
decyzja z jednym możliwym dobraniem. Przy odpadnięciu wszystkich
pozostałych stosuje najniższy wynik i wspólną wygraną remisujących.
Opisy zasad w aplikacji ujawniają te szczegóły.
