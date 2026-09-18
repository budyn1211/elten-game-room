# Kolejne poprawki po buildzie 228

Aktualizacja 18 września 2026: użytkownik polecił wdrożyć wszystkie
poniższe poprawki do kodu i potwierdził skróty sortowania z punktu 5.
Historyczne statusy „tylko plan” opisują etap zbierania wymagań; bieżące
postępy i wyniki są w `POST_228_IMPLEMENTATION.md`. Bez budowania,
podpisywania, instalacji i publikacji. Wersja 2.0/build 228 i dotychczasowa
podpisana paczka pozostają bez zmian.

## 1. Opóźnienia powiadomień o nowych stołach — usunięcie zapisu albo zapis w tle

Status: zapisane do późniejszego wdrożenia; jeszcze niewdrożone.

### Problem i granice diagnozy

Zgłoszono około dwusekundowe zamrożenie ELTEN-a przed odczytem powiadomienia
o nowym stole. Odbiornik Game Roomu zapisuje lokalny znacznik odbioru
synchronicznie, przed powrotem do pętli interfejsu i ogłoszeniem komunikatu.
Celowana próba z imitacją dwusekundowego zapisu potwierdziła, że takie
opóźnienie blokuje tę ścieżkę. Nie jest to jednak pomiar incydentu
zgłaszającego ani dowód, że rzeczywisty zapis zajmował u niego dwie sekundy.
Przygotowanie dźwięku także wymaga osobnego pomiaru.

Plik `table-notice-receipts.json` nie jest kopią powiadomienia ani
potwierdzeniem dla serwera, że komunikat został wypowiedziany. Zawiera
lokalną pamięć stołów już ogłoszonych lub obsłużonych oraz terminów
ważności. To dodatkowe zabezpieczenie Game Roomu, którego konieczność
nie została wykazana: ELTEN ma własną ochronę przed ponowną obsługą
identyfikatorów powiadomień i przy starcie zapamiętuje istniejące wpisy
bez ponownego ogłaszania. Sam restart lub dołączenie nie tworzy nowego
powiadomienia. Nowy stół ma nowy identyfikator i powinien zostać ogłoszony.
Sprzątanie już istniejącego wpisu po dołączeniu oraz pomijanie spóźnionej
dostawy to osobne kwestie, nie dowód konieczności utrwalania każdego
odbioru na dysku. Mechanizmy dostawy i stanu powiadomień ELTEN-a są osobną warstwą.
Sam odbiór powiadomienia o nowym stole nie wykonuje żądania HTTP.

### Zakres poprawki

- Najpierw sprawdzić, czy trwała pamięć odbiorów Game Roomu dubluje
  zabezpieczenia ELTEN-a. Osobno ocenić znaczniki odebrania (`seen`)
  i obsłużenia/dołączenia (`resolved`); nie usuwać obu mechanicznie.
- Wariant A: usunąć zbędny zapis odbiorów na dysku, jeżeli ochronę
  zapewniają host i ewentualna pamięć Game Roomu na czas działania.
  Nie dodawać w jego miejsce potwierdzeń sieciowych. Nie jest to
  polecenie natychmiastowego kasowania istniejącego pliku z danymi.
- Wariant B: jeśli testy wykażą potrzebę trwałego zapisu, przenieść
  go poza wątek interfejsu do jednej ograniczonej kolejki. Natychmiast
  zaznaczać odbiór w RAM, scalać oczekujące zapisy i przekazywać kopię
  stanu. Nie dopuścić do równoległych zapisów ani zastąpienia nowszego
  stanu starszym. Bezpiecznie obsłużyć błędy, ponawianie i zakończenie
  pracy bez blokowania interfejsu i nieograniczonego wzrostu kolejki.
- W obu wariantach zachować izolację kont, filtry, wygasanie, brak
  ponownego ogłaszania obsłużonych powiadomień oraz sprzątanie po
  dołączeniu. Nowego stołu nie wolno pomylić z poprzednim tego samego
  właściciela. Sposób przechowywania jest do ustalenia, nie celem samym w sobie.
- Umożliwić lekkie pomiary etapów rzeczywistego odbioru: mapowania,
  utrwalenia znacznika, przygotowania dźwięku i odświeżenia listy.
  Zapisywać tylko etap i czas, bez treści powiadomień, nazw użytkowników,
  tokenów ani danych zaproszeń. Ewentualne dalsze zmiany uzależnić od wyniku.
- Porównać stan obecny i wybrany wariant pod względem czasu do odczytu
  komunikatu oraz blokowania interfejsu. Oddzielić opóźnienie samej
  dostawy sieciowej od lokalnej obsługi już dostarczonego powiadomienia.
  Nie obiecywać skrócenia opóźnienia o dwie sekundy na podstawie samej
  próby z imitacją wolnego zapisu.

Nie zmieniać schematu serwera, transportu ani zasad wygasania powiadomień.
Nie dodawać żądań sieciowych i nie usuwać ochrony przed duplikatami.
Nie deklarować usunięcia wszystkich przyczyn zamrożenia bez pomiaru.

### Weryfikacja przy wdrożeniu

Testy celowane, bez pełnego runnera: ponowna dostawa tego samego ID,
różne ID dotyczące tego samego stołu, zwykły restart, powrót po utracie
połączenia, izolacja kont, wygasanie, dołączenie przed opóźnioną dostawą
i po odbiorze. Nowy stół tego samego właściciela nadal ma dawać nowy komunikat.
Nie zakładać, że wymuszenie duplikatu w teście dowodzi jego występowania
w prawdziwej dostawie. Sprawdzić też pozostawanie/usuwanie wpisu na liście
oddzielnie od automatycznego odczytu i dźwięku.

Dla wariantu A potwierdzić brak zapisu odbiorów i brak regresji powyższych
zachowań. Dla wariantu B: wolny i zawodny zapis nie blokuje odbioru,
seria powiadomień nie rozrasta kolejki, ostatni stan nie ginie przy
scalaniu; bezpieczny koniec pracy i kontrolowane ponawianie błędów.
Wyniki pomiarów opóźnień oraz podstawę wyboru wariantu zapisać w raporcie.
Próba rzeczywistej dostawy, jeśli będzie potrzebna, wymaga uzgodnienia
kont oraz konkretnego powiadomienia testowego.

Punkty wejścia: `__app.rb` (`map_notification`, `notification_received`),
`lib/table_watch.rb` (`Receiver`) i `lib/table_watch_runtime.rb`.
Szczegółowa diagnostyka lokalna, poza repozytorium:
`../diagnostics/table-notice-stall-228/README.md` względem jego katalogu głównego.

## 2. Krótsza nazwa powiadomienia o nowym stole, bez powtórzeń

Status: zapisane do późniejszego wdrożenia; jeszcze niewdrożone.

Użytkownik zgłosił dwukrotny odczyt frazy „Nowy stół”. Docelowa kolejność:
właściciel, nazwa gry, typ powiadomienia. Przykład podany przez użytkownika:
„Papierek, Yahtzee, typ, nowy stół”. Nie poprzedzać nazwy dodatkowym
„Nowy stół:” i nie powtarzać tej frazy w jednym odczycie.

### Potwierdzenie i zakres

- Obecnie `__app.rb`, `map_notification`, ustawia tytuł `New table`
  i treść `New table: %{game}, %{owner}`. W odczytanym kodzie działającego
  hosta `src/eapi/program.rb:428` metoda `NotificationPresentation#alert`
  łączy tytuł i treść. To potwierdza źródło powtórzenia w tym komunikacie.
- Przygotować nazwę/treść w kolejności właściciel, gra, bez prefiksu
  „Nowy stół:”. Typ „Nowy stół” pozostaje informacją o rodzaju powiadomienia,
  po nazwie, zgodnie ze standardową prezentacją ELTEN-a.
- Sprawdzić osobno automatyczne ogłoszenie i wiersz na liście powiadomień.
  Nie dopisywać na sztywno drugiego „typ” lub „Nowy stół”, jeśli daną
  etykietę odczytuje już host. Samo usunięcie prefiksu z treści nie wystarczy,
  jeżeli tytuł nadal będzie czytany przed właścicielem wbrew ustalonej kolejności.
- Odpowiednik angielski zachowuje tę samą kolejność i pojedyncze `New table`.
  Nazwa gry zgodna z językiem interfejsu, nazwa użytkownika bez przerabiania.
- Zmiana dotyczy prezentacji tego typu powiadomienia, nie jego technicznego
  identyfikatora, metadanych, dostawy, filtrów, ważności ani akcji dołączenia.
  Bez zmiany globalnego odczytu innych powiadomień ELTEN-a i zaproszeń.

### Weryfikacja przy wdrożeniu

Celowany test PL/EN, automatycznego odczytu i listy: właściciel przed grą,
rodzaj powiadomienia tylko raz, bez pustych wpisów. Zachować dołączenie
do właściwego stołu i pojedynczy dźwięk zgodnie z ustawieniami.
Sprawdzić także binarne wczytanie i brak tłumaczenia przy innym języku
hosta, bez błędów kodowania. Na etapie zapisywania planu tych zmian
nie wdrażano ani nie uruchamiano nowych testów; odczytano tylko kod.

## 3. Wybór języka bez przeskakiwania na zestaw — Quiz, Taboo i wspólny formularz

Status: zapisane do późniejszego wdrożenia; jeszcze niewdrożone.

Po każdej zmianie języka w Quizie i Taboo fokus przeskakuje na zestaw.
Utrudnia to przejrzenie języków strzałkami, bo użytkownik musi za każdym
razem wracać do poprzedniego pola. Docelowo zmiana języka pozostawia
fokus na liście języków; do zestawu przechodzi się samodzielnie Tabem.

### Potwierdzenie i zakres

- Wspólne `configure_game_options` w `__app.rb` po zdarzeniu `:move`
  języka przebudowuje formularz i jawnie ustawia
  `focused_option_key = GameRoomContent::SET_OPTION_KEY` (obecnie linia 1159).
  To wymuszenie w Game Roomie, nie wykazany błąd klawiatury ELTEN-a.
- Zachować fokus na języku i aktualnie wskazany język. Kolejne strzałki
  mają przeglądać języki bez powrotów Shift+Tab i bez dodatkowego zatwierdzania.
  Nie odczytywać przy tym zestawu ani całego formularza zamiast nowego języka.
- Nadal aktualizować zależną listę zestawów zgodnie z wybranym językiem,
  ale bez przejmowania fokusu. Zachować dotychczasowy zestaw, jeśli jest
  dostępny w nowym języku; w przeciwnym razie wybrać zgodny domyślny.
  Po ręcznym przejściu do zestawu lista i wybrana wartość muszą być aktualne.
- Nie resetować innych ustawień, wpisanych wartości ani zaznaczeń.
  Zachować walidację zgodności języka, zestawu i paczki danych.
- Naprawę umieścić we wspólnym formularzu, bez osobnych obejść w Quizie
  i Taboo. Uwzględnić również gry z ukrytym wyborem zestawu i przyszłe
  języki; nie zmieniać działania opcji niezależnych od języka.
- To samo zachowanie przy tworzeniu stołu i edycji jego ustawień Ctrl+X.
  Bez zmian zasad gier, danych zestawów, transportu i globalnych kontrolek hosta.

### Weryfikacja przy wdrożeniu

Celowane testy formularza dla Quizu i Taboo oraz próbnego zestawu z co
najmniej trzema językami: kilka kolejnych zmian w obie strony nie opuszcza
listy języków; Tab przechodzi do aktualnych zestawów; powrót do języka
zachowuje wybór. Sprawdzić wspólny zestaw dostępny w kilku językach,
konieczną zmianę zestawu, ukryty/jedyny zestaw, zapis i anulowanie,
zachowanie pozostałych opcji i Ctrl+X. Bez powtórzonego odczytu całego
formularza oraz bez błędów kodowania PL/EN i po binarnym wczytaniu.

Obecny `test/game_option_form_test.rb` jawnie oczekuje fokusu na zestawie
po zmianie języka. Przy wdrożeniu zmienić to oczekiwanie na uzgodnione
zachowanie i rozszerzyć scenariusze, a nie usuwać kontroli zgodności zestawów.
Na etapie planu odczytano kod i test; nie uruchamiano testów ani nie
wprowadzano poprawki do aplikacji.

## 4. Makao — Shift+Enter w pomocy skrótów

Status: zapisane do późniejszego wdrożenia; jeszcze niewdrożone.

Użytkownik zgłosił brak informacji o przygotowywaniu paczek przez
Shift+Enter w pomocy. Obsługa istnieje w `PacketCardSurface#activate`,
a pełne zasady Makao opisują ten skrót. Nie ma jednak odpowiadającej mu
informacji w bieżących wskazówkach kontrolki/skrótach prezentowanych pod F1.

- Dodać do kontekstowej pomocy ręki Makao: „Shift+Enter — dodaj kartę
  do paczki lub usuń ją z paczki”. Paczka zachowuje kolejność zaznaczania.
- Obok poprawnie opisać Enter jako zagranie karty/przygotowanej paczki,
  P jako odczyt paczki i Shift+P jako jej wyczyszczenie. Nie dublować
  istniejących wpisów ani dopisywać tych operacji na niepowiązanych ekranach.
- Źródłem pomocy ma być faktyczna obsługa kontrolki, bez drugiego
  konkurencyjnego handlera Shift+Enter i bez zmiany zasad paczek.
  Sprawdzić również sekcję skrótów w zasadach i zgodność PL/EN.
- Uwzględnić inne zastosowania tej samej kontrolki: w Pokerze służy
  do wyboru kart do wymiany, więc nie może otrzymać błędnego opisu
  „zagraj paczkę”. Nie zmieniać zachowania Enter w innych karciankach.

Przy wdrożeniu celowany test F1 z polem ręki, pojedynczych wpisów,
zaznaczania/usuwania kart i odświeżenia pomocy, PL/EN oraz kodowania
po binarnym wczytaniu. Na razie tylko odczyt kodu, bez uruchamiania testów.

## 5. Wspólne, ręcznie wybierane sortowanie kart w karciankach

Status: cel zgłoszony do planu; wybór skrótów jest propozycją do uzgodnienia,
nie zatwierdzoną decyzją użytkownika. Bez wdrażania.

Użytkownik chce sensownej metody sortowania własnej ręki w różnych
karciankach; nie wybrał jeszcze klawiszy. Propozycja bazuje na istniejących
Shift+C i Shift+H w UNO oraz Rummy:

- Shift+C — sortowanie według koloru (w klasycznej talii: kier, pik itd.);
  kolejne naciśnięcia przełączają porządek rosnący/malejący.
- Shift+H — sortowanie według wartości/rangi; również przełączanie kierunku.
- Shift+M — powrót do kolejności otrzymania kart, jak obecnie w Rummy.
  W UNO zachować dotychczasowy Shift+D jako zgodny dodatkowy skrót;
  nie zastępować nim Shift+D w Rummy, gdzie pobiera karty odrzucone.

### Zakres i ograniczenia propozycji

- Wspólny mechanizm prezentacji ręki, udostępniany według możliwości gry
  i ekranu, a nie tylko dziedziczenia po `CardGame`. Spades, Tysiąc i 99
  mają własne klasy bazowe, lecz również korzystają z widoku kart.
- Uwzględnić Makao, Spades, Tysiąca i 99 oraz zachować działające UNO
  i Rummy. W Pokerze najpierw ocenić ekran wymiany i podglądy kart;
  nie przebudowywać przy okazji całego interfejsu licytacji.
- Biblios nie ma zwykłej ręki o takich samych cechach, a Shift+C już
  odczytuje prowadzenie w kategoriach. Nie nadpisywać tego skrótu ani
  wymuszać niepasującego sortowania. Zakres/alternatywa dla Biblios do
  osobnego uzgodnienia, jeśli okaże się potrzebna.
- Gra dostarcza klucze sortowania swoich kart; nie porównywać tłumaczonych
  nazw alfabetycznie. Zachować ustalone porządki UNO. Porządek rang,
  kart specjalnych i jokerów innych gier opisać jednoznacznie przy
  dopracowaniu planu; nie utożsamiać bez sprawdzenia rangi, punktów
  karty i jej siły w danym wariancie.
- Zmienia się wyłącznie lokalny widok własnej ręki: bez żądań sieciowych,
  zmiany talii, reguł, botów, układów na stole i cudzych kart.
- Po sortowaniu kursor pozostaje na tej samej fizycznej karcie według ID,
  również przy kilku identycznych kartach. Zaznaczenia oraz kolejność
  przygotowanych paczek/układów nie zmieniają się przez sortowanie widoku.
- Zachować wybrany tryb przez odświeżenia i dobieranie w trakcie gry.
  Po zagraniu i dobraniu nadal obowiązują ustalone zasady kursora;
  Z/Shift+Z porusza się po legalnych kartach w widocznej kolejności.
- Krótkie potwierdzenie sposobu/kierunku sortowania, bez odczytywania
  całego formularza lub ponownego „Twoja ręka”. Aktualna pomoc F1
  zawiera tylko skróty dostępne na danym ekranie. W czacie/polu edycji
  pozostaje normalne wpisywanie tekstu.

W kodzie `CardTableSurface` istnieje `sort_cards`, a `MeldCardSurface`
obsługuje go dla Rummy. `PacketCardSurface` (Makao i wymiana w Pokerze)
jeszcze go nie obsługuje; samo dopisanie skrótu do gry nie wystarczy.
Nie resetować paczek przez porównywanie starej i nowej kolejności widoku.

Przy wdrożeniu: testy rosnąco/malejąco/powrotu do kolejności otrzymania,
kolizji skrótów, stałych ID i kursora, zaznaczeń, paczek, nowych kart,
odświeżeń i wyborów dodatkowych, a także braku wpływu na stan partii,
komunikację sieciową i pozostałe typy gier. Bez pełnego runnera.
Na etapie planu nie uruchamiano tych testów i nie zmieniano aplikacji.

## 6. Taboo — mieszane języki w zasadach i opisie skrótów

Status: zgłoszone do późniejszej poprawy; bez wdrażania.

Użytkownik widzi polskie i angielskie fragmenty w obu sekcjach pomocy
Taboo: zasadach oraz skrótach klawiszowych. Przy polskim interfejsie
obie sekcje mają być w całości po polsku, przy angielskim — po angielsku.
Język wybranego zestawu kart nie powinien zmieniać języka pomocy.

Odczyt bieżącego `locale/PL.mo` potwierdził polskie tłumaczenia wszystkich
12 tekstów z `Taboo#rule_sections` (nagłówków i akapitów). Izolowany odczyt
tych sekcji ze źródła wczytanego binarnie również znalazł te tłumaczenia.
Nie odtworzono jeszcze zgłoszenia w zainstalowanym kliencie ani na gotowej
paczce; nie uznawać na tej podstawie sprawy za naprawioną. Samo dopisanie
istniejących tłumaczeń lub założenie błędu kodowania nie jest diagnozą.

Przy wdrożeniu sprawdzić faktycznie używany katalog i ścieżkę tłumaczenia
w paczce, zgodność kluczy, kodowanie oraz wspólne akapity pomocy dodawane
do opisu skrótów. Uzupełnić ewentualne rzeczywiste braki i naprawić miejsce,
w którym poprawne tłumaczenie nie jest wybierane. Bez zmiany reguł Taboo,
kart, skrótów ani globalnego mechanizmu tłumaczeń ELTEN-a.

Weryfikacja: oba dokumenty z gotowej paczki przy interfejsie PL i EN,
niezależnie od języka kart; polskie nagłówki i pełne akapity, brak
angielskiego fallbacku w polskiej pomocy. Test nie może sztucznie
normalizować tekstu przed wyszukaniem tłumaczenia inaczej niż host.
Na etapie planu wykonano tylko odczyt i izolowaną próbę wyszukiwania
tłumaczeń; bez uruchamiania gier, zestawu testów i zmian aplikacji.

## 7. Nakładanie dźwięków — brak efektu waleta przy przekroczeniu progu w 99

Status: potwierdzony błąd wyboru efektów w 99, zapisany do późniejszej
poprawy. Nadal bez wdrażania.

Użytkownik przypomniał wcześniejsze ustalenie: dźwięki mogą nakładać się
na siebie. Zagranie karty i jego niezależne skutki mają zachować swoje
efekty, również podczas szybkich kolejnych ruchów. Zgłoszony przykład:
walet w 99 i jednoczesne przekroczenie 33 — słychać tylko jeden z dwóch
efektów specjalnych.

### Potwierdzenie i zakres diagnozy

- Wspólne `event_cue` już składa kilka efektów, a `play_all` przekazuje
  wszystkie do odtworzenia bez oczekiwania na zakończenie poprzedniego.
  W tej ścieżce Game Roomu nie ma ogólnej blokady nakładania dźwięków.
- `ninety_nine_cue` nadal wybiera pojedynczy efekt specjalny przez
  `if/elsif`: wynik rundy ma pierwszeństwo przed przekroczeniem progu,
  a przekroczenie progu przed efektem waleta lub zmiany kierunku.
  Dodanie podstawowego dźwięku karty nie przywraca pominiętego efektu.
- Izolowana próba istniejącego selektora: walet przy 10 → 20 zwraca
  `play`, `reverse`, `draw`; przy 25 → 35 oraz 60 → 70 zwraca
  `play`, `draw2`, `draw`, gubiąc `reverse`. To potwierdza błąd wyboru
  dźwięków, nie jest odsłuchem ani pomiarem miksera żywego ELTEN-a.
- Dotychczasowy test osobno obejmuje waleta, przekroczenie progu i kilka
  efektów, ale nie połączenie efektu karty specjalnej z progiem.

### Plan poprawy

- W 99 zbierać niezależnie należne efekty zagrania, karty specjalnej,
  przekroczenia progu, dobrania oraz wyniku. Nie zastępować jednego
  efektu drugim ze względu na ich jednoczesność. Wyliczać je z faktycznie
  zaakceptowanego ruchu i jego skutków, bez zmiany zasad/punktacji gry.
- Przejrzeć dobór efektów pozostałych gier pod kątem podobnego odrzucania
  niezależnych dźwięków. Nie usuwać rozróżnienia zdarzeń, które z natury
  wzajemnie się wykluczają, ani dodawać nowych efektów bez potrzeby.
- Zachować równoległe odtwarzanie: bez wyciszania poprzedniego efektu,
  kolejkowania do jego końca lub sztucznych pauz. Sprawdzić też kilka
  kolejnych zdarzeń odebranych razem. Zachować ustawienia głośności
  i wyciszeń oraz ochronę przed powtórnym dźwiękiem tego samego zdarzenia
  po odświeżeniu; to nie jest zakaz nakładania różnych zdarzeń.
- Dodać celowane regresje waleta z przekroczeniem 33/66, czwórki ze zmianą
  kierunku i progiem, efektów wyniku oraz ruchu z dobraniem. Korzystać
  z legalnych przejść stanu; nie dopisywać dobrania po zakończonej rundzie.
  Sprawdzić komplet wywołań odtwarzacza, nie tylko listę nazw, a przy
  weryfikacji klienta również rzeczywiste nakładanie efektów.

Na etapie planu tylko odczyt i izolowane sprawdzenie selektora, bez
uruchamiania pełnych testów, odtwarzania audio, zmian kodu i paczki.

## 8. Farkle — dźwięk odłożenia punktów (bank)

Status: zapisane do późniejszego wdrożenia, bez kopiowania pliku ani
zmian aplikacji na obecnym etapie.

Użytkownik wskazał `farkle_bank.ogg` z Dokumenty/freesound jako dźwięk
zatwierdzenia odłożenia punktów w Farkle. Chodzi o akcję `bank`, nie
o zapis partii do późniejszego wznowienia ani samo zaznaczenie kości.

Na dysku znaleziono plik pod nieco inną nazwą:
`C:/Users/mateu/Documents/freesound/farkle)bank.ogg` (35 559 bajtów),
SHA-256 `d0a06abbd62fbc7ed47ae77cb54c98f923d8d2effeaa217134cb96305adf0e73`.
Pliku z podkreśleniem w tym katalogu obecnie nie ma. Przy wdrożeniu użyć
znalezionego pliku jako zasobu `Audio/farkle_bank.ogg`, zachowując oryginał.

Efekt odtwarzać po zaakceptowanym `bank` gracza lub bota, przez wspólną
ścieżkę dźwięków zdarzeń u uczestników/obserwatorów. `apply_bank` zapisuje
historię rodzaju `:bank`, lecz obecny `farkle_cue` tego nie obsługuje.
Dodać zasób do listy i paczki; uwzględnić głośność/wyciszenie dźwięków gier.
Nie grać przy odrzuconej próbie odłożenia punktów ani powtórnym odświeżeniu.
Zgodnie z punktem 7 efekt bankowania nie zastępuje dźwięku wyniku partii
i nie czeka na jego zakończenie. Nie dodawać nowego komunikatu głosowego.

Przy wdrożeniu sprawdzić zwykły bank, bank kończący partię, nielegalną
próbę i deduplikację oraz obecność pliku w gotowej paczce. Na razie
tylko odczyt kodu i potwierdzenie pliku; bez odsłuchu i testów gry.

## 9. 99 — dźwięk trafienia dokładnie w 33 lub 66

Status: zapisane do późniejszego wdrożenia, bez zmian aplikacji.

Użytkownik wskazał dźwięk `ninety3366` z tego samego folderu do sytuacji,
gdy gracz osiągnie dokładnie 33 albo 66. Potwierdzony plik:
`C:/Users/mateu/Documents/freesound/ninety3366.ogg` (11 798 bajtów),
SHA-256 `d4d8748dfd9cab0a1c95148ca67fab6cc9b8b35d92cea7431194b9beb6d9fe10`.
Przy wdrożeniu dodać jako `Audio/ninety3366.ogg`, zachowując oryginał,
uwzględnić w dostępnych zasobach i gotowej paczce.

Efekt dotyczy trafienia w próg, nie przeskoczenia ponad niego. Powiązać
z istniejącą regułą `exact_danger_reached?`: suma wzrasta do 33/66,
w tym podwojenie 33 do 66. Samo pozostawienie sumy bez zmiany albo
obniżenie jej do progu nie uruchamia tej reguły; nie zmieniać punktacji.
Dźwięk po zaakceptowanym ruchu gracza lub bota słyszą uczestnicy
i obserwatorzy, zgodnie z ustawieniami głośności/wyciszenia gier.

Zgodnie z punktem 7 nie zastępować nim efektu zagrania karty, waleta,
zmiany kierunku, dobrania ani wyniku. Równoczesne, należne efekty mają
się nakładać bez pauz; ponowne odświeżenie nie gra tego zdarzenia drugi raz.
Nie dodawać nowego komunikatu głosowego.

Przy wdrożeniu sprawdzić 32 → 33, 65 → 66, 33 → 66 oraz waleta
23 → 33; odróżnić je od przekroczenia progu, braku zmiany sumy i spadku
do 33/66. Kontrola pliku w paczce i wspólnego odtwarzania z innymi efektami.
Na razie tylko odczyt kodu i potwierdzenie pliku, bez kopiowania, odsłuchu
oraz testów gry.

## 10. Wszystkie gry — nowy dźwięk wygranej całej partii

Status: zapisane do późniejszego wdrożenia, bez zmian aplikacji i paczki.

Użytkownik chce zastąpić dotychczasowy dźwięk wygrania całej partii
plikiem `C:/Users/mateu/Documents/freesound/win_party.ogg`.
Plik potwierdzony: 38 309 bajtów, SHA-256
`3bf14bd0c6ea156a8d2330f7d3cea9f82bdb144f374028671461b86b4cee0cca`.
Docelowo zasób `Audio/win_party.ogg`, z zachowaniem pliku źródłowego.

Podmiana we wspólnej obsłudze wyniku partii, obecnie `result_cue` wybiera
`win2` dla zwycięzcy (także w gałęzi awaryjnej). Nie dokładać nowego efektu
obok starego: zwycięzca ma słyszeć `win_party` zamiast `win2`. Zachować
rozpoznawanie zwycięskiej drużyny oraz dotychczasowe zachowanie przegranej,
remisu i obserwatora. Dźwięki wygranej/przegranej rundy lub rozdania
(`win1`/`lose1`) pozostają bez zmian. Później uzgodnioną podmianę dźwięku
przegranej całej partii opisuje punkt 11.

Uwzględnić listę zasobów, pakowanie, głośność/wyciszenie gier i punkt 7:
wynik może nakładać się z dźwiękiem kończącego ruchu. Bez ponownego
odtwarzania po odświeżeniu zakończonej partii i bez nowych komunikatów.
Przy wdrożeniu celowane testy wyniku indywidualnego/drużynowego,
oddzielnych efektów rundy i partii, głośności oraz obecności pliku w paczce.
Na etapie planu tylko potwierdzenie pliku i odczyt wspólnej obsługi;
bez kopiowania, odsłuchu, testów gry ani przebudowy.

## 11. Wszystkie gry — nowy dźwięk przegranej całej partii

Status: zapisane do późniejszego wdrożenia, bez zmian aplikacji i paczki.

Analogicznie do punktu 10 użytkownik chce zastąpić dotychczasowy dźwięk
przegrania całej partii plikiem
`C:/Users/mateu/Documents/freesound/lose_party.ogg`.
Plik potwierdzony: 92 799 bajtów, SHA-256
`58a803cce1fd954ebcabdeefca5fa5f5c30cdc5e2fb219c72d93398ea30464e9`.
Docelowo zasób `Audio/lose_party.ogg`, z zachowaniem pliku źródłowego.

We wspólnej obsłudze wyniku `result_cue`, także w gałęzi awaryjnej,
zastąpić `lose3` przez `lose_party`. Nie odtwarzać obu efektów przegranej.
Uwzględnić wynik drużyny oraz obsługę remisu i obserwatora; nie zmieniać
zasad rozstrzygania wyniku. Dobór momentu odtworzenia rozszerzyć o
eliminację z całej partii, zgodnie z doprecyzowaniem poniżej.
Dźwięk przegranej rundy lub rozdania `lose1` i wygranej rundy `win1`
pozostają bez zmian. Wygrana całej partii otrzymuje osobną podmianę
opisaną w punkcie 10.

### Doprecyzowanie: przegrana już przy eliminacji

Gracz trwale wyeliminowany z partii ma usłyszeć `lose_party` od razu po
zaakceptowanym zdarzeniu eliminacji, nawet jeżeli pozostali nadal grają.
Nie czekać na zakończenie całej partii. Jeśli odpada drużyna, dotyczy to
jej członków, zgodnie z zasadami danej gry. Pozostali gracze i obserwatorzy
nie słyszą z tego powodu własnego dźwięku przegranej.

Odtworzyć raz dla danej eliminacji; nie ponawiać przy kolejnych ruchach,
odświeżeniu, odtworzeniu historii ani końcowym rozstrzygnięciu tej samej
partii. Gracze niewyeliminowani wcześniej otrzymują zwykły dźwięk wyniku
na jej końcu. Nowa partia ma niezależną obsługę wyniku.

Rozróżnić odpadnięcie z całej partii od samej rundy lub rozdania (np.
UNO No Mercy), spasowania w Pokerze, pominięcia tury, rozłączenia oraz
przejścia w tryb obserwatora. Żadna z tych sytuacji sama w sobie nie
oznacza trwałej przegranej. Nie wyciągać tego wniosku wyłącznie z braku
gracza w bieżącej kolejce. Gdy to samo zdarzenie kończy całą partię,
uwzględnić jej ostateczne rozstrzygnięcie, w tym zwycięstwo/remis przy
jednoczesnym przekroczeniu limitu, zamiast ogłaszać zwycięzcy przegraną.

Obecny `result_cue` sprawdza najpierw `finished?`, więc sama podmiana
nazwy pliku nie realizuje tego wymagania. Przy wdrażaniu oprzeć wspólną
obsługę na zmianie rzeczywistego statusu udziału przed/po zdarzeniu,
z uwzględnieniem różnic między grami; nie zmieniać zasad eliminacji.
Sprawdzić wcześniejsze odpadnięcie, eliminację drużyny, kilka eliminacji
naraz, eliminację razem z końcem partii, brak powtórzeń przy jej końcu
i odświeżeniu oraz brak efektu partii przy odpadnięciu tylko z rundy.

Uwzględnić listę zasobów, pakowanie, głośność i wyciszenie gier oraz
nakładanie z dźwiękiem kończącego ruchu zgodnie z punktem 7. Zachować
ochronę przed ponownym odtworzeniem wyniku po odświeżeniu, bez nowych
komunikatów. Przy wdrożeniu celowane testy wyników indywidualnych
i drużynowych, odróżnienia rundy od partii oraz obecności pliku w paczce.
Na etapie planu tylko potwierdzenie pliku; bez kopiowania, odsłuchu,
testów gry ani przebudowy.

## 12. Tysiąc — dźwięk mariażu

Status: zapisane do późniejszego wdrożenia, bez zmian aplikacji i paczki.

Dodać dźwięk `1000_mariage.ogg` przy skutecznym zadeklarowaniu mariażu
przez dowolnego gracza: lokalnego, przeciwnika lub bota. To publiczne
zdarzenie gry, słyszalne u uczestników i obserwatorów, nie tylko u osoby
deklarującej mariaż.

Plik źródłowy potwierdzony:
`C:/Users/mateu/Documents/freesound/1000_mariage.ogg`, 13 791 bajtów,
SHA-256 `46ef75b8f15682e680da0821c47e0eb007047019aeff30fe464b7d883eda0981`.
Docelowo zasób `Audio/1000_mariage.ogg`, bez zmiany pliku źródłowego.

W istniejącym kodzie jest to zaakceptowana akcja `play` w trybie
`marriage`; samo posiadanie pary król–dama, otwarcie wyboru albo zwykłe
zagranie jednej z tych kart nie wystarcza. Nie odtwarzać efektu przy
odrzuconym ruchu ani po ponownym odświeżeniu tego samego zdarzenia.
Obecna obsługa dźwięku Tysiąca ignoruje tryb (`_mode`) i dobiera tylko
efekty zagrania/atutu. Przy wdrożeniu dołączyć efekt mariażu niezależnie,
zachowując inne dźwięki ruchu i wyniku zgodnie z punktem 7, głośność
oraz wyciszenie gier. Bez zmiany zasad, punktacji i komunikatów.

Przy wdrożeniu sprawdzić własny/cudzy mariaż i bota, wszystkie cztery
kolory, zwykłe zagranie króla/damy bez meldowania, niedozwoloną próbę,
brak powtórzeń, nakładanie efektów i obecność zasobu w paczce.
Na etapie planu tylko potwierdzenie pliku i odczyt kodu; bez kopiowania,
odsłuchu, testów gry ani przebudowy.

## Kolejne punkty

Do uzupełnienia po dalszych propozycjach użytkownika.
