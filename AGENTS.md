# Instrukcje dla agentów pracujących nad ELTEN Game Room

## Krowa i ponowne wydanie 229 — 18 września 2026

Najnowsze polecenie zezwala po zakończeniu weryfikacji zbudować i podpisać
tę samą 2.0.1/build 229 z Krową (PR #10, paoscripts, autor opisany na prośbę
użytkownika jako paulinux) i wcześniejszymi lokalnymi poprawkami audytu.
Zastępuje wcześniejsze wstrzymanie wydania, nie upoważnia do instalacji,
publikacji, GitHuba ani scalenia/zamknięcia PR-u. Changelog: zachować
28 wcześniejszych wpisów PL/EN i dodać TYLKO jeden opis Krowy z autorstwem.
Nie uruchamiać pełnego runnera; używać kontroli celowanych i gotowej paczki.

Zakres i dowody: docs/KROWA_IMPLEMENTATION.md oraz
../diagnostics/krowa-implementation/{SOURCE,SERVER,PACKAGE}.json.
Przyjęto poprawki 1–11 przeglądu. Baza rzeczowników, jej duplikaty,
kolejność i algorytm losowania pozostają identyczne z PR-em na wyraźne
polecenie użytkownika. Także osiem plików Audio/krowa-* bez edycji.
Nie usuwać duplikatów jako rzekomej optymalizacji.

Wyścig i Wieża mają prywatny lokalny sekret w pełnym zapisie. Wznowienie
musi go zweryfikować i zapisać pod nowym ID sesji PRZED publikacją archiwum
i startu. Brak sekretu nie może zostać uznany za udane wznowienie. Ujawnienie
po poddaniu w Wyścigu jest adresowaną wiadomością, nie wspólnym zdarzeniem.
Sprawdzać nadawcę, odbiorcę, fazę, rundę i zobowiązanie; nie odtwarzać starego
krowa_surrender_word jako ujawnienia. Kontroler nadal zna własny sekret.
Dzień Warszawy pochodzi z prawdziwego czasu serwera, nie epoki partii.
Usuniętych własnych słów nie odtwarzać przy ponownym czytaniu starej historii.

Cztery nowe tabele Krowy już dodano po potwierdzeniu konta papierek.
Zastane tabele i protected/powiadomienia zachowano. Nie powtarzać migracji;
testy publikacji/rankingów korzystają z atrap, nie żywych rekordów konta.
Nie osłabiać zamierzonej bramki dostępu do tabel. Metody klienta, rankingi,
ograniczenia ról i formularzy pozostają opcjonalnymi hookami Base, domyślnie
neutralnymi dla pozostałych gier. Nie utożsamiać testów z żywą rozgrywką.

## Poprawki po audycie klas — źródła, bez nowego wydania

Użytkownik zatwierdził potwierdzone błędy z listy 1–12, z wyjątkiem
punktu 2/F11 (zamierzona kontrola dostępu do tabel), bez optymalizacji
O01–O04. Wdrożenia i granice sprawdzenia opisuje docs/AUDIT_FIXES_229.md;
wyniki celowanych prób: ../diagnostics/audit-fixes-229/RESULTS.json.
Końcowo 59/59 uruchomień i 25 kontroli składni poprawnych, bez zmian
poza jawnym zakresem. Zachowano 579 wcześniejszych plików identycznie,
w tym dane, tłumaczenia, dźwięki, manifesty i changelog.
Starsze narzędzia merge-quiz-pool i refine-quiz-decisions-semantic-safety
nie są podłączone do obecnej ścieżki gry/danych/wydania; nie uruchamiać ich
na danych bez wcześniejszego usunięcia problemów F13/F14 z audytu.

Przy zmianach zegara sprawdzać nie tylko wolniejszy klient, ale też
pozostały czas po zapisie/wznowieniu oraz metadane serwera otrzymane
przed lub po odpowiedzi na zapis. Nie traktować lokalnego Time.now jako
potwierdzonego czasu serwera. Zachować ścisłe odrzucanie starych tur.
Ponowienie odpowiedzi na zaproszenie to nie ponowne zaproszenie: zachować
tożsamość decyzji, granicę czasu, izolację kont i brak podwójnej historii.
Wynik partii ma pozostać w historii, ale automatycznie odczytywać się raz.

Zmiany są niewydane. Nie budować/podpisywać na podstawie starszych wpisów.
2.0.1/229, changelog i podpisana paczka 9d2d6fdd… pozostają bez zmian.
Nie wykonano instalacji, publikacji, operacji GitHub, serwera ani profili.
Tylko testy celowane; nie przedstawiać symulacji jako prób żywych klientów.

## Ściszenie Statków: ponowne pakowanie 229 bez zmian changelogu

Użytkownik polecił przebudować i podpisać tę samą 2.0.1/build 229 ze
ściszeniem sześciu efektów Statków do 20% bazowego poziomu. Zachować
changelog PL/EN dokładnie bez zmian: dotychczasowe 28 punktów, bez nowego
wpisu o ściszeniu. Nie zmieniać nagrań, pauz, pozostałych dźwięków ani
preferencji użytkownika. Raport: docs/BATTLESHIP_SOUND_BALANCE.md.
Wyniki bieżącego pakowania: ../diagnostics/battleship-volume-229/SOURCE.json
i PACKAGE.json. Zachować poprzednią paczkę d49e824b… osobno; nie uznawać
samego tego wpisu za potwierdzenie wydania. Testy celowane, bez pełnego
runnera, instalacji, publikacji, GitHuba, serwera i zmian profili.

## Ctrl+F1: pusta lista skrótów — poprawka i ponowny build 229

Zgłoszenie Scrabble odtworzono przez pełną ścieżkę wyjścia z oczekiwania:
`wait_for_action` czyścił opisy w `ensure`, zanim otwierało się okno zasad.
Zachowywać jednorazowy snapshot aktualnej pomocy pól gry przed sprzątaniem;
nie usuwać cleanup ani nie przywracać stałych list nieaktualnych skrótów.
Nowy test `rules_help_lifecycle_test.rb` musi przechodzić przez Ctrl+F1/menu,
zakończenie oczekiwania i dopiero wyświetlenie listy. Samo przypięcie opisów
i bezpośrednie otwarcie okna nie odtwarza tego błędu. Sprawdzać też źródła
binarne i gotową paczkę, PL/EN, obserwatora oraz zachowanie kursora/czatu.
Raport: docs/RULES_HELP_LIFECYCLE_229.md. Użytkownik polecił przebudowanie
i podpisanie tej samej 2.0.1/229, zachowanie 27 punktów i jeden nowy PL/EN.
Wynik sprawdzać w ../diagnostics/rules-shortcuts-229/SOURCE.json i PACKAGE.json.
Zachować poprzednią podpisaną paczkę e1c7b20d…; bez instalacji, publikacji,
GitHuba, serwera, profili i pełnego runnera.

## Statki: audio i ustawianie floty; ponowny build 229 — 18 września 2026

Użytkownik zatwierdził sześć dźwięków Statków (dwa trafienia, trzy starty
rakiety, jedno pudło), odczekanie końca dźwięku przed kolejnym zdarzeniem
oraz wybór Losowo/Ręcznie po rozpoczęciu partii. Kolejka prezentacji jest
lokalna i włączona TYLKO w Statkach; inne gry nadal nakładają dźwięki.
Nie blokować czatu ani odbioru sieci, nie używać sleep, nie odpytywać serwera
z powodu samego zakończenia dźwięku. Tryb i ręczny szkic przeżywają odświeżenie;
losowa flota nadal jest prywatna, a powtórzenie wysłania zachowuje commitment.
Szczegóły: docs/BATTLESHIP_AUDIO_AND_SETUP_229.md.

Dodatkowa poprawka wspólnego formularza: po wybraniu gry zaczynać na
instrukcji „Wybierz opcje gry…”, nie na polu prywatności. Tab dopiero potem
przechodzi na Stół prywatny. Nie przestawiać pól ani zmieniać ustawień.
Zaktualizowano testy 25 formularzy oraz binarnego kodowania.

Najnowsze polecenie zatwierdza przebudowanie i podpisanie tej samej wersji
2.0.1/build 229. Zachować wcześniejsze 24 punkty changelogu, dodać trzy PL/EN.
Wynik końcowy sprawdzić w ../diagnostics/battleship-audio-setup-229/SOURCE.json
i PACKAGE.json — sam wpis nie potwierdza ukończenia pakowania. Zachować
poprzednią podpisaną 229 (aae9df52…). Testy celowane, bez pełnego runnera,
instalacji, publikacji, GitHuba, serwera i zmian profili.

## Statki/Mankala wdrożone; przebudowa 229 zatwierdzona, 18 września 2026

Najnowsze polecenie użytkownika znosi wcześniejsze wstrzymanie pakowania:
włączyć PR #8/#9 z uzgodnionymi poprawkami, uzupełnić changelog, przebudować
i podpisać tę samą 2.0.1/build 229. Bez instalacji, publikacji, GitHuba,
scalania PR-ów, zmian serwera/profili i pełnego runnera. Zachować wszystkie
wcześniejsze niewydane zmiany; teraz również mają wejść do paczki.
Gry włączono z zachowaniem autorstwa Dawida Piepera i przyjętych reguł Ayoayo.
Zakres i ograniczenia: docs/BATTLESHIP_MANCALA_229.md. Instrukcje obu gier
są przystępnymi opisami PL/EN z przykładami; polskie i angielskie źródła
służą redakcji, nie nadpisywaniu uzgodnionych odmian. Zachować ten standard.
Statki nie obsługują zapisu/wznowienia, dopóki nie będzie bezpiecznej obsługi
prywatnych flot obu graczy. Mankala korzysta ze wspólnego zapisu.
Walidacja i gotowa paczka są dokumentowane w katalogu roboczym
diagnostics/new-board-games-229/SOURCE.json oraz PACKAGE.json. Nie deklarować
zakończenia podpisywania na podstawie samego tego wpisu; sprawdzić wynik.


## PR #8/#9 — zatwierdzone zasady Ayoayo, 18 września 2026

Użytkownik zaakceptował poprawki przeglądu Statków i Mankali, po czym
zatwierdził zachowanie odmiany Ayoayo z PR #9 Pajpera. NIE zmieniać bicia
na wersję pozostawiającą własny kamień: PR zabiera kamienie przeciwnika
oraz własny kamień kończący ruch. Zachować też przyznawanie pozostałych
kamieni ostatniemu wykonującemu ruch przy zakończeniu z braku legalnego
ruchu. To przyjęty wariant, nie bezsporne błędy M1/M2 wcześniejszego audytu.
Doprecyzować te reguły w instrukcji PL/EN i testach, bez mieszania opisów
Mancala World i Johna Pratta. Raport skorygowano w
../diagnostics/pr-8-9-review-20260918/REVIEW.md.

Ten wpis dokumentuje decyzję, NIE wykonanie pozostałych poprawek ani
integrację PR-ów. Bez budowania, podpisywania, publikacji i zmian serwera;
wcześniejsze wstrzymanie wydania pozostaje aktualne.

## Tasowanie, kolejność wyników i changelog — niewydane, 18 września 2026

Na polecenie użytkownika dodano komunikat „Przetasowano talię.” i zasób
card-shuffle przy faktycznym recyklingu talii UNO, Makao, 99, Rummy oraz
Pokera dobieranego. Nie zmieniać RNG ani zasad dobierania: wspólny
GameRoomCardDeckHistory obserwuje istniejący licznik tylko po przyjęciu
zdarzenia. Historia i audio korzystają ze standardowej ochrony przed
powtórzeniem. Nowe rozdanie ani pusta talia bez kart do recyklingu nie są
takim zdarzeniem. Dźwięk CC BY 4.0; autor i źródło w THIRD_PARTY_NOTICES.

Odczyt punktacji pod S ma malejący wynik liczbowy i trwałe eliminacje na
końcu. Używać wspólnego score_announcement_order również w nowych grach;
nie sortować miejsc, nie zerować wyników, nie uznawać samego zera za
eliminację. Remisy zachowują kolejność miejsc; drużyny pozostają razem.
Nie zmieniać S służącego do liczenia pionków lub tylko własnych żetonów.
Monopoly sortuje majątek, a Poker sortuje cudze żetony pod Shift+S.

Uzupełniono istniejący changelog 2.0.1/229 w PL/EN: zachowano 14 punktów,
dopisano osiem zaległych, również o filtrach, zegarach, Ctrl+R i pomocy.
Wydanie nadal WSTRZYMANE: bez budowania, podpisywania, instalacji,
GitHuba, serwera i zmian profili. Szczegóły oraz wyniki bieżącej weryfikacji:
docs/CARD_RESHUFFLE_AND_SCORE_ORDER_229.md i
../diagnostics/card-reshuffle-scores-229/RESULTS.json.

## Wydanie wstrzymane; nowe limity czasu — 18 września 2026

Użytkownik wyraźnie zatrzymał budowanie i podpisywanie. W źródłach są
niewydane filtry kontaktów, wspólny thinking time i poprawki pomocy/Ctrl+R.
Najnowsze uzgodnienie: 99 po czasie traci jeden żeton, Poker automatycznie
pasuje. W wymianie Pokera dobieranego gracz all-in zachowuje karty bez
wymiany i nadal bierze udział w showdown — nie wolno go spasować.
Weryfikacja zakończona: 52/52 skrypty wspólne i 8/8 dodatkowych uruchomień
zegarów, składnia 59 Ruby, idempotencja zasad i binarne wczytanie. Jeden
osobny stary test wymian Monopoly nie przechodzi identycznie na HEAD
sprzed zmian; nie liczyć go jako zaliczonego. Szczegóły i granice kontroli:
docs/CONTACT_FILTERS_AND_TIMERS_229.md. Bez pełnego runnera i żywych
klientów. Numery 2.0.1/229, istniejąca podpisana paczka, GitHub, serwer
i profile bez zmian.
Starsze zgody na pakowanie poniżej nie upoważniają do nowego wydania.

## Ponowne pakowanie 2.0.1/229 — 18 września 2026

Najnowsze polecenie zatwierdza przebudowanie i podpisanie tej samej wersji
2.0.1/build 229 z formularzem prywatności, domyślnymi grami widgetu oraz
nowymi dźwiękami kostek w Domino i Mexican Train. Te trzy punkty dopisano
do istniejących 11 w tym samym changelogu PL/EN. Starsze statusy niewydania
poniżej opisują etap przed tym poleceniem. Zakres i testy:
docs/DOMINO_SOUNDS_229.md. Wynik podpisania i gotowego artefaktu sprawdzać
w ../diagnostics/release-2-0-1-refresh/PACKAGE.json, nie w historycznych
wynikach pierwszej 229. Poprzednią 229 z SHA 0ac85551… zachować osobno.
Tylko testy celowane, bez instalacji, publikacji, GitHuba i zmian serwera.

## Domyślne gry widgetu — poprawione, niewydane, 18 września 2026

Użytkownik zatwierdził jednorazowe włączenie sześciu gier z 2.0 w starych
ustawieniach oraz domyślne zaznaczanie każdej przyszłej nowej gry.
GameRoomPreferences normalizuje widget_games razem z widget_known_games;
nowe ID rejestru są domyślnie wybrane, zapisane ręczne odznaczenia zostają.
LEGACY_WIDGET_GAME_IDS jest zamkniętą listą 17 gier sprzed 2.0, wyłącznie
do migracji danych bez widget_known_games — nie dopisywać do niej nowych
gier. Samo zarejestrowanie kolejnej gry ma wystarczyć. Ustawienia zapisują
znane ID razem z wyborami; odczyt pozostaje bez zapisów na dysku. Nie
zmieniać tym mechanizmem lobby ani subskrypcji powiadomień. Opis:
docs/WIDGET_NEW_GAME_DEFAULTS.md; test widget_game_defaults_test obejmuje
aktualizacje, zapis/odznaczenia, niezależne profile i formularz ustawień.
13/13 testów celowanych, składnia trzech Ruby i diff check poprawne.
Bez pełnego runnera i żywych klientów. Bez nowej paczki: podpisana
2.0.1/229 z SHA 0ac85551… nie zawiera tej zmiany ani formularza prywatności.
Wersja, changelog i PL.mo niezmienione; nie instalowano, publikowano,
wysyłano na GitHub, zmieniano serwera ani żywych profili użytkownika.

## Prywatność tworzonego stołu — poprawione, niewydane, 18 września 2026

Na polecenie użytkownika przeniesiono „Stół prywatny” do wspólnego
formularza opcji, przed ustawieniami gry. `show_create_table` korzysta
z `configure_game_options(..., creating_table: true)`; wynik zawiera
osobno `game_options` i `private_table`. Zwykła edycja zachowuje dawny
wynik i nie pokazuje prywatności. Nie wkładać tego pola do definicji
opcji poszczególnych gier, JSON zasad ani zapamiętanego profilu.
Osobne `choose_table_privacy` usunięto. Domyślnie publiczny; wybór
przeżywa zmianę języka i walidację. Szczegóły:
`docs/PRIVATE_TABLE_CREATION_FORM.md`. 10/10 celowanych skryptów i składnia
trzech Ruby poprawne; nowe testy private_table_creation oraz
private_table_creation_encoding obejmują 23 gry i binarne ładowanie.
Nie przebudowano paczki: podpisana 2.0.1/229 z SHA 0ac85551… NIE zawiera
tej poprawki. Wersja, changelog i PL.mo niezmienione. Bez instalacji,
publikacji, GitHuba, serwera, pełnego runnera i żywych klientów.

## Przygotowanie wydania 2.0.1/build 229 — 18 września 2026

Najnowsze polecenie użytkownika zatwierdza zbudowanie podpisanej paczki
z wersją 2.0.1. Build 229 obejmuje 12 poprawek POST_228 oraz nowe zasady
23 gier. Nowy changelog PL/EN zawiera 11 punktów pod jednym nagłówkiem;
historyczne wpisy pozostają niezmienione. API nadal 3.0.3. Podpisana
228 ma pozostać nietknięta. Bez pełnego runnera, instalacji, publikacji,
GitHuba i zmian serwera. Zakres: `docs/RELEASE_2_0_1.md`.
Końcowe wyniki sprawdzać w katalogu roboczym poza repozytorium:
`../diagnostics/release-2-0-1/SOURCE.json` i `PACKAGE.json`. Sam ten wpis
nie jest potwierdzeniem ukończenia pakowania. Wcześniejsze zakazy budowania
dotyczą etapu sprzed najnowszego polecenia, nie wydania 2.0.1.

## Redakcja zasad wszystkich gier — ukończona w źródłach, 18 września 2026

Poprzednie 12 punktów wdrożono i zweryfikowano (POST_228_IMPLEMENTATION).
Następnie przepisano zasady 23 gier w PL/EN: 360 par akapitów, z przykładami,
wyjaśnieniem pojęć i wariantów według kodu. Źródła zewnętrzne porównano,
nie kopiowano ani nie zmieniano reguł silników. Lista skrótów pod strzałkami
w aktywnej grze korzysta ze wspólnych definicji F1 pola gry; biblioteka
zachowuje pełną instrukcję obsługi. Zasady to jeden dokument z nagłówkami,
obok skróty, przy stole także aktualne ustawienia. Raport i źródła:
`docs/RULES_REWRITE_REVIEW.md`, status: `docs/RULES_REWRITE_PROGRESS.md`.
15/15 końcowych skryptów celowanych, 63 Ruby ze sprawdzoną składnią,
207 symulowanych okien z binarnymi źródłami i rzeczywistym słownikiem hosta,
PL/EN/fallback. Bez pełnego runnera i żywych klientów. 2.0/228 i changelog
bez zmian; NIE budowano, podpisywano, instalowano, publikowano ani zmieniano
serwera/GitHuba. Podpisana 228 nie zawiera obu nowych etapów.

Przy kolejnych zmianach zasad edytować pary PL/EN w `docs/rulebooks/*.json`,
następnie uruchomić `tools/compile-rulebooks.rb`. Nie edytować wyłącznie
wygenerowanego `rule_sections`. Wspólne akapity mają tłumaczenia w
`locale/rules-shared-pl.json`. Nowa opcja wymaga wyjaśnienia i wpisu
w `docs/RULEBOOK_OPTION_COVERAGE.json`; indeks nie zastępuje sprawdzenia
znaczenia w kodzie. Zachować lokalne warianty i informować o różnicach
wobec źródeł. Nowe skróty przypinać do rzeczywistych kontrolek, bez drugiej
kopii aktualnej pomocy. Sprawdzać testy rulebook_authoring, rulebook_examples,
rules_live_help, rules_native_windows oraz dotychczasowe rules/encoding.
Przy przyszłym pakowaniu ponownie sprawdzić binarne wczytanie GOTOWEJ
paczki; obecne testy źródeł nie są dowodem jej zbudowania.

## Wdrożenie poprawek po 228 — 18 września 2026

Użytkownik polecił wdrożyć do kodu `docs/POST_228_FIXES_PLAN.md` (12 punktów).
Potwierdził Shift+C/Shift+H/Shift+M dla sortowania, z zachowaniem UNO/Rummy
i istniejącego Shift+C Biblios. Starszy status „tylko plan” poniżej opisuje
etap zbierania wymagań. Testy celowane, bez pełnego runnera; nie budować,
nie podpisywać, nie instalować ani nie publikować na podstawie tego polecenia.
Nie zmieniać serwera, numeru wersji i changelogu. Postęp i wyniki:
`docs/POST_228_IMPLEMENTATION.md`. Nie oznaczać niewykonanych prób jako
zaliczonych; podpisana paczka 228 nie zawiera tych nowych zmian.

## Kolejne poprawki po 228 — tylko plan, 18 września 2026

Bieżący zbiór nowych ustaleń: `docs/POST_228_FIXES_PLAN.md`.
Punkt 1 po doprecyzowaniu: sprawdzić potrzebę lokalnego zapisu odbiorów
powiadomień o nowych stołach; usunąć zbędny zapis albo przenieść potrzebny
do tła. Zmierzyć wpływ na opóźnienia komunikatu i blokowanie UI, zachować
filtry i obsługę dołączenia. Osobno ocenić seen/resolved i mechanizmy hosta:
restart ani dołączenie nie tworzy nowego powiadomienia, a sprzątanie listy
nie dowodzi konieczności zapisu każdego odbioru. Osobne pomiary etapów
odbioru. Próba syntetyczna wykazała blokującą ścieżkę, nie dowiodła
przyczyny rzeczywistego dwusekundowego incydentu. Użytkownik na razie
polecił tylko zapisać poprawkę i będzie dodawał kolejne. Bez implementacji,
nowego wydania, instalacji, publikacji i zmian serwera; czekać na polecenie.
Wydana 2.0/build 228 pozostaje aktualna i niezmieniona.
Punkt 2 tego samego planu: krótkie powiadomienie w kolejności właściciel,
gra, typ, np. „Papierek, Yahtzee, typ, nowy stół”, bez podwójnego „Nowy stół”.
Host łączy obecny tytuł z treścią zawierającą ten sam prefiks — potwierdzone
w kodzie. Sprawdzić odczyt i listę, etykietę typu, PL/EN i kodowanie;
nie zmieniać innych powiadomień ani działania dołączenia. Nadal tylko plan.
Punkt 3: wspólny wybór języka (zgłoszenie Quiz/Taboo) bez przeskoku fokusu
na zestaw. Strzałki nadal przeglądają języki; zestawy aktualizowane bez
zmiany fokusu, przejście ręcznie Tabem. Zachować inne opcje i ich walidację,
obsłużyć także Ctrl+X. Kod obecnie wymusza SET_OPTION_KEY po zmianie języka,
a test game_option_form_test tego oczekuje — oba do późniejszej zmiany.
Szczegóły i przyszłe testy w planie, bez wdrażania na obecnym etapie.
Punkt 4: uzupełnić F1 Makao o Shift+Enter (dodaj/usuń kartę z paczki),
bez drugiego handlera i niepoprawnego opisu dla wymiany w Pokerze.
Punkt 5: wspólne sortowanie własnej ręki; klawisze dopiero proponowane:
Shift+C kolor, Shift+H ranga z przełączaniem kierunku, Shift+M kolejność
otrzymania. Nie nadpisywać UNO/Rummy Shift+D ani Biblios Shift+C.
Zachować fizyczne ID, kursor i kolejność paczek/układów; bez zmian sieci
i reguł. PacketCardSurface nie obsługuje jeszcze sort_cards. Tylko plan;
nie traktować proponowanych klawiszy jako uzgodnionych.
Punkt 6: mieszane PL/EN w obu sekcjach pomocy Taboo. Bieżący PL.mo zawiera
tłumaczenia wszystkich 12 tekstów rule_sections; izolowany odczyt źródła
ich nie gubi. Sprawdzić rzeczywistą paczkę, wybór katalogu/kluczy i wspólne
akapity pomocy, bez zgadywania przyczyny. Docelowo oba dokumenty w języku
interfejsu niezależnie od języka kart. Szczegóły w planie; bez implementacji.
Punkt 7: zachować nakładanie niezależnych dźwięków. Wspólny mechanizm już
przekazuje wiele efektów, lecz ninety_nine_cue wybiera jeden specjalny
przez if/elsif. Potwierdzono brak reverse waleta przy 25 → 35 i 60 → 70:
draw2 zastępuje efekt karty. Zbierać skutki niezależnie, sprawdzić podobne
przypadki innych gier, bez pauz/uciszania, z zachowaniem głośności i ochrony
przed powtórzeniem tego samego zdarzenia. Nadal tylko plan, bez zmian kodu.
Punkt 8: dźwięk farkle_bank.ogg po zaakceptowanym odłożeniu punktów (bank),
nie zapis partii. Plik źródłowy ma faktycznie nazwę Dokumenty/freesound/
farkle)bank.ogg; przy wdrożeniu skopiować jako Audio/farkle_bank.ogg.
Zachować równoczesny dźwięk wyniku i ustawienia głośności. Tylko plan;
nie kopiowano pliku, nie zmieniano kodu ani paczki.
Punkt 9: ninety3366.ogg z Dokumenty/freesound przy trafieniu dokładnie
w 33/66 w grze 99. Powiązać z istniejącą regułą wzrostu do progu, nie
przeskoczeniem, spadkiem ani pozostawieniem sumy. Zachować nakładanie
efektów i głośności; plik potwierdzony, szczegóły w planie. Bez wdrażania.
Punkt 10: zastąpić wspólny dźwięk wygranej całej partii win2 plikiem
Dokumenty/freesound/win_party.ogg. Nie dodawać go obok starego, zachować
wygrane/przegrane rund win1/lose1, drużyny i ustawienia głośności.
Plik potwierdzony, szczegóły w planie; bez kopiowania i wdrażania.
Punkt 11: analogicznie zastąpić wspólny dźwięk przegranej całej partii
lose3 plikiem Dokumenty/freesound/lose_party.ogg, bez dwóch efektów
przegranej. Zachować lose1 dla rund, wynik drużyny, głośność i nakładanie
z ruchem. Doprecyzowanie: lose_party już przy trwałej eliminacji gracza
lub drużyny z partii, bez ponowienia na końcu tej samej partii ani przy
odświeżeniu. Nie mylić z odpadnięciem tylko z rundy (UNO No Mercy),
pasowaniem czy rozłączeniem; przy końcu partii respektować ostatecznych
zwycięzców/remis. Samo zastąpienie pliku w result_cue nie wystarczy,
bo dziś wymaga finished?. Plik potwierdzony, szczegóły w planie; bez
kopiowania i wdrażania.
Punkt 12: 1000_mariage.ogg z Dokumenty/freesound przy skutecznym mariażu
w Tysiącu, własnym/cudzym i bota, słyszalny u uczestników i obserwatorów.
Powiązać z zaakceptowanym play w trybie marriage, nie zwykłym królem/damą
ani odrzuconą próbą. Zachować równoczesne efekty, głośność i deduplikację.
Plik potwierdzony, szczegóły w planie; bez kopiowania i wdrażania.

## Build 228 — kodowanie ustawień, 17 września 2026

Użytkownik polecił zbudować i podpisać 2.0/build 228, kopiując cały changelog
227 i dopisując tylko poprawkę kodowania w PL/EN. Następnie, po pozytywnej
weryfikacji gotowej paczki, wysłać źródła na GitHub. Bez instalacji
i publikacji na ELTEN-ie; poprzednią paczkę 227 pozostawić bez zmian.
Naprawa wspólnych OptionDefinition/OptionChoice normalizuje etykiety
do UTF-8. Brak tłumaczenia angielskiej etykiety z myślnikiem pozostawiał
ASCII-8BIT; rosyjski opis stanu CheckBox wywoływał wyjątek. Nie zmieniać
reguł Reversi, wartości opcji ani globalnych kontrolek/gettext hosta.
Źródłowe testy regresji objęły 23 gry, 72 formularze i 276 stanów pól;
dodatkowo sprawdzono rzeczywisty kod CheckBox. Dotychczasowa paczka 227
odtwarza błąd. Nową sprawdzić również przez
`test/game_option_encoding_test.rb PACZKA`, kontrolę podpisu i zgodności
źródeł. Tylko testy celowane, bez pełnego runnera. Raport przygotowania
i wynik końcowy poza repo: `../diagnostics/option-encoding-228/`.
Poniższe wpisy 227 opisują poprzednie etapy, nie bieżący numer wydania.

## Komunikaty dodania/usunięcia nazwanych botów — 17 września 2026

Po ręcznym zgłoszeniu stwierdzono, że poprzednia paczka z imionami nadal
zapisywała bezimienne zdarzenie „dodano komputer”. Poprawiono wspólną
historię i odczyt: „Dodano Maślana.” / „Usunięto Maślana.”, bez słowa
„komputer” i dodatkowego wskazania dodającego w komunikacie stołu.
Globalne lobby zachowuje właściciela/rodzaj gry. Zdarzenie przechowuje
stabilne ID bota w istniejącym polu message; nie odtwarzać imienia
z bieżącego numeru miejsca, zwłaszcza po usunięciu innego bota.
Bez nowych kolumn, dodatkowych żądań i ujawniania prywatnych stołów.
Nie tworzyć migracji starych historii. Użytkownik polecił ponownie
przebudować i podpisać 2.0/build 227 z tym samym changelogiem. Wyniki
celowanych testów i kontrola artefaktu: ../diagnostics/bot-name-activity-227/.
Nie instalować i nie publikować. Starsze opisy dotyczą poprzednich paczek.

## Imiona botów i zgoda na przebudowanie 227 — 17 września 2026

Użytkownik przekazał listy 24 PL i 26 EN oraz polecił po tej zmianie
przebudować i podpisać ponownie 2.0/build 227. To zastępuje wcześniejsze
wstrzymanie pakowania. Changelog zachować, z punktami Biblios i imion botów
w PL/EN. Imię wybierane przy dodaniu, według interfejsu dodającego; bez
powtórzeń przy stole i ponownego losowania przy odświeżaniu. Wszyscy
widzą to samo imię, także po zapisaniu i wznowieniu nowej partii.
Użytkownik potwierdził brak starych zapisów: nie dorabiać ich migracji.
Stałych kodów imion w lib/bot_names.rb nie przestawiać ani nie używać
ponownie dla innych imion. Nowe pokoje używają discovery protocol 5,
aby starszy klient nie uznał nazwanego bota za człowieka. Bez zmian tabel
serwera. Testy celowane; punkt wznowienia: docs/POST_227_IMPLEMENTATION.md,
wyniki poza repo w ../diagnostics/bot-names-227/. Nie instalować ani
publikować; GitHub i rzeczywiste klienty bez zmian.

## Scrabble, Mexican Train i Biblios wdrożone; paczka wstrzymana — 17 września 2026

Na polecenie użytkownika wdrożono POST_227_GAME_CHANGES_PLAN w źródłach:
Scrabble Enter/lista/Enter, Backspace pod kursorem, cyfry tylko czytają,
bez H/V/N i skrótów układających litery; Mexican Train pokazuje wszystkie
pociągi, wyjaśnia odmowę, Z/Shift+Z tylko wskazuje legalne kostki.
Biblios z PR #7 dawidpieper zintegrowano lokalnie, bez scalania na GitHubie.
Naprawiono obsługę zdarzeń, duże płatności, prywatność i heurystyki bota,
dodano PL oraz dźwięki. Użytkownik wyraźnie polecił zachować talię i wariant
PR: 87 kart, w tym 45 kategorii/18 złota/24 kościelne. Nie zastępować ich
składem pudełkowej edycji. Rejestr ma 23 gry.

25/25 celowanych skryptów, składnia 37 Ruby, diff check i binarne wczytanie
bieżących źródeł z API tasowania hosta poprawne. Bez pełnego runnera
i ręcznych partii rzeczywistych klientów. Numery 2.0/227 bez zmian;
changelog PL/EN ma jeden dodatkowy punkt Biblios, pozostałe zachowane.
Raport: `docs/POST_227_VERIFICATION.md`; punkt wznowienia:
`docs/POST_227_IMPLEMENTATION.md`. Logi poza repo:
`../diagnostics/post-227-plan/`.

**Najnowsze polecenie wstrzymuje pakowanie i podpisywanie:** użytkownik
zapowiedział jeszcze jedną poprawkę. Czekać na nią i nowe polecenie
budowania. Nie instalować, nie publikować, nie zmieniać serwera.
Dotychczasowa paczka 227 c8dd0b8c… niezmieniona i nie zawiera tych zmian
ani wcześniejszych niewydanych poprawek Rummy. Starsze wpisy „tylko plan”
poniżej są historyczne; źródła wdrożone, wydanie nadal wstrzymane.

## Kolejny plan Scrabble, Mexican Train i Biblios — 17 września 2026

Użytkownik zaakceptował uproszczenie Scrabble (Enter/lista/Enter, Backspace
pod kursorem, 1–7 odczyt, bez formularza słowa, menu i H/V/N) oraz Mexican
Train: lista wszystkich pociągów, także zamkniętych, wyjaśnienia odmowy,
pierwszeństwo obowiązku dubletu. Z/Shift+Z tylko wskazuje legalne kostki,
bez automatycznego ruchu. Nowy PR dawidpieper #7 dodaje Biblios, bota,
zasady i testy; tłumaczenia PL do uzupełnienia. Head eee45867b29b9926026499159301cc3e4e038d88.
Pełny zakres: `docs/POST_227_GAME_CHANGES_PLAN.md`. To tylko plan;
PR otwarty, niescalony, bez pełnego audytu/testów. Nie wdrażać, nie budować,
nie podpisywać ani publikować bez kolejnego polecenia. Zachować wszystkie
wcześniejsze niewydane poprawki oraz istniejącą paczkę 2.0/227 bez zmian.

## Naprawy audytu interfejsu i przełącznik stron Domino — 17 września 2026

Użytkownik doprecyzował G/D jako zapamiętany wybór strony, a następnie
polecił „i popraw od razu resztę”. Osiem punktów poprzedniego audytu
obsłużono w źródłach. Domino: G lewo/D prawo bez ruchu; Enter przy obu
końcach używa preferencji bez pytania, przy jednym gra legalnie bez zmiany
preferencji. Domyślnie prawo. Stan lokalny zachowany po odświeżeniu,
podglądzie, odtworzeniu kontrolki i między rozdaniami. Z bez zmiany.
Mexican Train nadal ma wybór pociągu. Oba podglądy używają ID kostek/
pociągów; nowa runda zamyka stary podgląd. C/V nie blokuje wybór celu:
zostaje bezpiecznie anulowany. Nie czytać ukrytej ręki; Escape z wyboru
czyta samą kostkę. Scrabble: Backspace wraca na pole usuniętej płytki,
pusty szkic prosi o co najmniej jedną płytkę, a nie dwie nowe litery.
Zasady, boty i zdarzenia bez zmian. PL/EN, pomoc i projekt uaktualnione.
16/16 celowanych skryptów przeszło, w tym 15 nowych scenariuszy oraz
binarne ładowanie bieżących źródeł pod symulowanym API hosta. Bez pełnego
runnera, żywych klientów, serwera, wersji/changelogu i pakowania. Raport:
`docs/NEW_GAMES_INTERACTION_AUDIT_227.md`; wyniki poza repo w
`diagnostics/new-games-interaction-fixes-227/`. Paczka 2.0/227 o SHA
c8dd0b8c… nadal nie zawiera tych zmian ani wcześniejszych poprawek Rummy.
Nie budować/podpisywać/instalować/publikować bez nowego polecenia.

## Rummy i audyt interfejsu nowych gier — 17 września 2026

Nowsze niż paczka c8dd0b8c…: poprawiono źródła Rummy, D jako odczyt bez
listy, Shift+D bez dodatkowego Entera przy jednej legalnej możliwości,
widoczność tylko wierzchniej karty w single discard. Naprawiono również
menu, utrzymywanie wyborów po odświeżeniu, kursor i odczyty oraz publiczne
komunikaty; polskie tłumaczenia i zasady uaktualnione. Nie zmieniać stosu
potrzebnego do recyklingu tylko po to, żeby ukryć starsze odrzuty.
23 nowe scenariusze Rummy i łącznie 19 celowanych skryptów przechodzą.

Na dodatkowe polecenie „poszukaj” zbadano Domino, Mexican Train, Scrabble
i Taboo. Osiem nowych problemów UI/komunikatów odtworzono w diagnostyce;
NIE wdrażano ich napraw bez polecenia. Osobno użytkownik polecił skrócić
Mexican Train: C ma nagłówek „Pociągi”, bez stacji, a wiersze i wybory
celów np. „papierek, 9, otwarty”, bez słowa „koniec”. Wdrożono PL/EN,
bez zmian stacji w regułach i szczegółach; dublety i otwartość zachowane.
Taboo bez nowego potwierdzonego
błędu w zbadanych scenariuszach. Szczegóły, przyczyny, propozycje i zakres:
`docs/NEW_GAMES_INTERACTION_AUDIT_227.md`. Nie ogłaszać gwarancji bezbłędności.
Bez pełnego runnera, żywych klientów, wersji, changelogu, serwera, nowej
paczki, instalacji i publikacji. Podpisana 2.0/227 z c8dd0b8c… NIE zawiera
tych najnowszych poprawek Rummy ani opisów Mexican Train. Nie przebudowywać
bez nowego polecenia.

## Tasowanie i powrót na widget — źródła po 227, 17 września 2026

Naprawiono wywołania `Array#shuffle(random: ...)` w rozdaniu i wymianie
liter Scrabble oraz dobieraniu nowej talii Taboo. Wspólny
`GameRoomRandom.shuffle(values, random: rng)` działa bez nadpisanego przez
ELTEN-a Array#shuffle i zachowuje dotychczasową kolejność oraz stan RNG.
Test z zerową liczbą argumentów hosta odtwarzał błąd także z ostatniej
podpisanej paczki. Obowiązkowa reguła zgodności tasowania jest niżej.

Na kolejne zgłoszenie porównano widget ze źródłem sprzed zmian (HEAD,
build 226). Przywrócono kolejność przy wejściu: zadanie ELTEN-a pobiera
listę, dopiero potem natywny fokus ją odczytuje. Strzałki nie pobierają;
co 5 sekund tylko na aktywnym widgecie nadal działa cicha operacja w tle.
Wynik rozpoczęty przed ponownym wejściem nie nadpisuje nowszej listy.
Żądania są szeregowane; błąd wejścia nie odczytuje starego stołu.
Użytkownik następnie polecił przebudować i podpisać ponownie 2.0/build 227,
bez zmiany changelogu. Wynik kontroli gotowego artefaktu, jego SHA i rozmiar:
`../diagnostics/shuffle-widget-entry-227/PACKAGE.json`. Poprzednia paczka
z SHA f5097d11… nie zawiera tych poprawek i jest zachowywana osobno.
Nie instalować ani nie publikować bez nowego polecenia.

## Powiadomienia i widget po 227 — 17 września 2026

Naprawiono odrzucanie prawdziwych tokenów LiveSessions przez filtr UUID
powiadomień o nowych stołach. Zamiast pustego tekstu niedostępne ogłoszenie
ma wyciszoną treść zastępczą. Widget rozróżnia wczytywanie, brak wyników
i błąd; ogłasza pierwszy wynik na aktywnej pustej liście, zachowując ciszę
odświeżenia okresowego i bieżący kursor. Regresje najpierw odtworzyły błędy.
Szczegóły: `docs/NOTIFICATIONS_WIDGET_227_FIXES.md`. Użytkownik polecił
podpisać ponownie ten sam build 227, bez zmiany changelogu. Wyniki paczki
i testów: `../diagnostics/table-notice-widget-227/`. Jedna osobno zatwierdzona
próba powiadomienia na obu kontach została sprzątnięta; schemat, preferencje,
inne powiadomienia i zainstalowany program niezmienione. Nie instalować
ani nie publikować bez nowego polecenia.

## Poprawki po ręcznym teście 227 — 17 września 2026

W źródłach naprawiono brak odczytywania publicznych ruchów pięciu nowych
gier oraz wyjątek UTF-8/ASCII-8BIT w Mexican Train i wspólnych nazwach
kostek. Dodatkowy przegląd, zakres i ograniczenia: `docs/NEW_GAMES_227_FIXES.md`.
24 skrypty celowane, składnia 12 Ruby i diff check przeszły. Nie użyto
pełnego runnera ani rzeczywistych klientów. Moduł publicznych ogłoszeń jest
opt-in; nie włączać go dla historii zawierających prywatne dane gracza.
Wersja nadal 2.0/227. Następnie użytkownik polecił przebudować i podpisać
ten sam build z tym samym changelogiem oraz sprawdzić schemat serwera
i ustawić protected false. Wynik gotowej paczki i kontroli serwera:
`../diagnostics/new-games-227-postrelease/`. Bez instalacji i publikacji.

## Źródła 2.0/build 227 — trzy plany wdrożone, 17 września 2026

Scrabble (PL SJP/EN Wordnik, bez botów), Taboo (500 kart PL i 500 EN,
bez botów, zewnętrzna rozmowa) i siedem punktów NEXT_FIXES_PLAN wdrożono.
Zachowano Rummy, Domino, Mexican Train i poprzednie poprawki wspólne.
Farkle kończy bieżący obieg po limicie, stare zapisy mają starą regułę;
boty oceniają lidera i pozostałe tury bez zwiększania budżetu wyszukiwania.
Ctrl+X edytuje następną partię, Ctrl+Q trwale przerywa konkretną bieżącą,
bez zamknięcia stołu. Nowe pokoje mają discovery protocol 4 i wymagają 2.0.
Master-obserwator rozpoznawany niezależnie od pierwszego grającego miejsca;
Taboo nadal sprawdza rzeczywistego autora decyzji moderatora.

Changelog EN/PL: `docs/CHANGELOG_2_0.md`, 14 punktów pod jednym nagłówkiem.
Kontrola: `docs/RELEASE_2_0_VERIFICATION.md`, punkt wznowienia:
`docs/RELEASE_2_0_PROGRESS.md`. 48 celowanych skryptów, składnia 98 Ruby,
git diff --check i binarne wczytanie źródeł poprawne. Bez pełnego runnera
i ręcznych partii na rzeczywistych klientach. Wyniki gotowej podpisanej
paczki są zapisywane poza repo w `diagnostics/release-2-0/` obok projektu.
Nie instalowano ani nie publikowano. Starsze akapity „tylko plan” oraz
„wydanie wstrzymane” poniżej są historią wcześniejszych ustaleń.

## Wdrożenie trzech planów i wydanie 2.0 — 17 września 2026

Użytkownik polecił wdrożyć docs/SCRABBLE_DESIGN.md, docs/TABOO_DESIGN.md
i docs/NEXT_FIXES_PLAN.md, następnie zbudować i podpisać wersję 2.0
z changelogiem PL/EN. Starsze ograniczenia planowania/wstrzymania wydania
nie blokują tego polecenia. Zachować wcześniejsze lokalne wdrożenia.
Bez instalacji ani publikacji. Bieżąca kontrola: docs/RELEASE_2_0_PROGRESS.md.
Testy celowane, bez pełnego runnera. Nie deklarować niewykonanych etapów.

## Trzeci plan poprawek — zbieranie wymagań, 17 września 2026

Użytkownik zapowiedział kolejny plan po Scrabble i Taboo. Punkt wznowienia:
`docs/NEXT_FIXES_PLAN.md`. Nowe punkty: D odczytuje kości; Yahtzee V/Shift+V
otwiera własną/cudzą kartę punktacji; gry alfabetycznie według lokalizowanych
nazw; nazwa „99”, z zachowaniem ID `ninety_nine` i zapisów.
D już działa w Farkle. Użytkownik potwierdził dodanie odczytu w Yahtzee
i Chińczyku, zachowanie w Farkle i pozostawienie Monopoly bez zmian
(D oznacza tam niekupione nieruchomości).
Użytkownik zatwierdził PR #6 dawidpieper jako punkt 5 planu wraz
z dostosowaniem botów i tłumaczeniami. Dokończenie bieżącego obiegu
po osiągnięciu limitu, najwyższy wynik/remis, nie dodatkowa tura każdego.
Bot ma oceniać lidera i pozostałe tury; sam limit nie oznacza wygranej.
Poprawić strategię, pomocnicze oceny i pamięć wyników bez istotnego
zwiększania kosztu. Uzupełnić tłumaczenia PL i zgodne zasady EN.
Szczegóły, commit, przyszłe testy i zgodność zapisów w planie.
Wyłącznie akceptacja planu: PR niescalony, kod/boty/tłumaczenia nadal
niezmienione, bez testów gry. Czekać na osobne polecenie wdrożenia.
Punkty 6–7 w planie: Ctrl+X edytuje aktualne ustawienia dla następnej
partii, tylko master i poza aktywną grą. W polach tekstu nadal wycinanie.
Ctrl+Shift+X/zmiana gry poza zakresem. Ctrl+Q przerywa obecną partię
przez mastera, bez zamknięcia stołu, wyrzucania ludzi czy fikcyjnego wyniku.
Trwała, wspólna granica dla ID partii blokuje późniejsze ruchy, timeouty
i wyniki botów; wszyscy wracają do oczekiwania. Potem można zmienić
opcje i ręcznie zacząć od nowa w tej samej LiveSession. Krótkie pytanie
potwierdzające Ctrl+Q jest propozycją zabezpieczenia. Nie utożsamiać
tego z odwracalnym zamrożeniem Ctrl+S. Zachować czat, role i boty;
sam status stołu nie wystarczy. Szczegóły i przyszłe testy w planie.
Nadal tylko dokumentacja, bez zmian kodu, testów gry i wydania.
Nie zgadywać dalszego zakresu ani nie przywracać starych pomysłów.
Nie mylić go z już wdrożonym planem widgetu/powiadomień/Reversi/botów.
Tylko planowanie, bez kodu funkcji, serwera, testów gry i wydania.

## Taboo — plan gotowy do wdrożenia, 17 września 2026

Patrz `docs/TABOO_DESIGN.md`. Wyłącznie gra głosowa przez zewnętrzną
rozmowę/konferencję lub na żywo ze słuchawkami. Użytkownik potwierdził
4/6/8 ludzi i dwie równe drużyny, talie PL/EN docelowo po 500 sprawdzonych
kart oraz zatwierdzanie rozliczenia każdej tury przez mastera z korektami.
Wymaga wzorowania kart na istniejących zestawach. Adaptacje dopiero po
kontroli pochodzenia, licencji i każdej karty; zachować autorów i źródła.
Dotychczas odczytano tylko próbki tabooo/Taboo-Data, nie pełne audyty.
Nie zaimportowano ani nie przygotowano jeszcze docelowych zestawów.
Użytkownik zatwierdził następnie cały plan jako gotowy do wdrożenia.
Obejmuje to dźwięki: buzzer2 na brzęczyk, shuffle na start tury, replay na odgadnięcie, skip na
pominięcie, ding na koniec czasu, win2/lose3 na wynik całej partii według
drużyny. Bez sygnału każdej nowej karty i tykania zegara. Plan gotowy, ale
gra, talie i ich testy jeszcze niewykonane. Nie obiecywać rozpoznawania
mowy czy integracji konferencji.
Karta Taboo nie jest ręką karcianki: bez automatycznego Z i jej kursora.
Oznaczenie planu jako gotowego nie jest poleceniem implementacji.
Teraz użytkownik chce przygotować trzeci plan kolejnych poprawek.
Ten krok wyłącznie dokumentacyjny, bez testów gry, serwera, kodu funkcji,
zmiany wersji 1.1.10/226, paczki i publikacji. Scrabble nadal osobnym planem.

## Scrabble — zaakceptowany plan, bez wdrażania, 17 września 2026

Patrz `docs/SCRABBLE_DESIGN.md`. Użytkownik zaakceptował projekt po
usunięciu botów i wyborze PL/EN: jedna gra, 2–4 graczy, pierwszy wybór
języka w ustawieniach stołu, niezależny od języka interfejsu. Wykorzystać
profile content/languages.rb i dane content, nie duplikować silnika.
Akceptacja planu nie jest poleceniem wdrożenia. Solo i 5–8 osób poza zakresem.

Sprawdzono na jego polecenie końcowe rozliczenie PFS: odjąć wartości
stojaków, przy wyjściu dodać ich sumę kończącemu, przy blokadzie bez premii,
blank 0. Nie zmieniać innych reguł QC przy okazji tej korekty; remisy
wspólne są wyborem naszego planu, nie potwierdzeniem reguły QC.
Nowa rekomendacja EN po badaniu to otwarta lista Wordnika na MIT
2021-07-29: 198 422 wpisy, 194 152 po filtrze 2–15 liter. Dokument zawiera
źródło, commit, SHA i ograniczenia (nie NWL/Collins/QC, brak części form
brytyjskich). W pamięci sprawdzono strukturę całości i próbkę, nie pełną
merytorykę; nie dodano danych do gry. Porównany starszy ENABLE2K ma
braki m.in. qi/za/blog. Wordnik pozostaje rekomendacją, nie osobno
zatwierdzonym wyborem. Polski SJP nie jest OSPS; całej listy PL jeszcze
nie pobrano. Nie testowano żywego QC. Poprzednie cztery plany ukończone,
wydanie wstrzymane. Ten krok tylko dokumentacja; bez kodu gry, serwera,
testów gry, zmiany wersji 1.1.10/226, paczki i publikacji.

## Cztery plany wdrożone lokalnie — 17 września 2026

Dokończono Rummy, poprawki wspólne, Domino i Mexican Train. 48/48
celowanych skryptów, składnia 53 Ruby i git diff --check przeszły;
bez pełnego runnera. Kontrola punkt po punkcie i granice testów:
`docs/IMPLEMENTATION_2_0_VERIFICATION.md`. Bieżący punkt wznowienia:
`docs/IMPLEMENTATION_2_0.md`. Próba preferencji/powiadomienia na dwóch
kontach jest zakończona, dane testowe usunięte, nowa pusta tabela
`table_watch_preferences` pozostaje. Nie testowano jeszcze ręcznie
rozgrywki nowych gier na dwóch rzeczywistych klientach.
Użytkownik chce najpierw dodać następne gry. Wersja/manifest/changelog
pozostają 1.1.10/build 226, poprzednia podpisana paczka ma niezmieniony
hash. Nie budować, nie podpisywać, nie instalować ani nie publikować
bez nowego polecenia; nie zgadywać kolejnych gier. Starsze ograniczenia
„tylko plan” niżej są historią, nie powodem do cofania wdrożenia.

## Wydanie wstrzymane — najnowsza decyzja, 17 września 2026

Użytkownik polecił jeszcze nie budować nowego buildu, ponieważ chce dodać
kolejne gry. Doprecyzował: dokończyć obecne cztery plany i ich weryfikację,
a wstrzymać tylko zmianę wersji, budowanie i podpisywanie. Wersja pozostaje
1.1.10/build 226, bez instalacji i publikacji. Zakres kolejnych gier poda
użytkownik. Punkt wznowienia: docs/IMPLEMENTATION_2_0.md.

## Wdrożenie wersji 2.0 — bieżące polecenie, 17 września 2026

Użytkownik zatwierdził wdrożenie czterech planów, kolejno: Rummy,
SAVES_WIDGET_NOTIFICATIONS_PLAN (cztery punkty bez chmury), Domino,
Mexican Train. Następnie zbudować i podpisać wersję 2.0, bez instalacji
i publikacji. Starsze zapisy „bez wdrażania” poniżej są historyczne.
Stan prac i lista kontroli: docs/IMPLEMENTATION_2_0.md. Nie oznaczać
niezakończonych funkcji/testów jako ukończonych.


## Reversi — warianty zapisane w planie, 17 września 2026

Punkt 4 `docs/SAVES_WIDGET_NOTIFICATIONS_PLAN.md`: Allow passing oraz
Mandatory capture, oba domyślnie zaznaczone według opisu użytkownika.
Pierwsze dopuszcza dobrowolny pas mimo ruchu; wyłączenie nie blokuje
przymusowego pasa przy jego braku. Drugie wymaga odwrócenia pionka;
wyłączone pozwala postawić bez bicia, ale tylko obok istniejącego pionka,
na pustym polu. Plan przyjmuje osiem kierunków i dowolny kolor sąsiada;
nie jest to osobno sprawdzona reguła QC. Możliwe bicie nadal odwraca pionki.
Uwzględnić oba warianty w całym planerze bota, legalności, ocenie pozycji,
kluczach pamięci, replayu i zakończeniu gry. Stare archiwa bez opcji muszą
zachować poprzednie zasady. Użytkownik rozstrzygnął: P pomija własną turę,
gdy pas jest dozwolony, bez limitu kolejnych własnych tur. Dwa i więcej
dobrowolnych pasów nie kończą partii przy nadal legalnych postawieniach.
Rzeczywisty brak postawień u obu graczy nadal kończy grę. Zabezpieczenie
planera przed cyklami nie może wprowadzać remisu ani limitu pasów do zasad.
P nie przechwytuje czatu i nie pozwala pomijać tury przeciwnika.
Zmiany tylko w dokumentacji, bez kodu, testów gry, serwera i wydania.

## Opóźnienie botów — plan dla wszystkich gier, 17 września 2026

Użytkownik dopisał trzeci punkt do `docs/SAVES_WIDGET_NOTIFICATIONS_PLAN.md`:
wspólne opóźnienie bota 0–5 sekund we wszystkich grach z botami, również
przyszłych. 0 wyłącza celową pauzę, nie bota. UNO/Makao domyślnie 1;
dla pozostałych 0 zapisano jako propozycję. Zachować istniejące wartości,
uwzględnić thinking time i wyjątki faz. Wspólna definicja i planowanie,
bez blokowania UI, synchronizacji, reakcji ludzi i bez dodatkowych żądań.
Nie zmieniać strategii ani budżetu obliczeń. Obecny szkielet już planuje
oczekiwanie, ale UNO/Makao mają własne minimum 1 także przy wykonaniu.
Nowy plan zastępuje starsze propozycje opóźnienia w projektach Rummy,
Domino i Mexican Train; pozostały zakres tych dokumentów bez zmian.
Starsze wzmianki o dwóch punktach planu widgetu/powiadomień są historyczne.
Wyłącznie dokumentacja; nie wdrażać, nie zmieniać serwera, wersji ani wydania.

## Mexican Train — projekt do uzgodnienia, 17 września 2026

Ostatnia wcześniej nienazwana gra to Mexican Train. Użytkownik przekazał
opis QC; zapisano nowy `docs/MEXICAN_TRAIN_DESIGN.md`, bez implementacji.
Domino pozostaje zakończonym planem, Rummy i widget/powiadomienia bez zmian.
Nie zmieniać serwera, limitów, wersji ani nie budować/podpisywać/publikować.

Oddzielić reguły Mexican Train od Domino: stacja Double 12 schodzi co
rozdanie do 0 i wraca do 12; osobiste i publiczny pociąg; dodatkowe ruchy
po dubletach, stos obowiązków zamykania od ostatniego; ostatni dublet
kończy rozdanie, 0–0 zawsze daje 10. Nie przenosić automatycznie 11 zestawów,
drużyn ani opcji dobierania. Można współdzielić neutralne elementy kostek
i ręki przy przyszłym wdrożeniu, nie udawać gotowej implementacji Domino.
Interfejs, bot i 2–8 osób są propozycjami w dokumencie.
Użytkownik doprecyzował rozdanie: 2–5 osób po 15, 6–7 po 12, 8 po 10.
„17 graczy” odczytano jawnie jako literówkę „i 7”, bez osobnego
potwierdzenia i bez zmiany limitu 8. Pojemność z jedną stacją sprawdzono;
tabela w projekcie podaje pozostałości stosu dla 2–8 osób. Brakuje
startera i części wyjątków kontynuacji dubletów; nie przedstawiać
propozycji jako potwierdzonych reguł QC.
Użytkownik zatwierdził: we własnej serii wolno zamknąć starszy dublet,
zostawiając nowszy; następni zamykają pozostałe od ostatniego. Usunąć
z listy obowiązków konkretny zamknięty dublet, nie zawsze ostatni.
Pusty stos i brak ruchu otwierają własny pociąg z automatycznym pasem.
Limit punktów domyślnie 100, dodatkowa opcja dobierania mimo legalnej
kostki domyślnie wyłączona. Nie kopiować innych wariantów Domino.
Następstwo dobrowolnego dobrania przy nadal legalnej starej kostce
oznaczono jako propozycję do doprecyzowania, nie zatwierdzoną regułę.
Zmieniono wyłącznie dokumentację; nie uruchamiano testów nieistniejącej gry.

## Domino — zakończony plan, 17 września 2026

Pierwszą z dwóch zapowiedzianych nowych gier jest Domino. Użytkownik
przekazał opis Dominos z QC; w `docs/DOMINO_DESIGN.md` zapisano reguły,
interfejs, boty i wszystkie późniejsze doprecyzowania. Użytkownik uznał
plan za zakończony i przechodzi do ostatniej gry, nadal nienazwanej.
Nie jest to zgoda na implementację ani powód do dalszego rozwijania teraz
Domino. Nierozstrzygniętych wyjątków nie przedstawiać jako faktów z QC.
Nie wdrażać, nie zmieniać wersji, serwera ani limitów graczy, nie budować
i nie publikować. Użytkownik następnie zatwierdził pozostawienie limitu
8 osób, otwieranie dowolną kostką (nie tylko dubletem) oraz wygraną
najniższego łącznego wyniku przy jednoczesnym odpadnięciu wszystkich,
ze wspólnym zwycięstwem remisujących na najniższym wyniku. Nie rozszerzać
do większej liczby osób ani przywracać obowiązku otwarcia dubletem.
Zatwierdzenie tych punktów nie jest zgodą na wdrożenie.

Następnie użytkownik dodał 11 zestawów, opcje dobierania, kończenie całą
drużyną oraz thinking time i zażądał nazwy „kostki”. Po 7 w pojedynczym
Double 6 (maks. 4 osoby), w innych po 10. Na pytanie o za małe zestawy
potwierdził limit 5 osób w Double 9 i 2× Double 6, bez rozdania po 9;
pozostałe zestawy obsługują do 8 osób. Każda kostka z 2×/4× ma własne ID.
Domyślnie dobieranie mimo pasującej kostki jest włączone; zakaz, dobieranie
do skutku, drużyny i kończenie całą drużyną wyłączone. Zakaz dobierania
wyłącza i ukrywa oba zależne pola, a kończenie całą drużyną działa tylko
w drużynach. Jedno dobieranie w turze jest potwierdzone jako jedna akcja:
w trybie do skutku Spacja pobiera automatycznie do pierwszej pasującej
albo wyczerpania stosu, bez drugiej serii. Plan obejmuje blokadę mimo
niepustego stosu przy zakazie i pomijanie pustych rąk w kończeniu całą
drużyną. Wyjątki timeoutu, dobrowolnego dobrania, wybór startera w nowych
przypadkach i część UI nadal są propozycjami, nie faktami z QC.
Rummy, widget i powiadomienia pozostają odrębnymi, niezmienionymi planami.

Całe dobieranie do skutku ma być jednym krótkim zdarzeniem i jednym
zapisem ruchu, nie żądaniem dla każdej kostki. Klienci odtwarzają serię
lokalnie z ustalonego stosu. Standardowe odczyty/ponowienia transportu
pozostają, bez mnożenia żądań przez długość serii. Zaplanowano test
liczby wywołań i braku podwójnego dobrania, również dla zestawu 364 kostek.

Użytkownik doprecyzował, że dobieranie drużyn ma wykorzystywać istniejący
wspólny ekran ze Spades, nie nowy formularz. Potwierdzono ogólny
`GameRoomTeams::Assignment` oraz `configure_team_assignment`: automatyczny
skład, ręczna zmiana ludzi/botów i kontrola liczebności. Domino określa
własne dopuszczalne konfiguracje i przeplataną kolejność tur także po
ręcznym przydziale; nie kopiować ograniczeń ani punktowania Spades.
To uzupełnienie dokumentacji, bez implementacji.

## Aktualny zakres: widget i powiadomienia, 17 września 2026

Użytkownik usunął z bieżącego planu zapisy partii na serwerze. Nie wdrażać
chmury ani nie kontynuować prób magazynu; obecne lokalne zapisy, tabelę
diagnostyczną i raporty pozostawić. Projekt Rummy pozostaje bez zmian.
Plan `docs/SAVES_WIDGET_NOTIFICATIONS_PLAN.md` zawiera teraz widget
oraz dopracowany projekt powiadomień o nowych publicznych stołach.
Użytkownik zaakceptował go jako plan, w tym osobną tabelę z jednym małym
rekordem subskrypcji na konto, nadal bez zgody na implementację lub zmiany
serwera. Zapowiedział planowanie dwóch kolejnych, jeszcze nienazwanych
gier. Czekać na ich zakres; nie tworzyć kodu na podstawie tej zapowiedzi.

Aktualny kod ELTEN-a odczytany przez MCP potwierdza Apps.notify do jednego
konta, odbiór poza aktywnym oknem gry i zbiorczą listę online. Projekt:
jeden mały rekord preferencji na konto, odczyt przez klienta zakładającego
stół, lokalny wybór zainteresowanych/online i ograniczona kolejka wysłań.
To nie serwerowa subskrypcja ani jeden broadcast. Preferencje będą czytelne
dla rozsyłających klientów; starsze wersje i wyłączenie nadawcy ograniczają
dostawę. Nie odpytywać stołów okresowo w celu powiadomień i nie używać
Signals. Szczegóły, jawne propozycje i testy są w planie. Bez zmian kodu,
schematu serwera, rzeczywistych powiadomień, wersji i wydania. Historyczne
plany zapisu serwerowego poniżej nie są już bieżącym zakresem.

## Próba magazynu plików aplikacji, 17 września 2026

Na osobne polecenie sprawdzono `AppResources` dla zapisów partii.
API plików istnieje i nie podlega limitowi tekstowego pola tabeli, ale
Game Room ma `maxsize: 0`. Sztuczny plik 128 bajtów odrzucono jako HTTP 422
`apps.resources.quota_exceeded` / `App resource storage limit exceeded`.
Zwykły klient maskował tę odmowę jako `network_error`; dokładną odpowiedź
uzyskano oddzielnym klientem diagnostycznym bez globalnej zmiany transportu.
Przed i po próbach zero zasobów, zero zajętego miejsca; nic nie pozostało.
Nie zmieniano limitu, schematu, kodu funkcji ani paczki. Wariant plikowy
wymaga przydzielenia miejsca po stronie serwera, a następnie kontroli
uprawnień, pobrania i odtworzenia. Nie uznawać zera za brak ograniczeń.
Raport: `docs/SAVED_GAME_STORAGE_FEASIBILITY.md`, szczegółowy wynik poza repo
w `diagnostics/server-save-feasibility-2026-09-17/server-file-resource-results.json`.

## Próba serwerowych zapisów i sprzątanie, 17 września 2026

Użytkownik następnie zatwierdził utworzenie tabeli próbnej, testy i usunięcie
starych tabel. Jawnie potwierdził konto deweloperskie `papierek` i wykluczył
kopię usuwanych danych. Usunięto `tables`, `table_members`, `game_sessions`,
`game_events`, `invitations`, `invitation_responses`; API potwierdza not_found.
Pozostają nienaruszone `game_room_users`, `table_activity` i pusta
`saved_games_capacity_probe`. Nie przywracać usuniętych tabel z dawnych notatek.
Brak kopii usuniętych rekordów. Nie dotykano lokalnych zapisów ani LiveSessions.

W próbie `string:4096` działa, `string:4097` i większe deklaracje odrzucono.
11/15 syntetycznych legalnych archiwów przeszło rzeczywisty zapis/odczyt/replay;
Spades, UNO, Farkle, Monopoly przekroczyły jedno pole. Trzy pola pomieściły
12 288 znaków w jednym rekordzie i odtworzyły Monopoly. Cztery duże pola
z metadanymi oraz 256 pól wywołują błąd wewnętrzny; nie uznawać tego za
udokumentowany globalny limit. Nie powtarzać wielkich migracji na danych.
Nieudana szeroka migracja zepsuła tylko pustą tabelę diagnostyczną; usunięto
ją i utworzono poprawnie ponownie. Wszystkie syntetyczne rekordy sprzątnięto.
Nie wdrażać jednego rekordu dla dowolnej partii na podstawie tego testu.
Raport: `docs/SAVED_GAME_STORAGE_FEASIBILITY.md`, wyniki i skrypt poza repo
w `diagnostics/server-save-feasibility-2026-09-17/`. Duża seria trafiła na
limit żądań: dokończona po przerwie, nie powtarzać bez ograniczenia tempa.
Użytkownik mówi o `protected: true/false`, nie osobnym trybie private;
serwerowe `tables_protected: false` pozostawiono bez zmian. Nie testowano
prywatności z drugiego konta. Bez zmian kodu aplikacji, wersji 226, paczek,
publikacji i wdrożenia Rummy/widgetu/powiadomień. Starsze wpisy poniżej
o braku zgody dotyczą etapu przed tym eksperymentem.

## Zapis na koncie, widget i nowe stoły — tylko plan, 17 września 2026

Trzy nowe propozycje użytkownika zapisano w
`docs/SAVES_WIDGET_NOTIFICATIONS_PLAN.md`: dostęp do zapisanych partii
z innego komputera, usunięcie pobierania widgetu przy strzałkach oraz
powiadomienia o nowych publicznych stołach wybranych gier. Dokument
rozróżnia wymagania, potwierdzoną przyczynę widgetu i propozycje wymagające
sprawdzenia możliwości serwera. To nie jest zgoda na wdrożenie ani wydanie.
Nie zmienia projektu Rummy ani obecnego działania zapisów i powiadomień.
Później użytkownik zaakceptował odświeżanie widgetu przy wejściu i pod R
oraz zapytał o cykl co 5 sekund tylko na aktywnym widgecie. W planie
opisano ten wykonalny wariant, bez odpytywania po opuszczeniu kontrolki,
z zachowaniem bieżącego kursora i bez blokowania interfejsu. Wcześniejsza
propozycja 30-sekundowej ważności danych przy wejściu jest zastąpiona.
Zapis serwerowy opisano jako prywatny rekord jednej partii z obecnym
archiwum JSON; możliwości prywatności i limitów API nadal do potwierdzenia.
Użytkownik następnie wykluczył lokalne kopie zabezpieczające: docelowy
trwały zapis wyłącznie na serwerze, bez lokalnego trybu awaryjnego.
Nie jest to zgoda na usunięcie dotychczasowych plików. W kodzie potwierdzono,
że obecne wznowienie tworzy nową LiveSession i importuje samowystarczalne
archiwum, więc nie wymaga istnienia starej sesji. Tabela ma przechowywać
zapis, nie zastępować transport bieżącej partii. Nadal tylko plan.

Na pytanie o pojemność wykonano offline pomiar archiwów wszystkich 15
obsługiwanych gier i odczyt rzeczywistego schematu przez świeżą sesję MCP.
Raport: `docs/SAVED_GAME_STORAGE_FEASIBILITY.md`; skrypt i liczby poza
repozytorium w `diagnostics/server-save-feasibility-2026-09-17/`.
15/15 próbek przeszło bezstratną kompresję, walidację i odtworzenie.
Spades 815 zdarzeń: 13 748 bajtów po zlib+Base64; UNO 801: 12 976;
Monopoly 300: 6 512. Sztuczne historie 40 880 zdarzeń: około 608–756 KB,
nie legalne pełne partie ani gwarantowana granica. Globalnego limitu
pola/wiersza/żądania nie podaje odczytany schemat ani dokumentacja klienta;
nie ogłaszać, że każda partia mieści się w jednym rekordzie. Odczytane
`tables_protected` było false mimo true w źródłowej deklaracji; nie zmieniono
tego. Ochrona pieczęcią i widoczność własnych rekordów to odrębne ustawienia.
Bez zmian kodu aplikacji, schematu, rekordów, wersji i paczki. Próba zapisu
w tabeli testowej wymaga osobnej zgody i sprawdzenia konta właściciela.

## Rummy — projekt do dalszych ustaleń, 17 września 2026

Pełny projekt pod hasłem „rummy”, wraz ze wszystkimi późniejszymi korektami
użytkownika, znajduje się w `docs/RUMMY_DESIGN.md`. To dokument planistyczny,
nie gotowa implementacja. Użytkownik nadal zgłasza propozycje; aktualizować
ten dokument zgodnie z kolejnymi uzgodnieniami. Sama akceptacja i zapisanie
planu nie są poleceniem wdrożenia, zmiany wersji ani wydania paczki.

## Stan bazowy

Gałąź `main` zaczyna się od opublikowanego ELTEN Game Room 1.1.0, build 176.
Nie przenoś do niej eksperymentalnych zmian z późniejszych lokalnych buildów bez
osobnego zgłoszenia i przeglądu.

## Sposób pracy

Własne okna aplikacji używają `GameRoomUI::Form` lub
`GameSurfaces::RefreshAwareForm` z referencją `program:`. Wspólny szkielet
zapewnia lokalne F1 jako listę oraz F2/F3 i Shift+F2/F3 do głośności.
Nie dubluj tych klawiszy w klasach gier, nie zmieniaj źródeł ani zapisanych
QuickActions ELTEN-a. Dynamiczną pomoc gry i pokoju aktualizuj przez te same
definicje co rzeczywiste skróty (`GameRoomContextHelp`), nie dopisuj na stałe
tipsów zależnych od fazy. Szczegóły: `docs/VOLUME_AND_HELP_224.md`.

- Najpierw odtwórz problem i wskaż warstwę, która jest jego właścicielem.
- Kodowanie tekstów UI sprawdzaj również w paczce: ELTEN może wczytać źródła
  jako ASCII-8BIT, a brak tłumaczenia w `_()` pozostawia taki tekst bez zmiany.
  Nawet angielska etykieta z myślnikiem „—”, znakiem „×” lub innym znakiem
  spoza ASCII może wtedy wywołać Encoding::CompatibilityError przy doklejeniu
  przez kontrolkę polskiego/rosyjskiego opisu roli lub stanu. Teksty i etykiety
  przekazywane do kontrolek oraz składane komunikaty normalizuj do UTF-8 przez
  `GameRoomContent.utf8`, przed łączeniem/formatowaniem. Nie zmieniaj ID,
  wartości opcji ani binarnych danych, nie nadpisuj globalnego gettext ani
  kontrolek ELTEN-a i nie maskuj problemu usuwaniem znaków diakrytycznych.
  Etykiety `OptionDefinition` i `OptionChoice` normalizuje wspólny szkielet;
  nowe ustawienia mają go używać. Test musi przejść przez rzeczywiste
  tworzenie formularza i odczyt fokusu/stanu, także brakujące tłumaczenie
  Game Roomu obok tłumaczenia hosta. Nie wymuszaj UTF-8 w atrapach `_()` lub
  kontrolek, jeśli host tego nie robi — ukrywa to regresje. Używaj
  `test/game_option_encoding_test.rb` (źródła binarne; EN, PL oraz angielski
  tekst z rosyjskim hostem), a przy kolejnym pakowaniu także argumentu
  ze ścieżką gotowej paczki. Sam zwykły `require` albo test wyłącznie PL
  nie wystarcza do potwierdzenia zgodności.
- Tasowanie musi być zgodne z ELTEN-em: host nadpisuje `Array#shuffle`
  i `shuffle!` metodami bez argumentów. Nie używaj ich w kodzie partii ani
  planerów, zwłaszcza `shuffle(random: ...)`. Dla nowych wywołań stosuj
  `GameRoomRandom.shuffle(values, random: Random.new(seed))`, przekazując
  wspólne ziarno zapisane w zdarzeniu, nie nowy losowy seed podczas replaya.
  Zachowuj istniejące deterministyczne pomocniki (`CardGame#shuffled_cards`,
  `GameRoomDominoTiles.shuffle`, pomocniki planerów) i ich konwersję ziarna;
  nie migruj starych gier przy okazji, jeśli zmieniłoby to zapisane partie.
  Nie naprawiaj zgodności usunięciem argumentu random, `srand`, globalnym
  `rand` ani zmianą klasy Array w działającym ELTEN-ie. Testuj z
  `test/support/elten_array_shuffle.rb`, kontrolując rozdanie, ponowne
  tasowanie/wymianę, replay oraz kolejne użycie tego samego RNG. Sam test
  na zwykłym Rubym poza hostem nie wystarcza. Przy pakowaniu uruchom również
  binarne wczytanie z tą symulacją API; źródła i gotową paczkę rozróżniaj.
- Wprowadzaj małe, spójne poprawki i dodawaj celowany test regresji.
- Korzystaj z nowego, event-driven API ELTEN-a. Nie pisz ręcznych pętli UI.
- Rozszerzaj wspólny szkielet, gdy zachowanie jest wspólne dla rodziny gier;
  nie kopiuj tej samej obsługi do wielu klas gry.
- Nie przenoś reguł gry do `GameScreen` ani szczegółów interfejsu do transportu.
- Nie omijaj `action_for`, `GameRepository` i odtwarzania zdarzeń.
- Nowe karcianki mają korzystać ze wspólnej obsługi ręki, nie kopiować kursora:
  stabilne, unikalne ID kart, `hand_order` w faktycznej kolejności dobierania
  oraz `hand_epoch` identyfikujące właściciela i rozdanie. Szczegóły są w
  `docs/CARD_HAND_CURSOR_213.md`. Innych list, plansz i kości nie oznaczać jako
  ręki; ich zachowanie i odczyty nie mogą być zmieniane przez ten mechanizm.
- Nowa gra z rzeczywistą ręką kart implementuje `playable_card_navigation` i
  grupuje wszystkie legalne akcje według stabilnego ID fizycznej karty. `Z` i
  `Shift+Z` zapewnia wspólny szkielet. Automatyczny ruch wolno oznaczyć tylko,
  gdy karta nie wymaga dalszego wyboru, deklaracji, meldunku ani pakietu.
- Ręczne sortowanie ręki udostępnia `hand_sorting_available?` i wspólne
  `hand_sort_shortcuts`. Karty dostarczają semantyczne `sort_keys` dla
  colour/number/none, nigdy tłumaczone etykiety jako klucz. Domyślnego
  układu nie zmieniać przy samym dodaniu tej możliwości. Sortowanie widoku
  nie sortuje stanu partii, paczki ani kolejności zaznaczania układu;
  kontrolki CardTable/PacketCardSurface zachowują fizyczne ID i kursor.
  Sprawdzać konflikty skrótów i faktyczną obecność ręki na danym ekranie.
- Trwałą eliminację udostępnia `eliminated_from_game?`, oddzielnie od
  końca rundy, pasa, rozłączenia i all-in. Wspólny selektor dźwięków
  wykrywa przejście do tego stanu i respektuje ostateczny wynik/remis.
  Nie odtwarzać ponownie efektu porażki na końcu ani podczas replaya.
- Niezależne skutki jednego ruchu mogą mieć równoczesne efekty audio.
  Zbierać je niezależnie, nie przez wzajemnie wykluczające if/elsif;
  zachować deduplikację zdarzeń, akceptację ruchu i głośność gry.
- Tekst zasad ze znakami spoza ASCII tłumaczyć lokalnym
  `GameRoomRules.translate`: słownik hosta może przechowywać binarne klucze
  MO. Samo istnienie tłumaczenia i UTF-8 wyniku nie dowodzi, że klucz się
  dopasował. Testować rzeczywisty słownik albo wierną atrapę binarną.
- Bot wybiera akcję, ale wykonuje ją przez standardową ścieżkę gry.
- Stan stołu i partii synchronizuje stos LiveSessions. Publiczne stoły wyszukuj
  przez discovery i dołączaj do nich bezpośrednio; nie przywracaj bootstrapu
  ani synchronizacji przez Signals.
- Unikaj okresowego odpytywania i pełnej odbudowy formularza. Aktualizacja nie
  może przesuwać fokusu ani powodować zbędnych komunikatów czy dźwięków.

## Weryfikacja

Nowe wspólne funkcje stołu opisuje `docs/IMPLEMENTATION_AFTER_225.md`:

- Wariant/ustawienia Ctrl+R pochodzą z `table_options_announcement` i tych
  samych definicji co dokument ustawień. Nie utrzymuj drugiej listy reguł.
- Licznik S planszówki implementuje przez `remaining_piece_counts(replay)`
  w kolejności graczy; licz faktyczną planszę, nie wynik czy stan początkowy.
  Nie przypinaj literowych skrótów gry do edytowalnego czatu.
- Prywatność jest opcją wspólnego tworzenia stołu, nie ustawieniem każdej gry.
  Nie publikuj prywatnej aktywności. Ważność prywatnego powiadomienia musi
  pochodzić z serwerowego zaproszenia, nie z założonego terminu aplikacji.
- Zapis korzysta ze standardowego replaya i `saved_game_schema_version`.
  Nowa gra określa `save_game_error` dla niebezpiecznych faz albo wyłącza
  zapis przez `supports_saved_games?`. Jeśli wartości zdarzeń zawierają nazwy
  kontrolerów, implementuje `restored_event_value` dla tych konkretnych pól.
  Nie zastępuj graczy ani nie zamykaj stołu przed potwierdzonym zapisem na dysku.

- Uruchom celowane testy podczas pracy.
- Przed pull requestem uruchom `ruby tools/run-tests.rb`.
- Zmiana transportu wymaga testów `live_sessions_*`, `transport_test.rb`,
  `game_sync_test.rb` i scenariusza wielu klientów.
- Zmiana wspólnej powierzchni wymaga testu samej powierzchni oraz co najmniej
  jednej dotkniętej gry.
- Nie zmieniaj numeru wydania ani nie podpisuj paczki bez wyraźnego polecenia
  maintenera.

## Dane, których nie wolno dodawać

Nie zapisuj tokenów MCP, kluczy, certyfikatów, profili ELTEN-a, logów z danymi
prywatnymi, poświadczeń serwera ani podpisanych paczek `.eltsetup`.
