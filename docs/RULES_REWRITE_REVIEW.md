# Nowe opisy zasad — przegląd i weryfikacja

18 września 2026. Zakończono redakcję zasad **wszystkich 23 gier** w językach
polskim i angielskim. Jest to osobny etap po dwunastu poprawkach opisanych
w `POST_228_IMPLEMENTATION.md`. Oba etapy są w źródłach, jeszcze nie w wydanej paczce.

## Jak wyglądają zasady

Każda gra otrzymała własny tok wyjaśnienia: najpierw to, co trzeba zrozumieć,
żeby zacząć, potem przebieg ruchu, punktowanie i odpowiednio umieszczone
warianty. Nie zastosowano jednego szablonu nagłówków do wszystkich gier.
Wyjaśniono pojęcia, takie jak lewa, kontrakt, sekwens, blank czy niedomknięty
dublet. Przykłady pokazują rzeczywiste obliczenia i decyzje, nie tylko nazwy opcji.

Powstało 360 par akapitów PL/EN, wliczając opisy obsługi. Razem z nagłówkami
i wspólnymi objaśnieniami katalog obejmuje 494 pary tekstów. Indeks
`RULEBOOK_OPTION_COVERAGE.json` wskazuje rozdział dla każdej opcji danej gry.
Test sprawdza 137 wystąpień ustawień w rzeczywistych definicjach gier, w tym
wspólne opóźnienie bota. Sam indeks nie dowodzi poprawności opisu: treści
porównano dodatkowo z kodem reguł, obsługą ruchów i punktowaniem.

Zasady nadal są jednym dokumentem z nagłówkami, bez osobnego okna dla każdego
rozdziału. Biblioteka ma dwie pozycje: zasady i skróty. Przy stole pozostaje
trzecia pozycja z jego ustawieniami. Nie zmieniono sposobu wyboru wariantów.

Skróty są listą pod strzałkami, zamykaną Enterem lub Escape. W trakcie gry
pochodzą z tych samych aktualnie przypiętych definicji pola gry, których używa
F1. Nie zawierają osobno dopisanej drugiej listy ani poleceń zapraszania,
czatu i zarządzania pokojem. Uwzględniają bieżącą fazę, również Shift+Enter
Makao i wymianę w Pokerze. Poza aktywną partią pozostaje pełna instrukcja
obsługi wszystkich faz, dostępna przed rozpoczęciem gry.

## Źródła i najważniejsze różnice naszej wersji

Źródła internetowe służyły do porównania reguł, terminologii i sposobu
wyjaśnienia. Tekst został napisany od nowa, a nie przetłumaczony strona po
stronie. Przy rozbieżności opisano zachowanie **obecnego kodu Game Roomu**;
nie przenoszono reguł innej edycji do silnika tylko dlatego, że występują
w instrukcji zewnętrznej. Poniższa tabela odnotowuje również istotne różnice.

| Gra | Materiał porównawczy | Co sprawdzono lub wyraźnie rozróżniono |
| --- | --- | --- |
| Kółko i krzyżyk | [Hasbro — Tic Tac Toe](https://www.hasbro.com/common/instruct/BE3B7B36-D56F-E112-41B78D276B88B2AA.pdf) | Klasyczna plansza 3×3 i remis; bez dodatkowych gier elektronicznej edycji. |
| Cztery w rzędzie | [Hasbro — Connect 4](https://instructions.hasbro.com/en-au/instruction/connect-4-game) | Opadanie pionków, plansza 7×6, linie w czterech kierunkach; nasza gra dla dwóch osób. |
| Szachy | [FIDE — Laws of Chess](https://handbook.fide.com/chapter/E012023) | Ruchy figur, szach, pat, roszada, bicie w przelocie i promocja. Nasze automatyczne rozstrzyganie powtórzeń/50 posunięć nie jest turniejową procedurą zgłaszania roszczenia. |
| Warcaby | [FMJD — przepisy i aneksy](https://www.fmjd.org/downloads/FMJD_Annexes_2024_8-sig.pdf) | Nie utożsamiono wszystkich plansz z wariantem międzynarodowym. Opisano każde lokalne ustawienie bicia, damki i promocji, w tym opcjonalne pierwszeństwo damki oraz własny licznik remisu. |
| Reversi | [World Othello Federation — reguły](https://www.worldothello.org/about/about-othello/othello-rules/official-rules/english) | Linie przejmowania oraz osobne lokalne opcje dobrowolnego pasu i ruchu bez przejęcia; taki ruch nadal wymaga sąsiedztwa pionka. |
| Chińczyk | [Trefl — instrukcja](https://www.trefl.com/media/instruction/0/2/02418_instrukcja.pdf) | Domki, wspólny tor i zbijanie. Zachowano nasze wychodzenie szóstką oraz opcje blokad, bezpiecznych pól i trzeciej szóstki; nie przeniesiono innego warunku startu z instrukcji. |
| Spades | [Pagat — Spades](https://www.pagat.com/auctionwhist/spades.html), [QC](https://game.qcsalon.net/en/spades) | Licytacja, dokładanie do koloru, piki, nil i bags. Oddzielono zwykłe punktowanie, Quicksand, No-hell i Suicide oraz grę indywidualną/drużynową i lokalne premie kontraktów. |
| Tysiąc | [Pagat — 1000](https://www.pagat.com/marriage/1000.html) | Starszeństwo kart odrębne od punktów, mus i licytacja, mariaże, talon i wymiana, beczka, zera i rozpisanie. Podano konkretny lokalny wariant, nie mieszankę zasad domowych. |
| 99 | [QC — Ninety-nine](https://game.qcsalon.net/en/ninetynine) | Wpływ każdej figury na sumę, przejście przez progi i trafienie w nie. Walet dodaje 10; uzupełnianie ręki jest u nas automatyczne. |
| Farkle | [QC — Farkle](https://game.qcsalon.net/en/farkle) | Lokalne wartości układów i progów bankowania, konieczność punktowania wybranych kości, wykorzystanie wszystkich kości i dokładny zakres ostatniej kolejki. |
| Yahtzee | [QC — Yahtzee](https://qcsalon.net/en/yahtzee) | Wszystkie kategorie, także para, dwie pary i nędza. Ful to większa z wartości 25 i sumy kości. Premia kolejnego Yahtzee i reguła jokera są niezależne. |
| UNO | [QC — UNO](https://game.qcsalon.net/en/uno) | Kolejność dobierania i końca tury, odpowiedzi na kary, dwa etapy Wild, przechwytywanie, straight, buzzer, limity i eliminacja. Flip/No Mercy opisano według własnego kodu, nie jako kopie wszystkich edycji handlowych. |
| Makao | [Trefl — warianty Makao](https://www.trefl.com/media/instruction//0/2/02117__instrukcja.pdf) | Każda karta specjalna, paczki, obrona, kumulacja i automatyczny brak obrony. Rozpisano profile i własne ustawienia, bez podmieniania uzgodnionego wariantu na inne zasady domowe. |
| Poker | [Pagat — Five-card draw](https://www.pagat.com/poker/variants/5draw.html) | Osobne przebiegi Hold'em i dobieranego; hierarchia układów, ciemne, ante, kwota podbicia ponad wyrównanie, limity i pule boczne. Parametry oraz odmiany sprawdzono w naszym silniku. |
| Monopoly | [Hasbro — Monopoly](https://www.hasbro.com/common/instruct/monins.pdf) | Czynsz, grupa, równomierna zabudowa, zastawy i sprzedaż, aukcje, więzienie oraz lokalny przebieg długu. Zachowano generowany z danych opis 19 plansz; adaptacji nie nazwano identycznymi kopiami wydań QC. |
| Rummy | [QC — Rummy](https://game.qcsalon.net/en/rami), [Pagat — Rummy](https://www.pagat.com/rummy/rummy.html) | Dobranie przed operacjami, pierwsze wyłożenie, kolejność zaznaczania, miejsce jokera, stos odrzuconych i manipulacje. Kara 300 obejmuje też odzyskanego, niewyłożonego jokera; joker nie jest zwykłą kartą do dokładania do gotowego układu. |
| Domino | [QC — Dominos](https://radio.qcsalon.net/en/dominos) | Wszystkie zestawy i ich faktyczne limity, jedno uruchomienie dobierania, blokada i drużyny. Rozpoczynający u nas może położyć dowolną kostkę; rozdaje się 7 albo 10. |
| Mexican Train | [QC — Mexican Train](https://radio.qcsalon.net/en/mexicantrain) | Otwarte/zamknięte pociągi, powtarzana seria dubletów, obowiązek kolejnego gracza i potwierdzony wyjątek autora serii. 0/0 zawsze warte 10, inaczej niż w zwykłym Domino. |
| Scrabble | [Hasbro — Scrabble](https://instructions.hasbro.com/en-us/instruction/Scrabble-Game) | Łączenie słów, wszystkie przecięcia, blanki, jednorazowe premie oraz rozliczenie końcowe. Opisano własne słowniki PL/EN, sześć wariantów błędnego słowa, wymianę i lokalny warunek blokady, bez deklaracji zgodności z listą turniejową. |
| Taboo | [Hasbro — Taboo](https://instructions.hasbro.com/en-au/instruction/taboo-game) | Dozwolone podpowiedzi, hasło i słowa zakazane, rola przeciwników i punktacja. Głos odbywa się poza grą; przegląd, poprawa ocen i anulowanie tury są funkcjami Game Roomu. |
| Państwa-miasta | [QC — Little exam](https://game.qcsalon.net/en/petitbac) | Rola sędziego, ukrycie odpowiedzi, częściowa/unikalna/powtórzona odpowiedź i cykl sędziowania. U nas jedna litera oraz 1–9 kategorii, nie układ pytań QC. |
| Quiz Party | Kod `games/quiz_party.rb`, opcje oraz rejestr zestawów | Nie znaleziono kompletnej zewnętrznej instrukcji opisującej tę konkretną implementację. Podstawą są rzeczywiste trzy pytania w rundzie, wybór kategorii, ujawnienie odpowiedzi, cel punktowy i dogrywka. Nie przypisano tych zasad QC bez dowodu. |
| Biblios | [Biblios — instrukcja](https://www.nordicgames.is/wp-content/uploads/2015/12/Biblios-Rules-EN.pdf), zachowany wariant PR | Dary, informacje publiczne i ukryte, kości kategorii, dwa rodzaje płatności, kary i ponowna aukcja. Zachowano talię 87 kart, warianty autora i jego rozstrzyganie remisów; redakcja nie zastępuje ich inną edycją. |

To nie jest nowy audyt merytoryczny pytań Quizu ani kart Taboo, słowników
Scrabble, siły botów czy wszystkich możliwych stanów silników. Bazy treści,
strategie, protokół oraz reguły gier nie zostały zmienione przez redakcję.

## Jak utrzymywać teksty

Aktualizacja procesu: poniższy opis dokumentuje dawną redakcję PL/EN.
Obecnie tłumaczenia edytuje się wyłącznie w `locale/PL.po`; polskie pola JSON
są generowanym widokiem. `compile-rulebooks.rb` tworzy tylko angielski kod.
Aktualna instrukcja: `locale/README.md`.

Pliki `docs/rulebooks/*.json` przechowują obok siebie polską i angielską wersję
każdego nagłówka i akapitu. `tools/compile-rulebooks.rb` aktualizuje wyłącznie
`rule_sections` odpowiednich klas oraz katalog tłumaczeń. Wspólne teksty
mają pary w `locale/rules-shared-pl.json`. Gra wczytuje gotowe teksty Ruby
i PL.mo: nie pobiera instrukcji z internetu ani nie wymaga JSON-ów dokumentacji
podczas rozgrywki.

Przy nowej opcji trzeba dopisać zrozumiałe wyjaśnienie PL/EN i wskazać
rozdział w indeksie pokrycia. Przy nowym skrócie w czasie gry źródłem nadal
jest rzeczywiste przypięcie skrótu, a nie ręcznie skopiowana lista. Pełną
instrukcję obsługi w bibliotece również należy utrzymywać. Nie edytować tylko
wygenerowanego akapitu Ruby, bo następna kompilacja go zastąpi.

## Weryfikacja

Ostatnia seria: **15/15 skryptów celowanych**, składnia **63** zmienionych lub
nowych plików Ruby i kontrola diff poprawne. Raport z czasami, wyjściami
i kontrolą artefaktu: `../diagnostics/rules-rewrite-228/RESULTS.json`.

- Wszystkie 23 gry mają PL/EN, zgodność źródeł redakcyjnych z wygenerowanymi
  metodami i katalogiem, kompletne przypisanie opcji oraz strukturę dokumentów.
- Przykłady obliczono prawdziwymi pomocnikami gry: punktacja i joker Yahtzee,
  arytmetyka 99, kolejność i odzyskanie jokera Rummy, różne wartości 0/0.
- Binarne wczytanie aktualnych źródeł z rzeczywistym lokalnym słownikiem
  ELTEN-a: 207 okien dokumentów w symulowanym UI, dla 23 gier po angielsku,
  po polsku i z angielskim fallbackiem przy nieangielskim opisie hosta.
- Aktualne skróty z pola gry, brak duplikatów/poleceń pokoju, Enter/Escape,
  zmiana fazy, zachowanie zaznaczeń, kursora i szkicu czatu. Otwarcie pomocy
  nie wykonuje ruchu; nadal działają istniejące testy sieciowej obsługi ekranu.
- Osobno ustawienia: 72 formularze, 276 stanów checkboxów, 720 etykiet.
  Zachowano testy sortowania i nowych dźwięków z poprzedniego etapu.
- Ponowne uruchomienie kompilatora nie zmienia wygenerowanych plików
  ani katalogu — sprawdzona idempotencja.

Podczas przygotowania poprawiono także dane nowych testów (faktyczny format
ID karty 99 i rejestrację zestawów Quizu), zamiast zmieniać silniki w celu
dopasowania ich do błędnych atrap. Wynik końcowy dotyczy poprawionych testów.

**Nie uruchomiono pełnego runnera ani żywych klientów.** Próby ekranów są
symulacjami z binarnym źródłem i rzeczywistym kodem słownika, nie odsłuchem
każdej instrukcji w otwartym ELTEN-ie. Nie zbudowano i nie przetestowano
nowej podpisanej paczki.

Wersja nadal 2.0/build 228, API 3.0.3; numer i changelog bez zmian. Manifest
zawiera wcześniejsze dopisanie pięciu dźwięków, nie nowe wydanie. Dotychczasowa
podpisana paczka 228 pozostała bajtowo niezmieniona: 12 474 032 bajty,
SHA-256 `1534481cdd62043022f4eb4d51792a6fd8eb15f1bb262d4f5d2ded25c09d2922`.
Nie zawiera opisanych tutaj niewydanych zmian. Bez instalacji, publikacji,
GitHuba i zmian na serwerze.
