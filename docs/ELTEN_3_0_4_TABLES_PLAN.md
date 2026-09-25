# Plan na ELTEN 3.0.4 — gospodarz, zastępstwa, praca w tle i zapisy

Stan: 24 września 2026. Pięć zatwierdzonych punktów wdrożono w źródłach
i sprawdzono testami lokalnymi oraz próbami na trzech kontach. Nie wydano
jeszcze paczki. Dokument nie upoważnia do dowolnych zmian serwera,
instalacji, publikacji ani budowy paczki. Podstawa: źródła Game Roomu
2.0.3.1/build 238 oraz odczytane API uruchomionego ELTEN-a 3.0.4 RC 1.
Przed wydaniem sprawdzić także kontrakt finalnego ELTEN-a 3.0.4.

## Dwie poprawki po zgłoszeniach użytkownika — 25 września 2026

Brak dostępu do tabel nie blokuje już całego okna Ustawień. Lokalne
preferencje pozostają dostępne; tylko lista subskrypcji nowych stołów
zostaje zastąpiona objaśnieniem. Nieudany odczyt nie oznacza pustej listy,
a nieudany zapis serwerowy nie odrzuca pozostałych lokalnych zmian.
Komunikat wskazuje częściowy zapis oraz potrzebę restartu po zmianie języka.
Ochrona tabel nie została zmieniona ani ominięta.

Automatyczne zastępowanie w Audio Ballu i Pongu było niekompletne mimo
wcześniejszych prób ręcznych zamian. Sama zmiana członkostwa odświeżała
osoby, lecz nie wybudzała polityki zastępstwa; dodatkowo zewnętrzna pętla
ekranu odwoływała się do nieistniejącego pola transportu. Pierwsza poprawka
samego wybudzenia nie przeszła rzeczywistej próby i dopiero ona ujawniła
drugi błąd. Oba naprawiono. Zastępstwo nadal wykonuje normalne zadanie
sieciowe uprawnionego gospodarza, nie callback formularza. Nie dodano
pollingu ani zastępowania za samą utratę kanału Communications.

Końcowe 22 celowane skrypty są poprawne. Nowa regresja sprawdza zarówno
membership-only/recovery, jak i rzeczywistą pętlę GameScreen do wywołania
transportu. Odrębne kontrolne przywrócenie błędu w procesie testowym
potwierdza, że regresja go wykrywa. Cztery wcześniejsze testy zależały od
nieaktualnych indeksów kategorii; poprawiono fixture, nie działające UI.
Sprawdzono binarne źródła i PL/EN/fallback oraz zachowanie wcześniejszych
tłumaczeń; dodano trzy nowe wpisy.

Trzy końcowe rzeczywiste próby na dwóch kontach: wyjście gościa Audio Balla,
wyjście gościa Ponga i wyjście gospodarza Audio Balla. Bez dodatkowego
ruchu, Entera lub odświeżenia pozostającego gracza następowało fizyczne
zastępstwo botem i, gdy trzeba, przejęcie gospodarza. Boty w Pongu i po
przejęciu Audio Balla zdobyły po dwa trwałe punkty. Powrót zastąpionej
osoby jako obserwatora i ponowne wyjście nie zdublowały bota. Fokus/szkic
czatu zachowane. Osobno otwarto natywne Ustawienia na koncie z odmową
stamp_required. Próby używały handlerów kontrolek na jednym komputerze,
nie fizycznej klawiatury/odsłuchu ani pełnych meczów i wszystkich awarii.

Poprawione metody i katalog pozostawione w pamięci trzech działających
kopii, bez restartu lub pełnego reloadu. Główny, już otwarty ekran wymagał
jednorazowej aktywacji po hotloadzie — nie wliczać jej jako dowodu naturalnej
dostawy. Własne stoły prób i sondy usunięte, stół użytkownika zachowany.
Nie budowano paczki, nie zmieniano wersji/changelogu/profili/serwera
i nie publikowano. Raport prywatny: ../diagnostics/settings-departure-304/.

## Powrót obserwatora po zastąpieniu botem — 25 września 2026

Na istniejącym stole użytkownika w 99 odtworzono powrót do głównego menu
mimo udanego dołączenia jako obserwator. Był to zakolejkowany po wcześniejszym
wyjściu sygnał `closed`, a nie usunięcie osoby z serwera. Dotychczasowy guard
starego callbacku tego nie obejmował: sygnał zdążył już wejść do kolejki
PRZED utworzeniem nowego członkostwa. Transport odrzuca teraz takie
zamknięcie, gdy istnieje nowe otwarte członkostwo, sprawdzane lokalnie
bez I/O. Prawdziwe zamknięcie i błędy sieciowe nadal przechodzą.

19/19 celowanych skryptów poprawnych, bez pełnego runnera. Uzupełniono
atrapę natywnego `leave`, która wcześniej nie dostarczała `on_closed`.
Nowa regresja bada wczesne/spóźnione zamknięcie, wielokrotny powrót do
poczekalni/partii, obserwatora po zamianie oraz prawdziwe zamknięcie po
usunięciu obiektu z cache. Trzy kolejne żywe wyjścia/powroty po korekcie
pozostawiły otwarte UI, obserwatora i jednego bota; stan gry oraz gospodarz
nie zmieniły się. Raport prywatny `../diagnostics/participant-rejoin-304/`.
Końcowy czwarty powrót, już bez sondy, również przeszedł poprawnie;
obaj uczestnicy pozostali przy tym samym stole, bez nowego ruchu.
W odróżnieniu od wcześniejszej próby poniżej ten konkretny objaw został
odtworzony na stole użytkownika. Nie oznacza to dowodu wszystkich awarii
członkostwa ani testu różnych komputerów/łączy. Menu uruchamiano handlerami,
potwierdzenie wyjścia klawiszami skierowanymi do natywnego okna testowego.

Poprawka dwóch metod jest w źródłach i w pamięci trzech działających kopii,
bez restartu lub przeładowania całej aplikacji. Bez paczki/publikacji,
zmiany wersji/changelogu, serwera lub ruchów w partii użytkownika.

## Wybrana osoba i gry bez botów — 25 września 2026

Najnowsza decyzja zastępuje opis zamieniania dwóch grających osób poniżej.
`Ctrl+Shift+R` działa wyłącznie na liście użytkowników, na wybranym graczu
lub bocie. Od razu otwiera jedną listę zastępstw: obecni ludzie, którzy
nie grają, oraz nowy nazwany bot, gdy zastępujemy człowieka w grze z botami.
Obserwator nie jest źródłem zamiany; inna grająca osoba nie jest celem.
Anulowanie niczego nie zapisuje; brak kandydatów ma własny komunikat.
Po wyborze ponownie sprawdzane są obecność, uprawnienia i zajętość miejsca.
`Ctrl+M` nadal wybiera nowego gospodarza. Stare zapisy dawnych zamian
pozostają odtwarzalne, mimo że nowy interfejs nie proponuje takich zamian.

Osobno odtworzono błąd transportu: opóźniony callback zamknięcia starego
obiektu członkostwa mógł zamknąć nowe okno i wyczyścić jego oczekujący ruch,
choć użytkownik pozostawał przy stole. Teraz odrzucany jest callback,
gdy istnieje już inne bieżące członkostwo. Prawdziwe zamknięcie jest nadal
obsługiwane, także gdy odczyt wcześniej usunął zamknięty obiekt z cache.
To potwierdzony reproduktor lokalny, **nie dowód przyczyny konkretnego
zgłoszenia użytkownika z 99**. W pierwszej żywej próbie zgłoszonego
wyrzucenia po zamianie nie udało się powtórzyć.

Sprawdzono cztery gry bez botów:

- Scrabble: zastępstwo człowiekiem, puste miejsce po wyjściu, powrót z tym
  samym stojakiem, przejęcie gospodarza i dalsze legalne ruchy.
- Taboo: zachowanie drużyn oraz dalsze przygotowanie, opisywanie, koniec
  czasu i zatwierdzenie punktów przez nowego gospodarza.
- Państwa-miasta: brak fikcyjnej odpowiedzi za nieobecnego, powrót autora
  z oryginalną kopertą, anulowanie nieodzyskiwalnej rundy przez nowego
  gospodarza i odblokowanie zarządzania na bezpiecznej granicy.
- Krowa: wyjście/powrót gościa w Wyścigu i Wieży nie zmienia sekretu;
  dalsze próby są oceniane. Reguły dostępu Dziennej Krowy i blokady zmian
  przy prywatnym stanie pozostają zachowane. Nie obiecujemy przeniesienia
  sekretu po utracie gospodarza; nadal można przerwać partię.

Bez botów nie tworzymy automatycznego zastępcy. Miejsce zostaje w partii;
człowiek może wrócić lub gospodarz może wskazać obecnego obserwatora,
o ile pozwala na to faza. Nie dodano nowego automatycznego pasa/przegranej
za odejście; istniejące limity czasu nadal są regułą danej gry.

26/26 celowanych skryptów poprawnych, bez pełnego runnera. Końcowe żywe
próby: 17 porównań w 99, 14 w Scrabble z obserwatorem, 10 w Scrabble
z trzema grającymi ludźmi. Kontrolowano okna, role, ręce, historię, fokus
i szkic czatu, odejście/powrót, kolejnych gospodarzy oraz ostatniego członka.
To 41 punktów kontrolnych, nie 41 pełnych partii. Taboo, Państwa-miasta
i Krowę sprawdzano lokalnie na rzeczywistych modelach i atrapach API;
nie uruchamiano ich nowych żywych partii w tym etapie.

Raport prywatny: `../diagnostics/participant-focus-304/README.md`,
`RESULT.json`, `TESTS.json`, `LIVE-*.json`. Zachowano niepełne wcześniejsze
próby i opis błędów pomocników. Jeden komputer/łącze; wejście handlerami,
nie fizycznymi klawiszami, bez deklaracji odsłuchu. Nie jest to dowód
wszystkich możliwych awarii, utraty procesu lub dzierżawy serwera.

## Żywe zamiany i korekta odświeżania — 25 września 2026

Po zgłoszeniu użytkownika uruchomiono normalne ekrany Game Roomu na trzech
kontach, z rzeczywistymi prywatnymi stołami i standardowymi poleceniami
zamiany/przekazania. Odtworzono rozjazd pomijany przez wcześniejsze testy
modelu: wykonawcy mieli nowe osoby, lecz ekrany gości pozostawały przy
starym replayu, ręce i turze. Po przywróceniu człowieka mogły nadal pokazywać
bota oraz mylne „zagra w następnej partii”. Kolejny ruch czasem to naprawiał.

GameScreen traktuje teraz powiadomienie o stole również jako możliwą zmianę
metadanych partii. Sprawdza istniejącą projekcję sesji i odświeża replay,
gdy zmieniło się sterowanie lub sama sesja, także bez nowego zdarzenia gry.
Nie dodano pollingu ani wymuszania odczytu serwera; zwykła aktualizacja
osób/czatu bez takiej zmiany nie przebudowuje pola gry. Regresja sprawdza
niezmienioną rewizję ruchów i zachowanie szkicu/fokusu czatu.
Listy nazywają teraz bieżącego gospodarza „gospodarzem stołu”, a nie jego
założycielem. To jedna celowa korekta istniejącego polskiego tłumaczenia.

Po poprawce sześć prób na żywych stołach: UNO, Makao, Spades w drużynach,
Pong w singlu i deblu oraz Audio Ball. Sprawdzono role w obu kierunkach,
zamianę dwóch graczy, przejęcie ręki/miejsca/drużyny, człowiek → bot → człowiek,
automatyczne zastępstwo po wyjściu, powrót bez odebrania miejsca botowi,
przekazanie gospodarza grającemu/obserwatorowi i dalsze ruchy oraz punkty.
Porównywano wszystkie okna, wykonawców i klientów zręcznościowych,
nie tylko stan gospodarza. Zachowany fokus czatu potwierdza 13 próbek;
treść szkicu sprawdzono w regresji lokalnej, pierwsza żywa sonda jej nie zapisywała.

21/21 celowanych skryptów i kontrola katalogu poprawne. Prywatny raport
`../diagnostics/participant-live-304/README.md` opisuje 55 porównań,
reprodukcję, początkową nieukończoną próbę punktu z automatycznym odbijaniem,
błędy pomocników i próbkę podczas przejścia do nowego gospodarza.
Nie uznawać ich za 55 pełnych partii ani wszystkie możliwe sytuacje.
To rzeczywiste API/relay i natywne kontrolki; polecenia wywoływane handlerami,
nie fizyczną klawiaturą ani odsłuchem. Jeden komputer i łącze.

Zamknięto siedem własnych stołów (jeden reproduktor i sześć prób poprawki).
W trzech uruchomionych kopiach pozostawiono komplet poprawionych źródeł/MO,
bez sond i aktywnych prób. Instalacje na dysku i podpisana paczka 238 bez
zmiany; brak nowego wydania, publikacji, zmian schematów lub quota.

## Korekta: rzeczywista zamiana uczestników — 24 września 2026

Po sprawdzeniu wczytanej wersji użytkownik odrzucił sterowanie botem pod
tożsamością człowieka. Aktualne źródła zastępują samą osobę w partii:

- `Ctrl+Shift+R` — wybór osoby, następnie zastępstwa. Można wybrać inną
  osobę przy stole, już grającą osobę albo nowego nazwanego bota.
- Gracz A ↔ obserwator B: B zajmuje miejsce A i staje się graczem,
  A zostaje obserwatorem. Działa także przy wskazaniu najpierw B.
- Gracz A ↔ gracz B: obie osoby pozostają graczami i zamieniają się
  miejscami wraz z rękami, wynikiem, drużyną oraz obowiązkami danego miejsca.
- Gracz → bot: nowy bot ma własny identyfikator i imię, widoczne w grze
  oraz nowych komunikatach. Zastąpiony człowiek jest obserwatorem.
  Bot → obserwator: człowiek przejmuje miejsce, a bot znika ze stołu.
- `Ctrl+M` — wybór nowego gospodarza; nie wymaga wcześniejszego ustawienia
  kursora na liście osób. Oba polecenia są także w menu i pomocy.

Zamiana jest jednym zatwierdzonym wpisem w istniejącym dzienniku sterowania.
Stare ruchy, ich autorzy i stare komunikaty nie są przepisywane. Model stanu
przyporządkowuje je do właściwych miejsc przez istniejący kontrakt odtwarzania
gry. Zapis/odtworzenie zachowuje również kolejność zamian; większe wpisy
z nazwami Unicode dzielone są zgodnie z limitem bajtów Live Sessions.

Zachowane są ograniczenia faz z prywatnymi danymi, prawo gospodarza,
odrzucanie spóźnionych ruchów, starej partii i niezatwierdzonych zmian.
Potwierdzone odejście nadal uruchamia zastępstwo automatycznie, bez opcji;
powrót nie usuwa samowolnie bota. W Pongu po zastąpieniu pierwszej osoby
nie zmienia się wynikająca z początku meczu kolejność pierwszego serwu.

Pierwsze próby tej korekty były lokalne: bezpośrednie zamiany w obu kierunkach,
drużyny, odebranie prawa do ruchu, dalsza gra i wielokrotne odtworzenie.
Nowe kontrakty modeli obejmują 22 zwykłe gry; oddzielne testy obejmują
Ponga i Audio Balla. Wyniki i ograniczenia:
`../diagnostics/participant-replacement-304/README.md` oraz `TESTS.json`.
Nie należy utożsamiać ich z wcześniejszymi żywymi próbami poniżej,
które badały odrzucony później model kontrolera. Na osobne polecenie
użytkownika wczytano już korektę do pamięci wszystkich trzech kopii
(papierek, papiertestowy, papiertestowy1): każde wywołanie ok:true,
217 źródeł, bez stderr. Bez restartu/instalacji i bez kolejnych testów.
Działa do przeładowania programu lub restartu ELTEN-a. Nie wydano paczki.

## Ukończone wdrożenie — 24 września 2026

Poniższy opis i liczby testów dotyczą etapu sprzed korekty powyżej.

1. Menu osoby pozwala przekazać gospodarza. Zwykłe wyjście przekazuje stół
   następnemu obecnemu graczowi, a przy braku graczy — obserwatorowi.
   Zamknięcie stołu wszystkim to osobne polecenie. Nowy gospodarz przejmuje
   boty, zarządzanie stołem i publikowanie jego opisu.
2. Potwierdzone odejście uruchamia zastępstwo botem bez przełącznika,
   w obsługujących je grach i bezpiecznych fazach. Miejsce, ręka, drużyna
   i wynik pozostają. Powrót nie odbiera sterowania botowi; gospodarz
   przywraca je człowiekowi osobnym poleceniem.
3. „Ogólne” zawiera język oraz domyślnie włączone ustawienia mowy stołu
   i sygnału `ding` własnej decyzji poza jego oknem. Jedne ustawienia dla
   innej części ELTEN-a i innej aplikacji; bez wpływu na historię/model.
4. Każdy zapis jest prywatnym skompresowanym plikiem na koncie,
   z wcześniejszym przydziałem 16 MiB. Odczyt i kontrola przed zamknięciem,
   odtworzenie w nowej sesji, także z zastępstwami. Brak lokalnego fallbacku;
   starych plików nie usuwano. Zapis należy do aktualnego gospodarza.
5. Widget i listy pokazują stan oczekiwania/partii oraz graczy z botami,
   bez obserwatorów. Podczas partii liczone są miejsca, także zastępcze.
   Odmowa dołączenia zachowuje właściwy powód z Live Sessions.

### Zabezpieczenia i próby

Uprawnienia pochodzą z natywnego właściciela. Historię kontrolerów
uwierzytelnia kotwica w metadanych zapisywalnych tylko przez właściciela.
Dawne zdarzenia zachowują dawne uprawnienia. Spóźnione akcje starego
kontrolera i polecenia poprzedniej partii są odrzucane. Pong/Audio Ball
wymieniają kanał, zachowują wynik i ponawiają niedokończoną wymianę;
bez zmiany fizyki i bezpośredniego przesyłania akcji. Pakiety zastąpionego
człowieka/obserwatora nie mogą nadpisywać paletki bota. Zachowano automatyczne
przyjęcie kary w Makao i odmowę zakupu w Monopoly również dla nowego gospodarza.

Końcowo **66/66 celowanych skryptów** poprawnych, nie pełny runner.
W tym kontrakty wykonawcy 23 gier, przekazanie obserwatorowi i zastępstwo
pierwszego gracza w 22 grach, prywatne fazy, utracone potwierdzenia,
stare uprawnienia, rewanż, zapis, Unicode, kursor, sygnały decyzji oraz
singiel i mieszany debel. 59 zmienionych/nowych Ruby poprawnych składniowo.
4591 wcześniejszych tłumaczeń zachowanych, 25 dodanych; PO/MO i binarne
źródła oraz natywne kontrolki sprawdzone.

Żywe próby: trzy konta `papierek`, `papiertestowy`, `papiertestowy1`,
wszystkie na 3.0.4 RC 1. Trzecia kopia uruchomiona zwykłym skryptem ze
zaktualizowanego katalogu testowego. Farkle, UNO, Pong i Audio Ball:
wielokrotne przekazanie, wyjście gracza/gospodarza, istniejące i zastępcze
boty, powrót człowieka, zgodne zdarzenia i wyniki. UNO zapisano na koncie
nowego gospodarza, zamknięto oryginalny stół, odtworzono w nowej sesji
i rozegrano dalsze ruchy.

Były to prawdziwe API/relay, repozytoria, wykonawcy i klienci gier
z wejściem pomocników, nie fizyczna klawiatura/odsłuch ani trzy komputery.
Gry zręcznościowe miały cichy adapter audio. Kontrolki hosta testowano
osobno offline. Początkowe błędy pomocników i regresje wersji roboczej
zachowane w raporcie, poprawione próby powtórzone. Dwa testy natywne
początkowo korzystały z niewłaściwych źródeł hosta, a test języka bez
ścieżki hosta był pominięty; po ustawieniu 3.0.4 wszystkie przeszły.

Usunięto wyłącznie własne stoły/archiwum prób i sondy z pamięci. Trzy kopie
pozostają na ekranie głównym; głównego hosta nie restartowano. Nie instalowano
i nie pozostawiono nowego Game Roomu do normalnego użycia.
Raport: `../diagnostics/elten-304-points-1-2/RESULT.json` i `README.md`.

### Granice i stan wydania

- Statki/Krowa w trakcie partii oraz prywatne fazy odpowiedzi/ujawniania
  quizu i Państw-miast nie pozwalają na bezpieczne przekazanie sekretów.
  Operacja podaje powód; bot nie udaje posiadania cudzych danych. Nie dodano
  botów do gier, które ich nie obsługują.
- Zwykłe wyjście i natywne opuszczenie członkostwa nie dowodzą zachowania
  serwera po zabiciu procesu lub wygaśnięciu dzierżawy przy długiej awarii.
  Takiej próby nie wykonywano.
- Minimalne API manifestu i runtime to teraz **3.0.4**. Discovery 7 oddziela
  stoły od starszych klientów. Wersja/build 238 bez zmiany; podpisana 238
  nietknięta i nie zawiera tych zmian. Przed wydaniem sprawdzić finalne 3.0.4.
- Bez nowych zmian quota, ochrony lub tabel; bez GitHuba, podpisu i paczki.

## Historia etapu po zmianie limitu na 16 MB

Poniższy zapis pochodzi sprzed ukończenia punktów 1–2 i prób na trzech
kontach. Informacje o niewdrożonych punktach i API 3.0.3 są historyczne.

Użytkownik zatwierdził wdrożenie całego planu oraz próby na kontach
`papierek` i `papiertestowy` z tymczasowymi prywatnymi stołami/plikami.
Potwierdził konto deweloperskie `papierek`. Automatyczne zastępowanie
wychodzących graczy ma być stałym zachowaniem, bez przełącznika. Sygnał
własnej tury w tle: istniejący `ding`.

Po początkowej zgodzie na 10 MB użytkownik zmienił limit na **16 MB**.
Serwer przyjął `max_private_resources_bytes_per_user: 16777216`.
Zmieniono wyłącznie ten parametr aplikacji; porównanie potwierdziło
niezmienność tabel, ochrony i limitu publicznych zasobów. Nowe API prywatnych
zasobów rzeczywiście działa: oba konta przesłały i odczytały własny plik;
lista drugiego konta nie pokazała pierwszego pliku, próba pobrania jego
metadanych i zawartości zwróciła 404. Bajty własnych plików zgodne.
Oba pliki testowe (ID 1 i 2) usunięto i potwierdzono ich nieobecność.
Nie dotykano rzeczywistych zapisów ani istniejących stołów.

Źródła obejmują obecnie punkty 3, 4 i 5, lecz **cały plan nadal nie jest
ukończony ani gotowy do wydania**. `AccountSavedGames` przechowuje pojedynczy
skompresowany plik z manifestem i weryfikuje odczyt przed zamknięciem stołu;
brak lokalnego fallbacku, dotychczasowe lokalne pliki nietknięte. Lista pobiera
same manifesty, odtworzenie pełny plik. Zgubione potwierdzenie przesłania lub
usunięcia wymaga sprawdzenia dokładnie tego zapisu. Odczyt ma limit rozmiaru,
kontrolę sumy i odrzuca niepełny strumień oraz dopisane dane.

Kolejny etap lokalnej weryfikacji: **31/31 celowanych skryptów poprawnych**.
Sprawdzono nowy magazyn, zamknięcie pierwotnej sesji i dokładne odtworzenie
przy nowym stole, kolejny ruch drugiego klienta, stare archiwa 16 gier,
discovery, prezentację w tle, wykonawcę, poczekalnię i ustawienia. Są też
testy jednoczesnych decyzji quizu/Państw-miast/Statków/Krowy, braku sygnału
na przechwycenie UNO i automatyczne ujawnienie odpowiedzi. Sygnał tury jest
pojedynczy dla nadal aktualnej decyzji; nie odtwarza minionych tur po
nadrabianiu zdarzeń ani nieaktualnych powiadomień z kolejki dźwięków.

Polskie teksty uzupełniono; wszystkie 4591 wcześniejszych tłumaczeń zachowane,
osiem dodanych. Binarne wczytanie PL/EN/fallback i natywna kontrolka sprawdzone,
również polski nick jako ciąg binarny. Naprawiono normalizację tego nicku
w opisach stołu/widgetu. Natywna próba wpisywania tekstu podczas prezentacji
nie gubi znaków ani fokusu. 27 zmienionych plików Ruby poprawnych składniowo.

To testy lokalne z atrapą sesji i rzeczywistymi kontrolkami hosta, **nie pełny
runner ani żywe partie z tym nowym kodem**. Pierwsze błędy pomocników i prób
z niewłaściwą wersją źródeł hosta zachowane w raporcie, poprawione powtórzenia
osobno. Prywatny raport: `../diagnostics/elten-304-points-3-5/RESULT.json`.
Pozostają żywa integracja całości oraz podniesienie minimalnego API wydania
do 3.0.4; manifest/runtime nie zostały jeszcze zmienione z 3.0.3.
Punkty 1 i 2 (przekazywanie gospodarza i kontrolerów miejsc) **niewdrożone**.
Nie stosować nowego gospodarza wstecz do walidacji dawnych zdarzeń.

Główna kopia ma 3.0.4 RC 1. Uruchomiona zwykłym skryptem kopia testowa
(PID 19100, konto `papiertestowy`, MCP 37374) ma nadal 3.0.3 i nie ma nowych
metod przekazania gospodarza. Prywatny magazyn sprawdzono na niej przez
istniejący klient HTTP zgodnie z odczytanym kontraktem 3.0.4, bez podmiany
kodu hosta. Pierwszy pomocnik próby nie obsługiwał braku `api_download`;
poprawiona próba użyła istniejącego odczytu surowej odpowiedzi i przeszła.
Następnie użytkownik zatwierdził aktualizację **wyłącznie kopii testowej**
do tej samej 3.0.4 RC 1 oraz wykluczył dodatkową kopię starego hosta.
Aktualizacja istniejącego katalogu testowego zakończona: PID22920,
`papiertestowy`, ten sam profil i język, MCP37374 po nowej sesji, API3.0.4.
Potwierdzono dostępność przekazania gospodarza, odświeżania discovery
i prywatnych zasobów. Główna PID20496/papierek bez restartu lub zmian.
Raport `../diagnostics/test-elten-304-upgrade/RESULT.json`. Ten etap nie
obejmuje jeszcze żywych prób przekazywania gospodarza ani instalacji
nowego Game Roomu. Brak metody na poprzednim hoście nie był błędem serwera.

Brak buildu, instalacji/hotloadu Game Roomu, zmiany wersji lub GitHuba.
Podpisana 238 pozostaje niezmieniona. Nie przywracać historycznych
hotloadów ani nie restartować głównego klienta.

## 1. Gospodarz stołu nie musi być jego założycielem

### Oczekiwane działanie

- Właściciel wybiera osobę na liście użytkowników i polecenie
  „Przekaż gospodarza”. Zmiana nie tworzy nowego stołu ani partii.
- Przy zwykłym wyjściu gospodarza jego rolę otrzymuje następny obecny
  gracz-człowiek, w ustalonej kolejności miejsc. Bot nie może być gospodarzem.
- „Wyjdź ze stołu” i „Zamknij stół dla wszystkich” muszą być odrębne.
  Wyjście nie może domyślnie zamykać sesji pozostałym uczestnikom.
- Nowy gospodarz przejmuje zarządzanie stołem, zaproszeniami, ustawieniami,
  rozpoczęciem i zakończeniem partii oraz wszystkimi dotychczasowymi botami.
  Boty zachowują nazwy, miejsca, drużyny, karty, wyniki i ustawienia.
- Jedno zdarzenie w historii i jeden komunikat, np.
  „Peterman zostaje gospodarzem stołu”. Bez powtórzenia po odświeżeniu.

### Przyjęte rozstrzygnięcia

- Ręcznie można przekazać rolę również obecnemu obserwatorowi; nie zmienia
  to automatycznie jego roli w partii.
- Automatycznie pierwszeństwo ma gracz. Jeżeli zostali wyłącznie
  obserwatorzy, rolę otrzymuje pierwszy z nich według kolejności dołączenia.
- Gdy nie zostaje żaden człowiek, stół się zamyka. Nie tworzyć samoczynnego
  zapisu partii pod nieobecnym kontem.
- Prawo do nowego zapisu partii przechodzi na aktualnego gospodarza.
  Wcześniejsze zapisy pozostają na kontach osób, które je utworzyły.

### Warunki bezpiecznego wykonania

Potwierdzono dostępność `Session#transfer_ownership`, `on_owner_changed`
i serwerową flagę `ownership_transfer`. To podstawa przekazania uprawnień,
nie gotowa migracja Game Roomu. Dzisiaj część kodu pamięta gospodarza
z chwili startu, a wyjście właściciela wywołuje zamknięcie sesji.

Przy zwykłym wyjściu najpierw potwierdzić przekazanie na serwerze, dopiero
potem opuścić sesję. Przy niepewnym wyniku odczytać stan, zamiast zakładać
sukces lub powtarzać całą operację. Nagłe zamknięcie procesu, awaria sieci
i zwykłe wyjście to osobne scenariusze: automatycznego następstwa po awarii
nie uznawać za potwierdzone na podstawie samej metody przekazania.
Najpierw sprawdzić, czy serwer zachowuje sesję i wybiera nowego właściciela;
jeżeli nie, ta część wymaga wsparcia ELTEN-a/serwera.

Wspólny transport, repozytorium, wykonawca partii i poczekalnia mają używać
potwierdzonego bieżącego gospodarza. Dotychczasowe zdarzenia trzeba nadal
uznawać według uprawnień obowiązujących w chwili ich wykonania. Nie wystarczy
podmienić nazwiska właściciela: obecna walidacja ruchów botów i części wpisów
stołu jest związana z autorem/gospodarzem. Zachować weryfikowalną historię
zmian uprawnień, bez dopuszczenia dowolnej deklaracji właściciela przez klienta.

Stary wykonawca przestaje sterować botami i automatami; nowy rusza dopiero
po uzgodnieniu stanu. Odrzucać spóźnione decyzje poprzedniego wykonawcy,
nie wykonywać ruchu ani kary za czas dwukrotnie. Nie resetować limitów,
rozdania lub drużyn. Bezpiecznie przekazywać wymagane dane prywatne;
nie publikować sekretów w discovery ani ogólnym komunikacie stołu.

Pong i Audio Ball wymagają osobnej obsługi zmiany koordynatora Communications,
kontrolerów botów, bieżącej wymiany i zapisów wyniku. Zmiana właściciela
Live Sessions sama tego nie załatwia. Zachować bezpośrednią drogę akcji przez
relay; nie przywracać przekazywania każdego ruchu przez gospodarza.

## 2. Bot zajmuje miejsce gracza, a nie dodatkowe miejsce

- Ręczne polecenie gospodarza „Zastąp botem” dla miejsca uczestnika.
- Po doprecyzowaniu użytkownika: automatyczne zastępstwo jest jedynym,
  stałym zachowaniem, bez przełącznika w ustawieniach stołu. Dotyczy gier
  i faz obsługujących bezpieczne zastępstwo.
- Podczas partii bot przejmuje dokładnie to samo miejsce, drużynę, rękę,
  wynik i obowiązki. Nie dostaje nowego rozdania ani dodatkowego miejsca.
- Przed rozpoczęciem gry opcja może zastępować zwolnione miejsce w poczekalni.
- Samo wejście do Wiadomości, utrata pierwszego planu, chwilowy brak danych
  lub utrata strumienia nie oznaczają odejścia. Nie zastępować za to botem.
  Automatyczne zastępstwo dopiero po potwierdzonym opuszczeniu członkostwa.
- Powrót człowieka nie wyrywa sterowania botowi w połowie akcji. Propozycja:
  możliwość przywrócenia mu jego miejsca przez gospodarza w bezpiecznym
  momencie, jako kolejna jawna zmiana kontrolera.
- Zastępstwo i powrót trafiają do historii i komunikatów całego stołu.

W modelu oddzielić stałe miejsce w partii od sterującego nim konta/bota.
Nie przepisywać wstecz całej historii i nie pozorować, że nieobecny człowiek
nadal wysyła akcje. Każda nowa akcja przechodzi dotychczasową walidację zasad
oraz uprawnień bieżącego kontrolera. Ręczne zastąpienie obecnej osoby oznacza
odebranie jej sterowania tym miejscem, nie równoległą grę człowieka i bota.

Samo `supports_bots?` nie wystarczy do uznania każdego stanu za bezpieczny.
Sprawdzić kolejno gry, prywatne odpowiedzi i wybory, fazy jednoczesne,
aukcje oraz gry zręcznościowe. Gdy konkretna gra/faza nie pozwala na takie
przejęcie, podać przyczynę i nie wykonywać pozornego zastępstwa. Nie dodawać
w ramach tej zmiany botów do gier, które ich dotąd nie mają.

## 3. „Ogólne”: język i wspólne ustawienia pracy w tle

Zgodnie z doprecyzowaniem użytkownika wybór języka interfejsu i oba poniższe
przełączniki umieścić w kategorii „Ogólne”. Nie tworzyć osobnej kategorii
„Gra w tle” ani osobnej kategorii wyboru języka. Przeniesienie istniejącego
wyboru języka nie zmienia sposobu zapisywania lub stosowania tego ustawienia.

Dla ustawień pracy w tle rozpoznajemy dwie sytuacje:

1. ELTEN jest na pierwszym planie, ale użytkownik otworzył inną jego część,
   np. Wiadomości, forum lub konferencję, zamiast okna swojego stołu.
2. Ta kopia ELTEN-a nie jest na pierwszym planie, np. użytkownik przeszedł
   do przeglądarki, na pulpit albo do innej kopii ELTEN-a.

Użytkownik doprecyzował: jeden wspólny zestaw ustawień dla obu sytuacji,
bez osobnych przełączników dla innego okna ELTEN-a i innej aplikacji:

- „Odczytuj komunikaty stołu” — domyślnie włączone,
  zachowuje dotychczasową mowę. Wyłączenie wycisza automatyczne odczyty
  zdarzeń i czatu tego stołu, nie syntezę całego ELTEN-a.
- „Sygnalizuj moją turę dźwiękiem” — domyślnie włączone.
  Sygnał działa także przy wyłączonym automatycznym odczycie.

Wystarczy spełnienie któregokolwiek z tych warunków, żeby zastosować
wspólne ustawienia. Gdy zachodzą oba, nadal jest to jedno działanie
w tle — bez podwójnego komunikatu lub dźwięku. Przejście z innego okna
ELTEN-a do innego programu nie rozpoczyna ponownie sygnalizacji tej samej tury.
Własne okna pomocy/zasad/ustawień Game Roomu nie są inną częścią ELTEN-a.
Globalnych powiadomień o nowych stołach i zaproszeń nie zmieniać tym
przełącznikiem; zachowują dotychczasowe osobne ustawienia.

Wyciszenie dotyczy prezentacji, nie odbioru, historii, botów ani zegara gry.
Po powrocie nie odczytywać zaległości hurtowo. Ręczne przeglądanie historii
i odczyty informacji pozostają dostępne. Nie wołać globalnego zatrzymania
mowy, które ucinałoby właśnie czytane Wiadomości lub forum.

Dźwięk pojawia się raz, gdy rzeczywiście zaczyna się moja tura lub moja
wymagana decyzja. Nie przy każdym odświeżeniu, możliwości przechwycenia UNO,
otrzymaniu czatu lub zmianie okna. Dla obserwatora nie ma „mojej tury”.
Respektować wyłączenie dźwięków i ich głośność. Użytkownik zatwierdził
istniejący dźwięk „ding”; bez nowego nagrania.

Wykorzystać wspólną prezentację zdarzeń i tanie, lokalne rozpoznanie aktywnego
okna/wątku. Nie dodawać pętli odpytywania sieci, dysku w obsłudze zdarzenia
ani mowy z workera. Przejście do innej aplikacji Windows trzeba sprawdzić
osobno od przykrycia formularza Wiadomościami. Zachować uzgodnioną pauzę
zręcznościowych gier poza ich aktywnym ekranem; nie uruchamiać tam fizyki
i nie wznawiać sterowania tylko po to, żeby odtworzyć sygnał.

## 4. Zapisane partie dostępne z tego samego konta na innym komputerze

To ponownie zgłoszony cel, a nie potwierdzenie, że nowe Live Sessions
zapewnia trwały magazyn zapisów. Archiwum partii jest już samowystarczalne:
odtworzenie tworzy nowy stół. Zamknięta stara LiveSession nie jest potrzebna.

Docelowo „Zapisane gry” pobiera listę zapisów z konta. Wybranie pozycji
wczytuje archiwum, sprawdza zgodność i odtwarza partię dotychczasową drogą.
Zmiana miejsca przechowywania nie rozszerza automatycznie listy gier lub
faz, które wolno zapisywać. Dane prywatne muszą pozostać prywatne.

Najpierw osobny etap wykonalności magazynu po premierze 3.0.4:

- Sprawdzić aktualne, rzeczywiste limity tabel i zasobów aplikacji oraz
  uprawnienia zwykłych kont. Nie wnioskować z samego numeru wersji klienta.
- Poprzednie próby z 17 września potwierdziły limit 4096 znaków w polu;
  niektóre zwykłe partie nie mieściły się nawet w sprawdzonych trzech polach.
  Wgranie pliku zatrzymał zerowy przydział magazynu zasobów aplikacji.
  Są to wyniki historyczne, nie nowy pomiar na 3.0.4.
- Preferować jeden kompletny obiekt zapisu, jeżeli nowe API i przydział
  faktycznie to umożliwiają. W przeciwnym razie przedstawić do akceptacji
  podział na części w tabeli wraz z manifestem, limitem rozmiaru i kosztami
  żądań. Taki podział nie jest jeszcze zatwierdzony tym planem.
- Przed wdrożeniem potwierdzić dostęp tylko właściciela drugim kontem,
  odczyt na innym profilu/urządzeniu, kompletność, sumę kontrolną,
  ponowienie po niepewnym zapisie i bezpieczne usuwanie własnych zapisów.

Nie zamykać stołu przed potwierdzeniem kompletnego trwałego zapisu.
Brak miejsca lub sieci pozostawia grę otwartą. Zachować wcześniejsze
życzenie: docelowo bez lokalnych kopii awaryjnych. Nie usuwać jednak
dotychczasowych lokalnych zapisów; ewentualny import i późniejsze usunięcie
wymagają osobnego uzgodnienia. Jeżeli magazyn nadal nie jest dostępny,
pozostałe punkty planu mogą zostać wdrożone niezależnie.

Szczegóły wcześniejszych prób: [SAVED_GAME_STORAGE_FEASIBILITY.md](SAVED_GAME_STORAGE_FEASIBILITY.md).

## 5. Prawdziwy stan stołu w dołączaniu i widgecie

- Pokazywać krótko, czy stół oczekuje na graczy, czy trwa partia.
  Przykład w liście wybranej gry: „Papierek, 2/8, oczekuje”.
  W widgecie także nazwa gry: „UNO, Papierek, 2/8, gra trwa”.
- Oddzielić stan partii od publiczności/prywatności oraz możliwości
  dołączenia. „Gra trwa” nie znaczy automatycznie „nie można obserwować”.
- Liczyć faktyczne miejsca graczy wraz z botami. Nie doliczać obserwatorów
  do wyniku 2/8; osobno respektować rzeczywistą pojemność członkostwa
  Live Sessions i serwerową odmowę dołączenia.
- Gospodarz aktualizuje publiczne metadane po zmianie statusu, obsady,
  botów lub gospodarza. Nie po każdym ruchu partii. Nowy gospodarz
  przejmuje ten obowiązek. Prywatnych stołów nie ujawniać.
- Wykorzystać `update_discovery_metadata` i podgląd `DiscoveredSession`,
  w tym możliwość odświeżenia oraz `can_join` i powód odmowy.
  Metadane listy nie zastępują walidacji przy rzeczywistym dołączaniu.
- Zachować ustalony widget: odświeżenie na wejściu, pod R i co 5 sekund
  tylko na nim; nie przy strzałkach. Bez blokującej sieci na wątku UI.
- Przekazanie gospodarza, zmiana statusu lub metadanych nie oznacza
  utworzenia nowego stołu i nie rozsyła nowego powiadomienia subskrybentom.
- Pełny lub zamknięty stół powinien zwracać taki powód, nie ogólne
  „Nie udało się wykonać operacji”.

Ostatnia diagnostyka potwierdziła, że discovery przedstawiało czekającego
jednego gracza, choć stos zawierał rozpoczętą partię człowieka i siedmiu
botów. Faktyczne dołączenie odrzucono jako pełny stół, a aplikacja zgubiła
ten powód. Uwzględnić ten odtworzony przypadek jako regresję.

## Kolejność i kontrola przed wydaniem

Po akceptacji: aktualny kontrakt 3.0.4 i poprawny opis stołu; wspólne
uprawnienia gospodarza; kontrolery i zastępstwa; ustawienia pracy w tle.
Magazyn zapisów jako osobny etap, zależny od potwierdzonych możliwości.

Sprawdzić zwykłe gry, boty, gospodarza-obserwatora, wielokrotne przekazanie,
wyjście w turze bota, równoczesne odejścia, brak odpowiedzi po udanym zapisie,
powrót starego gospodarza, starych uczestników i ponowne odtworzenie historii.
Osobno obie gry Communications, singiel/debel, ludzie/boty i zmiana
koordynatora podczas meczu — bez zmieniania fizyki w celu ukrycia problemu.

Praca w tle: natywne Wiadomości/forum, start z Konferencji, inna aplikacja
Windows, minimalizacja i dwie kopie ELTEN-a. Potwierdzić także mowę/audio,
brak podwójnych sygnałów, niezmienność szkicu/kursora i normalną grę po
powrocie. Testy zapisów i zmiany schematu dopiero po osobnej zgodzie na
konkretne operacje serwerowe. Wyniki zakończonej weryfikacji i jej granice
opisano na początku dokumentu.
