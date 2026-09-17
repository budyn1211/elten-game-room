# Domino — zakończony plan gry

Data: 17 września 2026. Punkt wyjścia: Game Room 1.1.10/build 226.

Aktualny stan: późniejsze polecenie wdrożenia zostało wykonane lokalnie,
wraz z celowanymi testami. Wydanie wstrzymane do dodania kolejnych gier.
Podsumowanie: `IMPLEMENTATION_2_0.md`; kontrola punktów:
`IMPLEMENTATION_2_0_VERIFICATION.md`. Poniżej pozostaje historyczny projekt
i rozróżnienie potwierdzonych zasad od przyjętych propozycji wykonawczych;
stare zastrzeżenia „bez wdrażania” nie odwołują późniejszego polecenia.

Użytkownik zapowiedział dwa kolejne projekty gier i przekazał angielski opis
Dominos z QuentinC's Playroom. To pierwsza z tych gier; drugiej jeszcze
nie wskazał. Poniżej oddzielono reguły z przekazanego opisu od propozycji
interfejsu i nierozstrzygniętych przypadków. Użytkownik uznał etap
planowania Domino za zakończony i przechodzi do ostatniej gry. Ten
dokument jest zapisanym planem do przyszłego wdrożenia, a nie poleceniem
rozpoczęcia implementacji, zmian
serwera, wersji, budowania, podpisywania, instalowania ani publikowania.
Rummy oraz plan widgetu i powiadomień pozostają osobnymi dokumentami.

Doprecyzowania użytkownika z 17 września: rozpoczynający może wyłożyć
dowolną kostkę; przy jednoczesnej eliminacji wszystkich wygrywa najniższy
łączny wynik, z możliwością wspólnego zwycięstwa przy remisie; maksymalnie
8 osób. Te decyzje są zatwierdzone i zastępują wcześniejsze propozycje
w odpowiadających im punktach, bez zgody na implementację.

Następnie użytkownik rozszerzył zakres o jedenaście zestawów, ustawienia
dobierania, kończenie całą drużyną i czas na ruch. W całym polskim
interfejsie oraz opisie używamy nazwy „kostki”. Poniższe sekcje zastępują
pierwotny projekt tylko trzech zestawów i jednego sposobu dobierania.
Następnie użytkownik rozstrzygnął oba konflikty: Double 9 i 2× Double 6
mają u nas maksimum 5 osób, zawsze po 10 kostek. Jednokrotne dobieranie
oznacza jedną akcję na turę, także gdy do skutku pobiera ona kilka kostek.
Te ustalenia są zatwierdzone, nadal wyłącznie w planie.

## 1. Zakres

Jedna gra „Domino”, podstawowy łańcuch z dwoma dostępnymi końcami.
Gra indywidualna i drużynowa. Kostka 2–5 i 5–2 to ta sama para wartości,
tylko inaczej ustawiona. W pojedynczym komplecie występuje raz; zestawy
2× i 4× zawierają odpowiednio dwa i cztery egzemplarze każdej pary,
również dubletów. Każdy egzemplarz ma własną trwałą tożsamość: nie wolno
scalać identycznych kostek w jedną pozycję stanu gry ani gubić duplikatów.
Nie dodawać samowolnie Mexican
Train, All Fives, rozgałęzień od dubletów ani dodatkowych zasad specjalnych.

Użytkownik zdecydował, że u nas pozostaje maksymalnie 8 osób, zgodnie
z obecnymi `GameRepository::MAX_PLAYERS` i
`LobbyRepository::MAX_ROOM_CAPACITY`. Nie rozszerzać limitu ani projektować
większych konfiguracji na podstawie maksymalnych liczebności skopiowanych
z listy QC. Limit konkretnego zestawu może być niższy. Lista wariantów:

| Zestaw z przekazanej listy | Liczba kostek | Na osobę | Maksimum z listy QC | Maksimum u nas |
|---|---:|---:|---:|---:|
| Double 6 | 28 | 7 | 4 | 4 |
| Double 9 | 55 | 10 | 6 | 5 |
| Double 12 | 91 | 10 | 9 | 8 |
| 2× Double 6 | 56 | 10 | 6 | 5 |
| 2× Double 9 | 110 | 10 | 10 | 8 |
| 2× Double 12 | 182 | 10 | 12 | 8 |
| 4× Double 6 | 112 | 10 | 10 | 8 |
| 4× Double 9 | 220 | 10 | 14 | 8 |
| 4× Double 12 | 364 | 10 | 16 | 8 |
| Double 15 | 136 | 10 | 10 | 8 |
| Double 18 | 190 | 10 | 12 | 8 |

Domyślnie pojedynczy Double 6. Etykiety dla użytkownika należy przetłumaczyć
na polski i podawać rzeczywiste maksimum Game Roomu, nie np. 16 osób.
„Go back” z przekazanej listy jest nawigacją QC, nie dwunastym zestawem.

## 2. Ustawienia stołu

- Zestaw kostek: lista wszystkich jedenastu wariantów z sekcji 1.
- Gra drużynowa: pole wyboru, domyślnie wyłączone.
- Liczba drużyn i przydział graczy: dostępne tylko w trybie drużynowym;
  jednakowe liczebności, co najmniej dwie osoby w drużynie. Zgodnie
  z doprecyzowaniem użytkownika wykorzystać wspólny mechanizm i ekran
  przydzielania drużyn używany już przez Spades, bez tworzenia nowego.
- Zakaz dobierania ze stosu: pole wyboru, domyślnie wyłączone.
- Dobieranie mimo posiadania pasującej kostki: pole wyboru, domyślnie
  włączone, zgodnie z przekazanym stanem ustawień QC.
- Dobieranie do znalezienia pasującej kostki: pole wyboru, domyślnie
  wyłączone. Jedna akcja dobiera kolejne kostki do pierwszej pasującej
  albo wyczerpania stosu; nie można uruchomić drugiej serii w tej turze.
- Kończy cała drużyna: pole wyboru, domyślnie wyłączone; dostępne tylko
  przy grze drużynowej. Rozdanie kończy wtedy opróżnienie rąk całej drużyny,
  a nie pierwszego z jej członków, z zachowaniem możliwości blokady.
- Czas na ruch (thinking time): pole liczby sekund. Użytkownik podał
  skutek przekroczenia: dobranie kostki i koniec tury. Propozycja dla
  wartości domyślnej i wyłączenia ograniczenia: 0 = bez limitu. Wartości
  tej nie potwierdzono jako ustawienia QC; wymagania wyjątków w sekcji 4.
- Limit punktów: dodatnia liczba, domyślnie 100 zgodnie z opisem QC.
- Opóźnienie bota: 0–5 sekund, 0 wyłącza celową pauzę. Późniejsze wspólne
  ustalenie dla wszystkich gier jest w punkcie 3
  `SAVES_WIDGET_NOTIFICATIONS_PLAN.md`; proponowana wartość domyślna
  dla Domino to 0. Uwzględnić limit czasu, bez wymuszania timeoutu pauzą.

Zaznaczenie zakazu dobierania wyłącza oraz ukrywa oba zależne pola:
dobieranie mimo pasującej kostki i dobieranie do skutku. Ich efektywne
wartości muszą być fałszywe również po normalizacji ustawień i odtworzeniu
zapisu, nie tylko w formularzu. Po wyłączeniu zakazu pola znów są dostępne.
Gdy dobieranie jest dozwolone, oba pola mogą działać razem, z semantyką
określoną w sekcji 4. Bez gry drużynowej nie pokazywać opcji kończenia
całą drużyną. Nieaktywnych reguł nie odczytywać pod Ctrl+R.

Nie dodawać wyboru liczby rozdań ani dodatkowych sposobów punktowania
bez osobnego uzgodnienia. Prywatność stołu pozostaje
opcją wspólnego formularza, nie nową regułą Domino.

## 3. Rozdanie i rozpoczęcie

Nowa zasada użytkownika zastępuje wcześniejsze 5–7: po 7 kostek w
pojedynczym Double 6, we wszystkich pozostałych zestawach po 10.
Dla 4 osób w Double 6 rozdaje się wszystkie 28 kostek i stos jest pusty.

W pierwotnej dostarczonej propozycji występował konflikt:
6 osób po 10 potrzebuje 60 kostek, a Double 9 ma 55, zaś 2× Double 6
ma 56. Użytkownik zatwierdził zachowanie po 10 i ograniczenie obu tych
zestawów do 5 osób. Przy 5 osobach zostaje odpowiednio 5 albo 6 kostek
w stosie. Nie stosować wyjątku po 9, nie dodawać dodatkowej talii ani
nie duplikować brakujących kostek. Przed startem sprawdzić limit danego
zestawu i pojemność, także po zmianie ustawień i przy wznowieniu zapisu.

Reszta kostek tworzy zakryty stos, także w wariancie zakazu dobierania,
w którym nie jest używany. Rozpoczyna posiadacz najwyższego
dubletu spośród rozdzielonych kostek. Dublet znajdujący się w stosie nie
wyznacza rozpoczynającego. To kryterium wyboru osoby nie ogranicza
kostki, którą ta osoba otworzy łańcuch.

Zatwierdzona poprawka użytkownika: pierwsza osoba może zagrać dowolną
kostkę ze swojej ręki, także niedublet. Nie wymagamy najwyższego dubletu
ani żadnego innego dubletu jako pierwszego zagrania. Zastępuje to
ograniczenie z pierwotnego opisu oraz wcześniejszą propozycję otwarcia
najwyższym dubletem.

Do potwierdzenia pozostaje wybór rozpoczynającego w kolejnych rozdaniach
oraz sytuacje, w których żaden gracz nie ma dubletu lub kilka osób
ma identyczny najwyższy dublet z zestawu 2×/4×. Trzeba ustalić sposób
wyboru osoby, nie legalność otwarcia — dowolna kostka jest legalna na
pustym stole. Ponowne rozdawanie nie zostało
zatwierdzone i nie jest już proponowane jako konieczny skutek braku dubletów.

## 4. Przebieg tury

Gracz dokłada jedną kostkę do lewego albo prawego końca. Stykające się
wartości muszą być równe. Program ustawia kostkę właściwą stroną.
Dublet nie tworzy dodatkowych odnóg i nie daje kolejnego ruchu.

Z zakazem dobierania można tylko zagrać. Brak legalnej kostki powoduje
automatyczne pominięcie bez dodatkowego Entera, nawet jeśli w stosie
pozostały kostki. Nie udawać, że stos jest pusty: jest niedostępny.

Bez zakazu dobieranie uruchamia Spacja. Gdy opcja dobierania mimo
pasującej kostki jest wyłączona, wolno dobrać tylko przy braku ruchu.
Gdy jest włączona, gracz może dobrać także mając legalne zagranie.
Nie ma dowolnej liczby niezależnych dobrań w jednej turze.

Przy wyłączonym dobieraniu do skutku pobierana jest jedna kostka.
Jeśli po dobraniu jest legalny ruch, gracz może zagrać, ale nie może
ponownie dobierać. Przy braku legalnego ruchu kolejka przechodzi dalej.
Proponowana konsekwencja dla dobrowolnego dobrania: nietrafiona nowa
kostka nie kasuje możliwości zagrania pasującą kostką, którą gracz miał
wcześniej. Tego szczegółu nie opisuje wprost przekazany tekst opcji;
pozostaje jawną propozycją do akceptacji.

Zatwierdzone doprecyzowanie użytkownika: „raz na turę” oznacza jedną
akcję. W opcji do skutku pobiera ona kolejne kostki do pierwszej
pasującej lub wyczerpania stosu. Jedno naciśnięcie Spacji uruchamia
całą serię, bez ponownego uruchomienia w tej turze. Limit nie oznacza
jednej fizycznej kostki w tym wariancie. Pozostałe pobrane kostki zostają
w ręce. Nowe naciśnięcia Spacji i ponowione żądanie tej samej akcji nie
mogą uruchomić drugiej serii. Stan po serii podlega tym samym zasadom
zagrania albo pominięcia, co stan po pojedynczym dobraniu.

Proponowana semantyka współdziałania obu zezwoleń: jeśli gracz miał już
pasującą kostkę i mimo to świadomie dobiera, akcja pobiera co najmniej
jedną nową kostkę; w trybie do skutku szuka pierwszej pasującej spośród
nowo dobieranych, nie kończy się bez dobrania z powodu wcześniejszej ręki.
Gdy stos jest pusty, nie można dobierać, ale zachowuje się legalne
zagrania z ręki. Pusta ręka członka drużyny, który skończył, nie uprawnia
do ponownego dobierania, patrz sekcja 6.

### Czas na ruch

Po upływie włączonego limitu następuje dobranie jednej kostki i przekazanie
tury, bez możliwości zagrania po tej karnej czynności. Nie uruchamiać
automatycznie całej serii do skutku na podstawie samego opisu timeoutu.
Proponowane doprecyzowanie zgodne z zakazem i jednokrotnym dobieraniem:
jeśli w tej turze już dobierano, stos jest pusty albo dobieranie jest
zakazane, następuje sam koniec tury, bez dodatkowej kostki. Nie obchodzić
w ten sposób ustawionych reguł. Wyjątki wymagają zatwierdzenia.

Korzystać ze wspólnego zegara gry i standardowej walidacji terminów,
bez osobnego niezależnego zegara każdego klienta. Otwarcie podglądu
łańcucha ani dobieranie nie rozpoczynają nowej tury i nie odnawiają czasu.
Ruch i przekroczenie terminu muszą dawać jedno rozstrzygnięcie w replayu,
nie dwa dobrania z dwóch klientów. Domyślnie bez samoczynnego odczytywania
odliczania; to propozycja interfejsu, nie dodatkowa reguła z QC.

## 5. Zakończenie rozdania i punkty

Wyłożenie ostatniej kostki kończy rozdanie natychmiast w grze indywidualnej
i w drużynowej bez opcji kończenia całą drużyną. Z tą opcją obowiązuje
sekcja 6. Kończący otrzymuje zero punktów, pozostali sumę oczek swoich
pozostałych kostek.
Wyjątek: 0–0 liczy się za 10, ale tylko gdy stanowi całą pozostałą rękę
tej osoby. W towarzystwie innych kostek daje zero. Nie przenosić reguły
„0–0 zawsze za 10” z innych odmian domina.

Blokada wymaga pełnego obiegu graczy z niepustymi rękami bez możliwości
legalnego zagrania oraz braku dostępnego dobierania: stos jest pusty albo
dobieranie jest zabronione. Przy zakazie nie czekać na opróżnienie
niedostępnego stosu. Samo wyczerpanie stosu nie kończy rozdania. Zagranie
kostki zeruje liczenie obiegu bez ruchu. Timeout gracza mającego legalną
kostkę nie dowodzi blokady; nie opierać jej wyłącznie na liczbie pominięć.
Przy blokadzie każdy otrzymuje punkty za własną rękę; nie wyznacza się
sztucznego zwycięzcy rozdania.

Punkty dopisuje się wszystkim jednocześnie na koniec rozdania. Wynik
równy limitowi lub wyższy eliminuje; pozostający gracze kontynuują.
Ostatni pozostały gracz wygrywa partię. Sposób pozostawania wyeliminowanych
przy stole powinien korzystać ze wspólnego modelu aplikacji.

Zatwierdzone rozstrzygnięcie użytkownika: gdy wszyscy pozostali gracze
jednocześnie osiągną lub przekroczą limit, wygrywa najniższy łączny wynik
po rozliczeniu rozdania. Identyczny najniższy wynik oznacza wspólne
zwycięstwo remisujących graczy, bez dodatkowego rozdania. Jest to świadoma
decyzja projektu, nie dodatkowo potwierdzona reguła QC. Nie zmienia
punktowania zwykłej blokady ani kontynuacji, gdy nadal pozostaje kilku
graczy poniżej limitu.

## 6. Drużyny

Wybór składu korzysta z istniejącego ekranu „Gracze i drużyny”, używanego
w Spadesach. Przed rozpoczęciem master może zaakceptować automatyczny
przydział, zmienić drużynę wybranego człowieka lub bota albo przywrócić
przydział automatyczny. Wspólny mechanizm sprawdza równe liczebności
przed startem. Nie tworzyć dla Domino drugiego formularza ani odrębnego
formatu zapisywania przydziałów.

Potwierdzenie w obecnych źródłach: `GameRoomTeams::Assignment`
(`lib/game_teams.rb`), `Base#team_assignment` / `with_team_assignment`
(`games/base.rb`) i `configure_team_assignment` / `choose_team`
(`__app.rb`). Mechanizm jest ogólny; ograniczenie Spades do drużyn
dwu- lub trzyosobowych nie jest ograniczeniem wspólnego przydzielania.
Domino określa własne dopuszczalne konfiguracje wymienione poniżej,
z zachowaniem pola wyboru gry drużynowej i limitu wybranego zestawu.
Nie przenosi ze Spades limitów graczy ani zasad punktowania.

Kolejność graczy przeplata drużyny, np. A1, B1, C1, A2, B2, C2.
Nie wystarczy dowolnie rozmieścić ludzi i przypisać im etykiety drużyn.
Automatyczny przydział już przeplata zespoły. Ręczna zmiana we wspólnym
ekranie zmienia przynależność, nie porządek uczestników; inicjalizacja
Domino musi z zatwierdzonego składu wyznaczyć przeplataną kolejność tur.
To zastosowanie składu do reguł Domino, nie nowy sposób wybierania drużyn
ani zmiana dotychczasowego zachowania Spades.

Konfiguracje z równymi drużynami: 4 osoby — 2×2; 6 — 2×3 lub 3×2;
8 — 2×4 lub 4×2. Zatwierdzony limit 8 osób wyklucza większe konfiguracje.
Zestaw kostek musi wystarczać do zatwierdzonego rozdania; pojedynczy
Double 6 pozostaje najwyżej dla 4 osób. Double 9 i 2× Double 6 mają limit
5 osób, więc z równych drużyn obejmują jedynie konfigurację 2×2. Nie
dopuszczać w nich sześciu osób. Pozostałe zestawy obsługują konfiguracje
drużynowe do 8 osób.

Przy wyłączonym kończeniu całą drużyną pierwszy gracz z pustą ręką kończy
rozdanie, a jego drużyna dostaje zero. Każda przeciwna
drużyna otrzymuje sumę punktów własnych rąk oraz dodatkowo sumę punktów
kostek pozostałych całej zwycięskiej drużynie. Ten dodatek otrzymuje
każda drużyna przeciwna, nie dzieli się go między nie.

Przykład: A kończy, partnerom A pozostało 8 punktów, drużyna B ma 20,
C ma 15. Wynik rozdania: A +0, B +28, C +23.

Przy włączonym „Kończy cała drużyna” pusta ręka jednej osoby nie kończy
rozdania. Osoba ta czeka i jest pomijana w kolejce; nie dobiera na nowo,
nie dostaje kary za czas oczekiwania i nie jest usuwana ze składu drużyny.
Wygrywa pierwsza drużyna, której wszyscy członkowie mają puste ręce.
Wtedy pozostali naliczają swoje punkty; dodatek za kostki zwycięskiej
drużyny wynosi zero, ponieważ nie ma ona żadnych kostek. Nadal możliwy
jest koniec przez blokadę, liczony wśród osób, które mają jeszcze kostki.

Przy blokadzie nie ma drużyny zwycięskiej: każda liczy tylko swoje ręce.
Proponowana interpretacja wyjątku 0–0: badać każdą rękę osobno, nie całość
kostek drużyny. Limit eliminowałby całą drużynę. Te szczegóły drużynowe
warto osobno potwierdzić, bo opis nie rozwija wszystkich wyjątków.

## 7. Proponowany interfejs i klawisze

Głównym polem jest ręka kostek pod strzałkami, np. „0–4”, „2–5”, „6–6”.
Nie osobny przycisk dla każdej kostki, nie przemieszczanie się Tabem
między nimi i nie ręczne obracanie kostek. Dwa identycznie odczytywane
egzemplarze w zestawie wielokrotnym pozostają osobnymi pozycjami.

- Enter: zagranie zaznaczonej kostki na jedyną legalną stronę; jeśli
  pasują obie, na wcześniej wybraną stronę, bez dodatkowego pytania.
- G: ustawienie preferowanej lewej strony, bez zagrywania kostki.
- D: ustawienie preferowanej prawej strony, bez zagrywania kostki.
  To zatwierdzone doprecyzowanie użytkownika z 17 września zastępuje
  wcześniejsze bezpośrednie zagrywanie pod G/D i menu stron pod Enterem.
  Początkowo wybierana jest prawa strona. Wybór jest lokalnym ustawieniem
  interfejsu, nie ruchem sieciowym; pozostaje po odświeżeniach i między
  rozdaniami aż do zmiany. Jednorazowe zagranie na jedyny pasujący koniec
  nie zmienia zapamiętanej preferencji. G/D potwierdza tylko stronę.
- Spacja: dobieranie zgodnie z ustawionymi regułami, bez drugiego
  niezależnego dobierania w tej samej turze. Nie dobiera przy zakazie.
- C: krótki odczyt odkrytych końców, np. „Lewo 3, prawo 6”.
- V: lista całego łańcucha w rzeczywistej orientacji od lewej do prawej;
  zamknięcie przywraca poprzedni kursor ręki, bez odbudowy formularza.
- S: wyniki graczy albo drużyn.
- E: liczba kostek u każdego aktywnego gracza i liczba pozostała w stosie,
  np. „papierek, 5; peterman, 3; stos, 9”, bez ujawniania kostek innych.
  Przy zakazie stos oznaczyć jako niedostępny, nie jako możliwe źródło
  dobierania. Członkowie drużyny, którzy skończyli, mają zero kostek.
- T: czyja tura.
- Z / Shift+Z: proponowana nawigacja po legalnych kostkach. Jedyna
  legalna fizyczna kostka z jednym sposobem zagrania może być od razu
  zagrana. Przy dwóch legalnych stronach tylko ustawienie kursora;
  następujący Enter używa zapamiętanej preferencji G/D.
  Identyczne egzemplarze nie są jedną fizyczną kostką; nie scalać ich
  przy ustalaniu, czy możliwy jest automat.

F1, Ctrl+F1, Ctrl+R, głośność, czat i pozostałe funkcje wspólne pozostają
standardowe. Literowe klawisze nie działają jako akcje gry podczas
pisania na czacie. Nie przejmować Ctrl+R nowym lokalnym skrótem.

Proponowane zachowanie kursora jak w rękach karcianek: po zagraniu
na poprzednią kostkę, a z pierwszej pozycji na nową pierwszą; po dobraniu
na dobraną kostkę, przy serii na ostatnią dobraną. Nowe kostki domyślnie
na końcu w rzeczywistej kolejności dobierania. Odczytywana jest nazwa
pod kursorem, bez ponownego nagłówka ręki i całego formularza.

Technicznie obecne `playable_card_navigation` i zachowanie kursora są
kontraktem kart. Przy wdrażaniu potrzebna jest jawna obsługa ręki kostek
lub neutralne współdzielone elementy nawigacji. Nie oznaczać dowolnej
planszy/listy jako karcianej ręki i nie zmieniać przez to innych gier.

## 8. Komunikaty

Propozycje: „papierek zagrywa 2–5 z prawej”; „peterman dobiera kostkę”;
„peterman nie może zagrać”; „papierek wygrywa rozdanie”; „Rozdanie
zablokowane”, następnie punkty dopisane każdemu graczowi lub drużynie.
Nie ogłaszać publicznie wartości dobranej kostki. Przy serii dobierania
proponowany jeden zbiorczy komunikat z liczbą kostek, bez osobnej wypowiedzi
dla każdego egzemplarza. Nie odczytywać całego
łańcucha po każdym ruchu; do tego służy V. Unikać dwóch komunikatów
opisujących to samo pominięcie i automatycznego powtarzania wyników.
Dźwięki podporządkować istniejącym kategoriom głośności Game Roomu;
konkretne pliki do ustalenia, bez wymyślania brakujących zasobów.

## 9. Proponowany bot

Bot zwykły zna własne kostki i publiczny przebieg, nie ukryte ręce
przeciwników ani kolejność stosu. Nie zdecydowano o dodaniu osobnego
bota wszechwiedzącego. Nie przenosić automatycznie decyzji z Rummy.

Ocena wszystkich legalnych par kostka–strona powinna uwzględniać:

- natychmiastowe zakończenie rozdania;
- pozostawienie końców pasujących do własnej ręki i unikanie izolowanych
  kostek, zwłaszcza dubletów;
- pozbywanie się kosztownych kostek, ryzyko samotnego 0–0;
- liczbę odkrytych kostek danej wartości, dobieranie i pasy przeciwników,
  z uwzględnieniem dwóch lub czterech kopii w zestawach wielokrotnych;
- wynik i zagrożenie eliminacją, korzyść lub koszt możliwej blokady;
- w drużynach szansę zakończenia przez partnera i koszt utrudnienia mu ruchu,
  zamiast bezwzględnego minimalizowania wyłącznie własnych oczek.

Dobrowolne dobranie przy włączonym zezwoleniu nie dowodzi braku pasującej
kostki. Nie przenosić takiego fałszywego wniosku do planowania. Tryb zakazu
wymaga oceny blokowania bez oczekiwania na dobieranie. Przy kończeniu
całą drużyną wyjście jednego bota nie jest jeszcze wygraną i strategia
musi uwzględniać pozostałych partnerów. W dobieraniu do skutku bot
uruchamia tylko jedną akcję, nie powtarza decyzji po każdej kostce.
Koszt obliczeń
pozostaje ograniczony także dla zestawu 364 kostek.

Pas to informacja o ówczesnej ręce, nie wieczna pewność braku danej
wartości: późniejsze dobieranie zmienia możliwy skład ręki. Bot nie może
wykorzystywać ręki partnera, jeśli nie jest publiczna. Małe, ograniczone
obliczenia i ewentualne płytkie planowanie, bez nieograniczonego przeszukiwania
blokującego ELTEN-a. Trudność weryfikować celowanymi pozycjami i odróżniać
rozsądne ryzyko od oczywistego błędu, nie obiecywać optymalnej gry.

## 10. Przyszła implementacja i testy

Gra korzysta ze wspólnego transportu i odtwarzania zdarzeń, bez własnej
sieci lub odpytywania. Trwałe ID każdej fizycznej kostki niezależne od
orientacji, również identycznych kopii z zestawów wielokrotnych. Zapis
lokalny Ctrl+S przez istniejący mechanizm po obsłużeniu zasad bezpiecznych
faz; nie wracać przy tym do odłożonego projektu zapisów serwerowych.

### Cała seria dobierania jako jeden zapis ruchu

Po pytaniu użytkownika o liczbę żądań uzgodniono, że dobieranie do skutku
jest jednym ruchem również na poziomie transportu. Wysyłamy jedno krótkie
zdarzenie dobierania; klienci odtwarzają serię lokalnie z tej samej,
deterministycznej kolejności stosu, do pasującej kostki albo wyczerpania.
Nie tworzyć osobnego zdarzenia ani żądania dla każdej kostki i nie wysyłać
rozbudowanej listy ich nazw. Po serii aktualizować rękę i komunikat zbiorczo.
Przykładowo 20 kostek oznacza jeden zapis ruchu, nie 20 zapisów.

To nie obietnica dokładnie jednego żądania HTTP w każdej sytuacji:
standardowa synchronizacja, odczyty i odzyskiwanie po błędzie pozostają.
Ich liczba nie może rosnąć proporcjonalnie do liczby dobranych kostek.
Ponowienie tego samego ruchu nie może ponownie pobrać kostek. Celowany
test transportu ma policzyć wywołania dla pojedynczego dobrania i długiej
serii, także w zestawie 364 kostek, oraz sprawdzić zgodność odtworzenia
u kilku klientów. Podstawą wykonalności jest istniejąca analogiczna
obsługa dobierania do skutku w UNO; Domino nie jest jeszcze wdrożone.

Przed wydaniem testować: kompletność wszystkich jedenastu zestawów,
niezależność identycznych egzemplarzy, legalność obu stron i orientacji,
rozpoczęcie dowolną kostką (także niedubletem), dokładne rozdania,
walidację pojemności i limit 8 osób, normalizację sprzecznych opcji,
pojedyncze i seryjne dobieranie zgodnie z zatwierdzonym wariantem,
blokadę drugiego dobierania, zachowanie po dobrowolnym dobraniu,
ostatnią kostkę w stosie, reset licznika
blokady, koniec z pustą ręką, wyjątek 0–0, równoczesne naliczenie punktów
i eliminacje, wygraną najniższym wynikiem przy odpadnięciu wszystkich
i wspólne zwycięstwo przy remisie, drużyny i ich kolejność, brak ujawniania rąk, replay oraz
lokalne wznowienie. Osobno: blokadę przy zakazie mimo niepustego stosu,
kończenie całą drużyną i pomijanie pustych rąk, timeout przed/po dobraniu,
timeout z zakazem i pustym stosem, wyścig ruchu z terminem bez podwójnej
kary. UI: Enter/G/D/Z, kursor, czat, pomoc, brak zbędnych odświeżeń.
Bot: wyjście ostatnią kostką, wybór strony, blokowanie, samotny 0–0,
współpraca, duplikaty i poprawne wnioskowanie po dobrowolnym dobieraniu.

## 11. Kontrola szczegółów przed przyszłym wdrożeniem

Użytkownik zakończył etap planowania. Poniższe punkty zachowują ślad
szczegółów, których wcześniej nie rozstrzygnięto osobno; nie są powodem
do kontynuowania teraz prac nad Domino zamiast przejścia do ostatniej gry.
Nie utożsamiać zakończenia planu z potwierdzeniem nieznanych reguł QC ani
nie przypisywać użytkownikowi niepodanych reguł wyboru rozpoczynającego.

1. Potwierdzenie proponowanej obsługi nietrafionego dobrowolnego dobrania,
   współdziałania obu zezwoleń i wyjątków timeoutu; domyślne 0 czasu.
2. Wybór osoby rozpoczynającej kolejne rozdania, brak dubletów oraz
   remis najwyższych dubletów w zestawie wielokrotnym. Sama kostka
   otwierająca jest już ustalona jako dowolna.
3. Potwierdzenie wyjątków 0–0 i eliminacji drużynowych.
4. Akceptacja proponowanych klawiszy i zachowania ręki kostek; zakres
   opóźnienia bota 0–5 wynika już ze wspólnego planu poprawek.

Nie otwierać ponownie rozstrzygniętych kwestii: dowolna kostka otwierająca,
najniższy wynik i wspólne zwycięstwo przy jednoczesnym odpadnięciu
wszystkich, maksymalnie 8 osób, po 7 kostek w pojedynczym Double 6 i po
10 w pozostałych, limit 5 w Double 9 i 2× Double 6 oraz jedna akcja
dobierania do skutku w turze. Wszędzie używać polskiej nazwy „kostki”.

## Źródła i granice potwierdzenia

Podstawą jest pełny tekst Dominos wklejony przez użytkownika, późniejsze
rozstrzygnięcia oraz przekazana lista jedenastu zestawów i opcji QC.
Lista i reguła 7/10 są materiałem od użytkownika, nie wynikiem nowego
sprawdzenia klienta; wykryty konflikt pojemności rozstrzygnięto zgodnie
z odpowiedzią użytkownika, a nie domysłem o zachowaniu QC.
Wyszukiwarka
zwróciła zgodny angielski opis QC z
https://radio.qcsalon.net/en/dominos oraz wersje językowe oficjalnej strony.
Bezpośrednie otwarcie https://qcsalon.net/en/dominos i strony statystyk
przekroczyło czas odpowiedzi. Nie sprawdzano gry na żywym kliencie QC
ani nie ustalono z forum dodatkowych reguł. Nie uznawać propozycji powyżej
za potwierdzone zachowanie QC. Przy dalszych ustaleniach uaktualniać ten
dokument zamiast odtwarzać wcześniejsze, zastąpione wersje planu.
