# Rummy — uzgodniony projekt gry

Ostatnia aktualizacja: 17 września 2026.

Status aktualny: użytkownik następnie zlecił wdrożenie. Rummy jest wdrożone
lokalnie i przeszło celowane testy. Wydanie zostało później wstrzymane do
dodania kolejnych gier: bez zmiany wersji, paczki, instalacji i publikacji.
Kontrola wszystkich punktów: `IMPLEMENTATION_2_0_VERIFICATION.md`;
punkt wznowienia: `IMPLEMENTATION_2_0.md`. Sformułowania poniżej o przyszłej
weryfikacji zachowują treść projektu, nie opisują aktualnego stanu prac.

Hasło do wznowienia rozmowy: **rummy**. Ten dokument zawiera pełny,
ujednolicony projekt, nie tylko różnice względem wcześniejszego planu.
Przy następnych uzgodnieniach aktualizować odpowiednie sekcje tutaj, tak aby
nie trzeba było odtwarzać zasad z rozproszonych, sprzecznych wersji rozmowy.
Numeracja 1–17 odpowiada głównym punktom przedstawionego użytkownikowi planu.

Podstawą są przekazane przez użytkownika zasady QuentinC's Playroom (QC),
jego próby w QC, wcześniejsze sprawdzenie publicznych materiałów i świadomie
przyjęte decyzje projektowe. Nie wszystkie szczegóły naszego projektu są
potwierdzoną kopią zachowania QC. Użytkownik zaakceptował proponowane
rozstrzygnięcia, a późniejsze poprawki opisane poniżej mają pierwszeństwo.

## 1. Jedna gra, warianty i formularz ustawień

W głównym wyborze gier pojawia się jedna pozycja Rummy. Eliminacja,
manipulowanie układami i układy identycznych kart nie są oddzielnymi grami.
Warianty są niezależne: można np. połączyć eliminację, tradycyjną punktację,
wielokrotne dobieranie, manipulowanie układami i identyczne karty.

Jedyną listą wyboru w ustawieniach Rummy jest sposób odrzucania kart
(Discard mode). Reguły włącza się polami wyboru z krótkim opisem na kilka
słów. Wartości liczbowe wpisuje się w pola edycyjne. Szczegółowe wyjaśnienia
znajdują się w zasadach, nie w długich etykietach formularza.

| Ustawienie | Kontrolka i krótki opis | Domyślnie |
|---|---|---|
| Sposób odrzucania | Lista: bez odrzucania; odrzucanie bez dobierania; dobieranie jednej; dobieranie wielu | Dobieranie jednej |
| Tryb eliminacyjny | Pole wyboru — „Osiągnięcie limitu eliminuje gracza” | Wyłączone |
| Punktacja co 5 | Pole wyboru — „Uproszczone wartości kart” | Włączone |
| Manipulowanie układami | Pole wyboru — „Zabieranie, dzielenie i łączenie” | Wyłączone |
| Układy identycznych kart | Pole wyboru — „Jednakowe wartości i kolory” | Wyłączone |
| Minimum pierwszego wyłożenia | Pole liczby punktów; zakres 15–90 | 30 |
| Limit punktów | Pole liczby punktów: cel w zwykłym trybie, próg odpadnięcia w eliminacji | 1000 w zwykłym trybie, 500 w eliminacji |
| Czas na turę | Pole liczby sekund; 0 bez limitu, przy włączonym limicie zakres 20–600 | 0 |
| Opóźnienie bota | Wspólne pole liczby sekund; zakres 0–5, 0 wyłącza celową pauzę | Proponowane 0, zgodnie z późniejszym punktem 3 `SAVES_WIDGET_NOTIFICATIONS_PLAN.md` |

Odznaczony tryb eliminacyjny oznacza zwykłą rozgrywkę. Odznaczona punktacja
co 5 oznacza punktację tradycyjną. Nie dodawać oddzielnych list dla tych dwóch
wyborów.

Opcję liczby rozdań usunięto całkowicie, również z warunków końca partii
i rozstrzygania remisów. Nie implementować jej jako ukrytego ustawienia.
Usunięto również możliwość bota wszechwiedzącego: nie ma takiego pola,
wariantu ani ukrytej ścieżki decyzji Rummy.

Prywatność stołu, zaproszenia i obserwatorzy korzystają ze wspólnego
mechanizmu Game Roomu. Nie dublować ich w opcjach samej gry.

## 2. Gracze, talie i rozdanie

Gra dla 2–8 graczy, w dowolnym połączeniu ludzi i zwykłych botów.

- 2–4 graczy: dwie talie.
- 5–6 graczy: trzy talie.
- 7–8 graczy: cztery talie.
- Przy włączonych układach identycznych kart: zawsze cztery talie.

Przyjmujemy dwa jokery na każdą talię 52 kart, czyli odpowiednio 108, 162
lub 216 kart. Jest to przyjęta decyzja projektu, nie wynik pełnej weryfikacji
liczby jokerów we wszystkich konfiguracjach QC.

Każdy otrzymuje 14 kart. Pozostałe tworzą zakryty stos dobierania.
Stos odrzuconych zaczyna się pusty i powstaje z odrzucanych kart.

Kolejność graczy jest stała. Po rozdaniu gracz rozpoczynający przesuwa się
o jedno miejsce, z pomijaniem wyeliminowanych.

Każdy fizyczny egzemplarz karty ma własne stabilne ID. Dwie siódemki pik
to dwie osobne karty, mimo jednakowego odczytu. Jest to istotne dla zaznaczeń,
dobierania, kursora i zachowania liczby kart.

## 3. Przebieg tury

### 3.1. Najpierw dobieranie

Tura zaczyna się jednym dobieraniem:

- jednej karty ze stosu zakrytego;
- albo karty lub pakietu ze stosu odrzuconych, jeśli pozwala na to wariant
  i gracz ma już własne pierwsze wyłożenie.

Pakiet ze stosu odrzuconych jest jednym dobieraniem. Nie dobiera się drugi
raz w tej samej turze. Przed dobraniem nie wolno wykładać, dokładać,
odzyskiwać jokera ani zabierać kart lub układów ze stołu.
Wyjątek: rzeczywisty brak źródła dobierania, opisany w punkcie 11.

### 3.2. Działania na układach

Po dobraniu można wykonać dowolną liczbę legalnych działań: wykładać nowe
układy, dokładać do istniejących, podmieniać joker, a przy odpowiednim
wariancie zabierać karty, rozdzielać i łączyć układy.
Nie kończyć tury automatycznie po jednym wyłożeniu.

### 3.3. Koniec tury lub rozdania

W wariantach ze stosem odrzuconych zwykłą turę kończy odrzucenie jednej
karty. Bez odrzucania służy do tego Shift+F.

Pozbycie się wszystkich kart przez wykładanie lub dokładanie natychmiast
kończy rozdanie. Nie trzeba zachowywać ostatniej karty do odrzucenia.
Kary dotyczące zakończonej tury muszą zostać rozliczone również wtedy,
gdy ostatnia czynność kończy rozdanie.

Przy trzech lub mniej kartach gra automatycznie podaje liczbę kart gracza;
nie ma obowiązku ręcznego zgłaszania. Nie powtarzać odczytu przy samym
odświeżeniu niezmienionego stanu.

## 4. Układy i kolejność wybierania kart

### 4.1. Sekwencje jednego koloru

Sekwencja to co najmniej trzy kolejne karty jednego koloru, np. 5, 6, 7 kier,
walet, dama, król pik, as, 2, 3 trefl albo dama, król, as karo.

- As może być niski albo wysoki.
- Nie zawijamy przez asa: król, as, 2 jest niedozwolone.
- Maksymalna długość sekwencji wynosi 13 kart.
- Nie tworzymy sekwencji z asem jednocześnie na początku i na końcu.

Ważna późniejsza poprawka użytkownika: gracz musi zaznaczać karty
w prawidłowej kolejności układu. Zachowujemy kolejność dodawania do szkicu,
nie porządek indeksów ręki. Program nie sortuje automatycznie wybranego
układu i nie naprawia jego kolejności:

- 3, 4, 5 pik — poprawna sekwencja;
- 3, 5, 4 pik — niepoprawna; zaznaczenia pozostają do poprawienia;
- joker, 3 i 4 pik — joker zajmuje miejsce dwójki;
- 3, 4 pik i joker — joker zajmuje miejsce piątki.

Sortowanie samej ręki nie zmienia kolejności już przygotowanego układu.
Nie wprowadzać dodatkowego pytania o dopasowanie jokera, które wynika
z wybranej kolejności. Szczegóły jego odczytu opisuje punkt 7.

### 4.2. Zestawy tej samej wartości

Trzy lub cztery karty tej samej wartości, różnych kolorów, np. 8 kier,
8 karo i 8 pik. Kolor może wystąpić tylko raz. Dwa egzemplarze 8 pik
nie zastępują dwóch różnych kolorów. Kolejność kolorów w takim zestawie
nie ma znaczenia dla legalności.

### 4.3. Układy identycznych kart

Tylko po włączeniu wariantu: trzy lub cztery fizyczne egzemplarze dokładnie
tej samej karty, np. trzy czwórki pik.

- Długość 3–4 karty.
- Najwyżej jeden joker.
- Co najmniej dwie naturalne identyczne karty.
- Bez układów pięciokartowych.

Użytkownik sprawdził w QC trzy zwykłe identyczne karty i jokera. Dwie
naturalne karty z jokerem oraz ograniczenie do czterech są zaakceptowanym
doprecyzowaniem naszego projektu, nie oddzielnie potwierdzonym testem QC.

## 5. Pierwsze wyłożenie

Każdy gracz osobno musi wejść do gry, wykładając z własnej ręki jeden lub
kilka nowych układów, których łączna wartość osiąga minimum ustawione
dla stołu. Muszą być wyłożone w tej samej turze.

Przy minimum 30 i uproszczonej punktacji można przygotować razem:

- 5, 6, 7 kier — 15 punktów;
- 2, 3, 4 pik — 15 punktów.

Przed własnym pierwszym wyłożeniem nie można:

- dobierać ze stosu odrzuconych;
- dokładać do istniejących układów;
- odzyskiwać jokerów;
- zabierać kart ani całych układów;
- manipulować układami na stole.

Nie można użyć kart zabranych ze stołu do zebrania minimum. Pierwsze
wyłożenie z kilku układów zatwierdza się łącznie: gra nie przyjmuje połowy
za 15 punktów, jeśli obowiązuje minimum 30.

Po zaakceptowaniu pierwszego wyłożenia pozostałe działania są dostępne
jeszcze w tej samej turze. Nie daje to prawa do ponownego dobierania ze
stosu odrzuconych — dobieranie tej tury już się odbyło.

Status pierwszego wyłożenia jest indywidualny i zeruje się w nowym rozdaniu.
Obowiązuje również w eliminacji, chociaż same wyłożenia nie zwiększają tam
wyniku punktowego.

## 6. Cztery warianty stosu odrzuconych

### 6.1. Bez odrzucania

Gracz dobiera ze stosu zakrytego, wykonuje działania i kończy turę Shift+F,
bez oddawania karty na stos odrzuconych.

### 6.2. Odrzucanie bez dobierania

Na końcu tury odrzuca się kartę, ale nie wolno dobierać z tego stosu.
Karty wracają do obiegu dopiero po wyczerpaniu stosu zakrytego
i przetasowaniu odrzutów.

### 6.3. Dobieranie jednej karty

Zamiast zakrytej karty można wziąć wierzchnią odrzuconą kartę.
Zgodnie z obserwacją użytkownika wolno ją zachować w ręce. Nie wymagać
natychmiastowego wyłożenia mimo niejednoznacznego zdania w opisie QC.

### 6.4. Dobieranie wielu kart

Wybrana karta jest dobierana razem ze wszystkimi kartami nad nią. Nie można
wyjąć jednej głębszej karty z pominięciem nowszych odrzutów. Wszystkie dobrane
karty można zachować w ręce; nie ma obowiązku natychmiastowego wyłożenia.

Przykładowy stos od góry:

1. Dama kier.
2. 7 pik.
3. 4 trefl.

Enter na 4 trefl dobiera wszystkie trzy, na 7 pik — dwie górne.
Ograniczenie własnego pierwszego wyłożenia pozostaje w mocy.

Ważna późniejsza poprawka interfejsu: lista Shift+D zawiera wyłącznie
nazwy kart, od najnowszej odrzuconej u góry do najstarszej na dole.
Bez dopisków „dobierzesz 3 karty” i bez dodatkowych potwierdzeń. Liczba
dobieranych kart wynika z wybranej głębokości i zasad. Ta zmiana dotyczy
opisu listy wyboru, nie usuwa zwykłego zdarzenia dobrania kart w historii.

## 7. Jokery: miejsce, odczyt i odzyskanie

Joker może zastąpić brakującą kartę w nowym układzie. Najwyżej jeden joker
na układ. Nie dokłada się samego jokera do istniejącego układu jako zwykłego
przedłużenia. Przy manipulacji możliwe jest zabranie dozwolonego układu
bez jokera i zbudowanie z niego nowego układu z jokerem.

### 7.1. Odczyt i miejsce jokera

Joker jest jawnie odczytywany wszędzie, gdzie prezentujemy karty układu.
Nie odczytywać go jako zwykłej zastępowanej karty ani nie ukrywać jego
obecności. Krótki opis układu również sygnalizuje, że zawiera joker.

Przykład dokładnie zgodny z poprawką użytkownika: „joker, 3 i 4 pik”.
Nie dopisywać „joker zastępujący dwójkę pik”, „joker jako dwójka” ani
analogicznego dodatkowego wyjaśnienia. Odczyt zachowuje pozycję jokera;
znaczenie wynika z układu. Na ręce samodzielna karta nadal nazywa się joker.

Kolejność zaznaczania określa dopasowanie w sekwencji. Nie przesuwać jokera
automatycznie na inny koniec i nie otwierać osobnego wyboru jego wartości,
jeżeli wynika ona z tej kolejności.

Zestaw wartości może nadal pozostawiać niejednoznaczność koloru jokera.
Nie wymyślać brakującego koloru tylko dlatego, że zaznaczono joker pierwszy
lub ostatni.

### 7.2. Podmiana naturalną kartą z ręki

Po dobraniu i własnym pierwszym wyłożeniu można zastąpić joker właściwą
naturalną kartą. Odzyskiwanie działa także przy wyłączonym manipulowaniu.

Nie ma pozycji „Odzyskaj jokera” w menu kontekstowym stołu. Gracz wskazuje
naturalną kartę w ręce, naciska Enter i wybiera pasujący układ. Jeśli
podmiana jest jednoznaczna, karta zastępuje joker, a joker trafia do ręki.
Nie wymaga to oddzielnego polecenia odzyskania.

Przykład: w dama pik, król pik, joker naturalny as pik zastępuje joker.

Przy dwóch siódemkach różnych kolorów i jokerze trzecia siódemka nie odzyskuje
jokera, bo nadal istnieją dwa możliwe brakujące kolory. Trzecia naturalna
siódemka rozszerza zestaw. Dopiero czwarty brakujący kolor zastępuje joker.

Odzyskany joker może być użyty w nowym układzie w tej samej turze. Można też
go zachować i zapłacić jednorazową karę 300 przy zakończeniu tury. Nie blokować
końca tury z powodu niewyłożonego jokera. Po rozliczeniu jest zwykłą kartą
w ręce, bez powtarzania starej kary.

### 7.3. Cały układ z jokerem

Przyjęta reguła projektu: najpierw trzeba odzyskać joker przez zwykłą podmianę,
a dopiero później można zabrać cały pozostały układ. Nie uwalniać jokera przez
samo zabranie całego układu.

To zaakceptowane wyjaśnienie pasujące do obserwacji użytkownika, nie w pełni
potwierdzona uniwersalna reguła QC. Nie wyklucza ono zabrania dozwolonej
naturalnej karty, jeżeli pozostały układ z jokerem nadal jest poprawny.
Joker pozostający na stole nie może być swobodnie przedefiniowywany przez
manipulację zamiast normalnej podmiany.

## 8. Manipulowanie układami i kary za zachowane karty

Wariant opcjonalny, dostępny po dobraniu i własnym pierwszym wyłożeniu.
Układy na stole są wspólne: nie ma znaczenia, kto je wcześniej wyłożył.

### 8.1. Pojedyncze karty

Z sekwencji można zabrać naturalną kartę z końca, jeśli zostają co najmniej
trzy karty poprawnej sekwencji. Nie wyjmować pojedynczej karty ze środka,
pozostawiając dziurę.

Z zestawu czterech kart można zabrać dozwoloną kartę, pozostawiając poprawny
zestaw trzech. Te same kontrole poprawności dotyczą układów identycznych.

Przykład: na stole 4, 5, 6, 7 karo, w ręce 4 kier i 4 trefl. Gracz zabiera
4 karo i może wyłożyć trzy czwórki. Pozostałe 5, 6, 7 karo nadal są legalne.

### 8.2. Cały układ

Można zabrać cały dozwolony układ bez jokera, także trzykartowy. To jedna
czynność, bez konieczności rozbierania go karta po karcie. Karty trafiają
rzeczywiście do ręki. Można wykorzystać je w innych układach albo zatrzymać
z karą opisaną poniżej.

### 8.3. Łączenie i rozdzielanie

Merge, czyli „Połącz układy”, pozwala wskazać drugi pasujący układ. Wynik
musi spełniać zasady, w tym długość, kolory, fizyczne egzemplarze i ograniczenia
jokera.

Nie ma osobnej pozycji „Rozdziel układ”. Rozdzielenie można wykonać przez
zabranie całego dozwolonego układu i przygotowanie nowych.

Przykład: z 6, 7, 8, 9, 10 pik oraz dodatkowej 8 pik z ręki można uzyskać
6, 7, 8 i 8, 9, 10 pik. Muszą istnieć dwa fizyczne egzemplarze ósemki.
Jeżeli zabierany układ zawiera joker, najpierw obowiązuje jego zwykła podmiana.

Nie wysyłać na stół niepoprawnych dwukartowych resztek ani przejściowych
układów z dziurą. Całe układy można zabrać do ręki; nowo wykładane muszą być
poprawne. Przygotowanie kilku nowych układów jest prywatnym szkicem do
łącznego zatwierdzenia.

### 8.4. Zwrot nie jest warunkiem zakończenia tury

Ważna późniejsza korekta użytkownika: nie mówić, że wszystkie zabrane karty
„muszą wrócić przed końcem tury” jako twardy warunek wykonania ruchu.
Wolno zakończyć turę, zachowując je w ręce. Za każdą niewyłożoną kartę
zabraną w tej turze nalicza się jednorazowo 300 punktów kary:

- zwykły tryb: minus 300;
- eliminacja: plus 300.

Dwie takie karty oznaczają 600. Dotyczy to także odzyskanych jokerów.
Zachowane karty pozostają w ręce, po rozliczeniu stają się zwykłymi kartami
i ta sama kara nie wraca w kolejnych turach. Jeśli później zostaną ponownie
wyłożone i na nowo zabrane, jest to już nowe zdarzenie, a nie stary dług.

Nie blokować końca tury, gdy w ręce zostały wyłącznie zabrane karty albo
odzyskany joker. Przy kończeniu przez odrzut można odrzucić taką kartę,
ale odrzucenie nie jest zwrotem do układu i nie kasuje kary 300. Karty
nieodrzucone i niewyłożone zostają w ręce. Kara jest rozliczana również wtedy,
gdy ostatni odrzut opróżnia rękę i kończy rozdanie.

Przy nierozróżnialnych egzemplarzach poprawne wyłożenie równoważnej karty
rozlicza jeden odpowiadający jej obowiązek. Nie karać za wybór „innego”
identycznego jokera lub identycznej karty, zachowując zarazem tożsamość
fizycznych kart i ich liczbę.

Samo anulowanie niewysłanego szkicu nie cofa rzeczywistego zabrania kart.
Rozliczenie wartości punktowej zabieranych kart w zwykłym trybie jest
odrębne od kary 300 — patrz punkt 10.

## 9. Wartości kart

| Karta | Uproszczona punktacja co 5 | Tradycyjna punktacja |
|---|---:|---:|
| 2–9 | po 5 | wartość karty |
| 10, walet, dama, król | 10 | 10 |
| As przed dwójką | 5 | 1 |
| As po królu lub w zestawie asów | 15 | 11 |
| As pozostały w ręce | 15 | 11 |
| Joker wyłożony | wartość zastępowanej karty | wartość zastępowanej karty |
| Joker pozostały w ręce | 20 | 20 |

Zgodnie z ustaleniem as w ręce ma tę samą wartość co as wysoki. Niski as
zachowuje niższą wartość. „Punktacja co 5” oznacza powyższą tabelę,
nie dowolne matematyczne zaokrąglenie sumy.

Układy identycznych kart mają szczególną wartość wyłożonych kart:

| Karta w identycznym układzie | Uproszczona | Tradycyjna |
|---|---:|---:|
| 2–9 | 15 za kartę | wartość karty + 10 |
| 10–król | 20 | 20 |
| As | 25 | 21 |

Joker w takim układzie ma wartość zastępowanej identycznej karty. Premia
za identyczny układ nie zwiększa wartości niewyłożonych kart w ręce.

Przykład z rozmowy: 3, 4 pik i joker daje 15 punktów przy uproszczonej
punktacji, bo każda z trzech kart jest warta 5. Przy tradycyjnej punktacji
i jokerze na miejscu piątki daje 3 + 4 + 5 = 12. Sam wynik 15 w QC nie dowodził
wartości przypisanej jokerowi, bo także dwójka jest tam warta 5 w tym trybie.

## 10. Punktacja, premie, eliminacja i koniec partii

### 10.1. Zwykły tryb

Gracz dostaje punkty na bieżąco za wykładane i dokładane karty.
Przy zabieraniu kart ze stołu ich dotychczasowa wartość jest odejmowana
od wyniku zabierającego, nie od pierwotnego autora układu. Ponowne wyłożenie
nalicza wartość w nowym miejscu. Podmiana i odzyskanie jokera muszą zachować
tę samą zasadę rozliczenia rzeczywiście nowych kart.

Przełożenie tej samej karty o niezmienionej wartości nie produkuje punktów.
Przeniesienie wysokiego asa do niskiej sekwencji może zmniejszyć wynik.
Zabranie czwórki i dołożenie do dwóch własnych czwórek daje w uproszczonym
trybie zysk za dwie nowe karty, a nie za wszystkie trzy.

Zwycięzca rozdania dostaje dodatkowo sumę wartości kart pozostałych w rękach
przeciwników. Pozostali zachowują wcześniej zdobyte punkty; nie odejmować
im automatycznie całej ręki.

Premie:

- zakończenie, zanim ktokolwiek inny zrobił pierwsze wyłożenie: +100;
- pierwsze wyłożenie i opróżnienie ręki w tej samej turze, czyli rummy: +200;
- takie rummy wyłącznie nowymi układami z własnej ręki, bez dokładania
  do stołu i korzystania z zabranych układów: +300 zamiast +200;
- premia +100 łączy się z odpowiednią premią rummy, dając +300 albo +400.

Obowiązkowe dobranie na początku tury nie wyklucza rummy. Przygotowanie
kilku układów w szkicu nie zmienia definicji rummy ani chwili faktycznego
pierwszego wyłożenia.

### 10.2. Eliminacja

Mniej punktów oznacza lepiej. Wyłożenia i dokładanie nie dają punktów,
ale ich wartość nadal służy do sprawdzania pierwszego wyłożenia.

- Zwycięzca dostaje 0 za rozdanie.
- Pozostali dostają punkty za własne pozostałe karty.
- Rummy mnoży punkty przeciwników za rękę przez 2.
- Rummy wyłącznie własnymi nowymi układami mnoży je przez 3.
- Takie rummy, zanim ktokolwiek inny się wyłożył, mnoży je przez 4.

Stosować jeden właściwy mnożnik, nie iloczyn 2 × 3 × 4. Mnożnik nie obejmuje
wcześniejszych kar 50 ani 300. Wygranie rozdania nie kasuje kar naliczonych
już zwycięzcy.

Świadoma decyzja projektu: nie dodajemy opisanej na forum QC szczególnej
premii minus 100 i dodatkowego podwajania za zwykłe zakończenie przed wejściem
pozostałych. Użytkownik zaakceptował projekt z zerem dla zwycięzcy i powyższymi
mnożnikami rummy. Nie przywracać tego wyjątku jako rzekomo pominiętej poprawki
bez kolejnego uzgodnienia.

### 10.3. Progi, remisy i dalsze rozdania

Próg sprawdza się dopiero po pełnym rozliczeniu rozdania, wraz z premiami
i karami. Nie kończyć partii po chwilowym przekroczeniu progu w środku tury.

W zwykłym trybie po osiągnięciu limitu wygrywa najwyższy końcowy wynik,
nie osoba, która przekroczyła próg pierwsza. Przy remisie najwyższych
wyników gra trwa dalej. Po usunięciu limitu rozdań nie ma wyjątku kończącego
taki remis po z góry określonej liczbie rozdań.

W eliminacji odpadają osoby, które osiągnęły lub przekroczyły limit.
Pozostali grają dalej, do wyłonienia ostatniej osoby. Wyeliminowani nie są
dalej rozdającymi lub wykonującymi tury uczestnikami partii; korzystają
z istniejącej obsługi obserwowania.

Jeżeli wszyscy pozostali jednocześnie przekroczą próg, wygrywa najniższy
wynik; remis najniższych wyników daje wspólne zwycięstwo. Jest to przyjęte
rozstrzygnięcie naszego projektu.

## 11. Czas na turę i zablokowane rozdanie

### 11.1. Upływ czasu

Zgodnie z próbami użytkownika:

- zwykły tryb: kara minus 50;
- eliminacja: kara plus 50;
- jeśli gracz jeszcze nie dobrał w tej turze, dobiera automatycznie jedną
  kartę ze stosu zakrytego, o ile można ją rzeczywiście uzyskać;
- jeśli już dobrał, nie dobiera drugi raz;
- kolejka natychmiast przechodzi do następnego gracza;
- program nie wybiera człowiekowi losowej karty do odrzucenia.

Kary za niewyłożone karty zabrane ze stołu dochodzą osobno. Przekroczenie
czasu i zachowanie dwóch zabranych kart oznacza 50 + 300 + 300 = 650 kary.
Po rozliczeniu karty pozostają w ręce jako zwykłe.

Czas dotyczy całej tury. Otwieranie list, budowanie szkicu i kolejne działania
nie uruchamiają zegara ponownie. Nie dodawać automatycznych komunikatów
odliczających każdą sekundę. Upływ czasu unieważnia niewysłany szkic; same
prywatne zaznaczenia nie są wyłożeniem. Kara 300 dotyczy rzeczywiście
zabranych i niezwróconych kart, nie zwykłych kart zaznaczonych w szkicu.

Rozstrzygnięcie czasu musi być spójne w odtwarzaniu partii i odporne na
ponowienie tego samego zdarzenia. Nie naliczać ponownie kary wskutek
odświeżenia lub różnicy zegarów klientów.

### 11.2. Wyczerpanie stosu i blokada

W wariantach z odrzucaniem przetasowuje się dostępne odrzuty do nowego
zakrytego stosu, pozostawiając ostatnią odrzuconą kartę na wierzchu odrzutów.

Jeśli rzeczywiście nie ma skąd dobrać, wolno wykonać pozostałe legalne
działania bez dobierania. Nie nakazywać dobrania nieistniejącej karty.

Przyjęty warunek blokady: dwa pełne obiegi aktywnych graczy bez rzeczywistego
postępu przy niemożliwym dobieraniu. Użycie nowych kart z ręki lub wznowienie
dobierania jest postępem; samo zabieranie i odkładanie tych samych kart
nie może bez końca odnawiać licznika. Dokładna granica dwóch obiegów jest
zaakceptowanym doprecyzowaniem projektu, nie wynikiem próby użytkownika.

Rozliczenie zablokowanego rozdania:

- zwykły tryb: pozostają zdobyte punkty i kary, bez zwycięzcy i premii
  za zakończenie; odpowiada to obserwacji użytkownika;
- eliminacja: każdy dostaje punkty za własną rękę, bez mnożników rummy;
  jest to przyjęte rozstrzygnięcie, nie oddzielnie potwierdzona próba QC;
- następnie sprawdza się limity i ewentualnie zaczyna kolejne rozdanie.

## 12. Ręka, Enter, odrzucanie i przygotowanie nowych układów

Podstawą jest wspólna kontrolka ręki Game Roomu, wraz z czatem, historią
i użytkownikami. Nie tworzyć odrębnego sposobu obsługi całej aplikacji.

### 12.1. Zwykła ręka

Strzałki przeglądają karty. Spacja dobiera z zakrytego stosu.
N rozpoczyna przygotowanie nowych układów.

Późniejsza poprawka użytkownika ustala działanie Entera:

- Jeśli karta pasuje do istniejących układów, Enter otwiera ich wybór.
  Nie dokłada karty automatycznie, nawet jeśli pasuje tylko do jednego.
- Jeśli nie pasuje do żadnego układu, Enter pokazuje „Odrzuć” i „Anuluj”.
- Delete odrzuca wskazaną kartę bez dodatkowego wyboru, również wtedy,
  gdy dałoby się ją dołożyć do układu.
- Anulowanie lub Escape zachowuje kursor na tej samej karcie.

Enter i Delete nie omijają warunków legalności: odrzucanie jest dostępne
we własnej turze, po dobraniu i w wariancie z odrzutem. Nie pokazywać
pozornie dostępnego odrzucania przed dobraniem lub poza swoją turą.

Podmiana jokera odbywa się tą samą drogą: naturalna karta, Enter, wybór
pasującego układu. Bez osobnego polecenia „Odzyskaj jokera”.

### 12.2. Szkic nowych układów

1. N rozpoczyna przygotowanie.
2. Strzałki poruszają się po ręce.
3. Enter zaznacza lub odznacza kartę. W tym trybie nie otwiera odrzucania.
4. Kolejność dodawania kart do szkicu jest kolejnością układu, także jokera.
5. Ponowne N odkłada poprawny bieżący układ do prywatnego szkicu i pozwala
   przygotować następny.
6. F zatwierdza wszystkie przygotowane układy razem, uwzględniając aktualnie
   zaznaczony.
7. P odczytuje przygotowane układy, sumę i ewentualny brak do pierwszego
   wyłożenia.
8. Shift+P otwiera listę szkiców do poprawienia albo usunięcia.
9. Escape anuluje niewysłany szkic, nie wychodzi od razu z pokoju.

Za mała suma pierwszego wyłożenia lub niepoprawny układ nie kasują
zaznaczeń. Przykład: „Przygotowano 25 punktów. Do pierwszego wyłożenia
brakuje 5”. Gracz może poprawić wybór i kolejność; program nie sortuje go
samodzielnie.

Jedna fizyczna karta nie może wystąpić w dwóch przygotowanych grupach.
Przed przyjęciem całej akcji przygotowane karty nadal należą do ręki,
a szkic jest tylko lokalny. Nie publikować każdego zaznaczenia w sieci.

Anulowanie szkicu nie cofa żadnej wcześniejszej przyjętej akcji na stole,
w szczególności nie oddaje automatycznie zabranych kart i nie kasuje ich
ewentualnej kary. Odrzucenie lub inne działanie nie może po cichu zatwierdzić
niedokończonego szkicu.

## 13. Lista stołu, uproszczone menu i skróty

### 13.1. C — układy na stole

C otwiera jedną listę przeglądaną strzałkami, np.:

- „Układ 1. Kier, od 4 do 8. Pięć kart.”
- „Układ 2. Trzy króle, w tym joker.”
- „Układ 3. Cztery identyczne szóstki pik.”

Enter otwiera szczegóły. W szczegółach odczytywane są faktyczne karty
w kolejności układu, z jawnym jokerem, np. „joker, 3 i 4 pik”.

Po poprawce użytkownika menu kontekstowe konkretnego układu zawiera tylko:

- „Połącz układy” (merge) — wybór drugiego pasującego układu;
- „Zabierz cały układ”;
- kolejne pozycje „Zabierz [nazwa konkretnej karty]”, po jednej dla każdej
  karty, którą aktualnie wolno zabrać.

Dla sekwencji 4–8 pik będą to np. „Zabierz 4 pik” i „Zabierz 8 pik”,
a nie ogólne „zabierz kartę z początku lub końca”.

Nie ma tu „Dołóż kartę”, „Odzyskaj jokera”, ogólnego „Zabierz wybraną kartę”
ani osobnego „Rozdziel układ”. Dokładanie i podmiana są już dostępne z ręki.
Rozdzielanie odbywa się przez zabranie układu i przygotowanie nowych.

Pokazywać wyłącznie operacje rzeczywiście dozwolone w bieżącej fazie,
wariancie i układzie. Brak jokera lub obecność jokera, liczba kart, własne
pierwsze wyłożenie i dobieranie nie są sprawdzane wyłącznie przez menu:
takie same warunki obowiązują w walidacji akcji.

### 13.2. D i Shift+D — stos odrzuconych

D wyłącznie odczytuje dostępne odrzuty, bez otwierania listy i zmiany
fokusu. W single discard oraz odrzucaniu bez dobierania odczytuje tylko
wierzchnią kartę; w multiple discard cały dostępny stos od najnowszej.
Starsze karty nadal mogą pozostawać w stanie partii do ponownego tasowania,
ale nie są widoczne w wariancie pojedynczego odrzutu.
Shift+D służy dobieraniu: przy jednej legalnej możliwości od razu dobiera
kartę, także gdy tylko jedna pozostała w wariancie wielokrotnym. Dopiero
kilka dostępnych możliwości otwiera listę wyboru głębokości.
Lista ma wyłącznie nazwy kart, najnowsza na górze, starsze niżej.
Nie dodawać liczb „dobierzesz N” ani dodatkowego potwierdzenia wybranej
głębokości. Enter dobiera zgodnie z zasadami wariantu.

### 13.3. Zestawienie skrótów

| Skrót | Działanie |
|---|---|
| Strzałki | Przeglądanie bieżącej listy |
| Spacja | Dobranie ze stosu zakrytego |
| Enter w zwykłej ręce | Wybór pasującego układu; przy braku celu „Odrzuć” i „Anuluj” |
| Delete w zwykłej ręce | Natychmiastowe odrzucenie i koniec tury, jeśli dozwolone |
| Shift+F | Koniec tury w wariancie bez odrzucania |
| N | Przygotowanie nowego układu; podczas przygotowania przejście do następnego |
| Enter podczas przygotowania | Zaznaczenie lub odznaczenie karty |
| F podczas przygotowania | Zatwierdzenie przygotowanych układów |
| P | Podsumowanie przygotowania |
| Shift+P | Poprawianie przygotowanych układów |
| C | Lista układów na stole |
| D | Odczyt dostępnego stosu odrzuconych bez listy; w single tylko wierzchnia karta |
| Shift+D | Natychmiastowe dobranie przy jednej możliwości; przy kilku lista głębokości |
| E | Krótkie liczby kart graczy |
| S | Wyniki |
| T | Czyja tura |
| Shift+C | Sortowanie ręki według koloru, przełączanie kierunku |
| Shift+H | Sortowanie ręki według wartości, przełączanie kierunku |
| Shift+M | Powrót do kolejności otrzymywania kart |
| Z / Shift+Z | Następna/poprzednia karta do natychmiastowego legalnego dołożenia |
| Ctrl+R | Obecny wariant i ustawienia, istniejący wspólny mechanizm |
| Ctrl+F1 | Zasady, skróty i ustawienia stołu |
| F1 | Aktualna pomoc jako lista |
| Ctrl+S | Zapis partii w dozwolonym momencie |

Nie dodawać zwykłego R jako drugiego skrótu do reguł. F1, głośność F2/F3
i Shift+F2/F3, czat oraz nawigacja historii pozostają we wspólnym szkielecie.
Litery gry nie przechwytują tekstu w edytowalnym czacie.

Z/Shift+Z to pomoc w bezpośrednim dołożeniu, nie automatyczny rozwiązywacz
ręki. Nie znajduje najlepszego kompletu kilku kart. Automatyczny ruch
dopuszcza wyłącznie jedną grywalną fizyczną kartę i jedno jednoznaczne
działanie, bez wyboru celu, podmiany jokera lub alternatywy wymagającej
przygotowania układu. Podczas budowania szkicu automat nie działa.
Nie utożsamiać wyjątkowego automatu Z z Enterem: Enter zgodnie z poprawką
użytkownika pokazuje wybór także przy jednym pasującym układzie.

## 14. Kursor, komunikaty i dźwięki

### 14.1. Wspólne zachowanie ręki

- Po zagraniu kursor trafia na poprzednią pozostałą kartę; jeśli jej nie ma,
  na następną.
- Przy zagraniu kilku kart stosuje się tę samą zasadę do pozostałej ręki.
- Po dobraniu jednej lub wielu kart wskazana jest ostatnia faktycznie
  otrzymana karta.
- Bez sortowania nowe karty trafiają na dół, z sortowaniem na właściwe
  miejsca, ale kursor śledzi fizyczną kartę, nie dawny indeks.
- Odczytuje się kartę pod kursorem, bez powtarzania „Twoja ręka”.
- Ruch przeciwnika lub aktualizacja niezmienionej ręki nie przesuwa kursora.
- Aktualizacje nie wyciągają użytkownika z czatu lub historii i nie
  odbudowują całego formularza.

Korzystać z istniejącej obsługi stabilnych ID, `hand_order` i `hand_epoch`,
opisanej w `CARD_HAND_CURSOR_213.md`. Nie zmieniać przy okazji zachowania
innych list, plansz, kości i pozostałych gier.

### 14.2. Komunikaty

Komunikaty mówią jasno, kto i co zrobił. Przykłady:

- „Papierek wykłada 5, 6, 7 kier.”
- „Peterman dokłada 8 kier.”
- „Papierek odzyskuje jokera.”
- „Peterman dobiera 3 karty ze stosu odrzuconych.”
- „Papierek ma 2 karty.”
- „Upłynął czas Petermana. 50 punktów kary.”

Odczyt kart zawsze zachowuje jawnego jokera. Usunięcie pozycji menu
„Odzyskaj jokera” nie usuwa informacji o faktycznie wykonanej podmianie.
Usunięcie dopisku liczby kart pod Shift+D nie usuwa informacji o zdarzeniu
dobrania w historii.

Po rozdaniu osobno podać zwycięzcę, premie lub mnożnik, rozliczenie punktów
oraz ewentualne odpadnięcie lub wygranie całej partii. Nie mieszać wyniku
rozdania z wynikiem całej gry.

Nie ogłaszać zawartości kart dobieranych przez przeciwnika ze stosu zakrytego.
Nie powtarzać całego stołu po każdym ruchu i nie powielać komunikatów
wskutek technicznego odświeżenia.

### 14.3. Dźwięki

Wykorzystać istniejące dźwięki dobierania, zagrywania, tasowania i wyników.
Podlegają wspólnej regulacji głośności Game Roomu. Nie zmieniać głośności
mowy lub ELTEN-a i nie przywracać zakazu nakładania się dźwięków.
Nie dodawać dźwięku przy każdym odświeżeniu stanu.

## 15. Boty — wyłącznie zwykłe

Boty korzystają tylko z własnej ręki i informacji publicznych: układów,
odrzutów, liczby kart graczy oraz jawnego przebiegu gry. Nie znają cudzych
rąk ani przyszłej kolejności zakrytego stosu. Nie ma wariantu wszechwiedzy.

### 15.1. Planowanie ręki

Planer rozważa kilka podziałów ręki na rozłączne układy, zamiast wybierać
pierwszą znalezioną trójkę. Nie zużywa jednej karty w dwóch planach.
Uwzględnia próg pierwszego wyłożenia z wielu grup, różne użycie jokerów,
układy identyczne i istniejące możliwości dokładania.

Nie powinien wykładać trzech siódemek, jeśli niepotrzebnie rozbija tym dwie
znacznie korzystniejsze sekwencje. Akcje bota zawierają prawidłową kolejność
kart, tak samo jak akcje człowieka.

### 15.2. Dobieranie i odrzucanie

Przy wielokrotnym dobieraniu ocenia cały obowiązkowy pakiet. Nie bierze
wielu niepotrzebnych kart dla drobnej korzyści z jednej głębszej.

Przy odrzucaniu uwzględnia przydatność karty we własnych układach, wartość
pozostałej ręki, publiczne wskazówki o potrzebach przeciwników oraz ryzyko
umożliwienia komuś zakończenia. Wnioskowanie z jawnych ruchów jest dozwolone;
odczytywanie ukrytych rąk z pełnego stanu gry nie jest.

### 15.3. Cel strategiczny

Zwykły tryb: uwzględnia punkty i premie rummy, ale nie czeka bezmyślnie
na wielką premię, gdy przeciwnik może zaraz zakończyć. Eliminacja: mocniej
ogranicza ryzyko pozostania z drogimi kartami.

Rozpoznaje możliwość wygrania całej partii, zamiast przedłużać ją dla
niepotrzebnych dodatkowych punktów. Odróżnia ryzykowną sensowną decyzję,
która się nie udała, od oczywistego błędu strategicznego.

### 15.4. Manipulowanie

Najpierw przygotowuje pełny legalny plan wykorzystania zabranych kart,
a dopiero potem je zabiera. Powinien unikać odzyskiwania jokera bez sposobu
wyłożenia, niepotrzebnych kar 300, zapętlonego przekładania i mylenia
ponownego naliczenia zabranej karty z rzeczywistym zyskiem.

Możliwość zachowania karty z karą pozostaje legalna także dla bota, ale nie
jest domyślną strategią ratowania źle przygotowanego planu.

### 15.5. Koszt obliczeń i wykonanie

Planowanie ma ograniczony koszt i prostszy legalny ruch awaryjny.
Nie zakłada setek symulowanych partii na każdy ruch. Potrzebne będą pomiary
kosztu na rzeczywistym kodzie; nie obiecywać idealnej gry ani całkowitego
braku opóźnień bez tych pomiarów.

Opóźnienie 0–5 sekund stosuje się przed rozpoczęciem ruchu bota, nie przed
każdą kartą z jednego planu; 0 wyłącza celową pauzę. Zakres zastępuje
wcześniejsze 1–5 zgodnie ze wspólnym planem poprawek. Oczekiwanie nie
blokuje UI ani aktualizacji.
Po zmianie stanu plan jest ponownie sprawdzany, a bot wykonuje działania
tą samą ścieżką akcji co człowiek, bez omijania walidacji.

## 16. Zapis, synchronizacja, pomoc i integracja

Rummy używa obecnych stołów, historii, czatu, obserwatorów i odtwarzania
zdarzeń. Nie tworzyć nowego transportu, własnych pętli UI ani okresowego
odpytywania tylko dla tej gry. Zaznaczanie i przesuwanie strzałkami są lokalne.

Każdy faktyczny ruch jest walidowany przy przyjęciu. Ukrycie pozycji menu
nie zastępuje kontroli zasad. Korzystać z `action_for`, `GameRepository`
i standardowego replaya. Zdarzenia powinny przesyłać zwarte identyfikatory
kart i działań; sprawdzić limit wielkości wartości, nie kopiować całej ręki
lub długich opisów do pojedynczego ruchu.

Zapis musi zachować ręce, stosy, układy, pozycje i dopasowania jokerów,
wyniki, ustawienia, pierwsze wyłożenia, kolejność graczy, stan tury i dane
potrzebne do kontynuacji. Nie tasować ponownie zapisanej partii.

Przyjęta bezpieczna faza zapisu: początek tury, przed dobraniem, bez
niedokończonego szkicu i nierozliczonych zabranych kart. Nie traktować takiej
fazy jako automatycznie osiągniętej, gdy zapis zgłoszono w innym momencie.

Ctrl+S korzysta ze wspólnego mechanizmu i jest dostępne założycielowi.
Najpierw potwierdzony zapis na dysku, dopiero potem zamknięcie stołu.
Wznowienie korzysta z istniejącej obsługi pierwotnych graczy i botów.
Nie rozszerzać zapisów na inne gry przy okazji Rummy.

Pomoc i tłumaczenia:

- F1: wspólna dynamiczna lista, bez duplikatów i pozycji niepasujących
  do aktualnej fazy; te same definicje co faktycznie działające skróty.
- Ctrl+R: istniejący wspólny odczyt wariantu i aktywnych ustawień.
- Ctrl+F1: zasady, skróty klawiszowe oraz w pokoju ustawienia tego stołu.
- Każdy dokument zasad jest jednym tekstem z nagłówkami, nie wieloma
  osobnymi sekcjami formularza.
- Interfejs, komunikaty, pomoc i zasady po polsku i angielsku.

Przed późniejszym wdrożeniem stosować aktualne wskazówki
`ADDING_A_GAME.md`, `ARCHITECTURE.md`, `CARD_HAND_CURSOR_213.md`,
`GAME_RULES_209.md`, `VOLUME_AND_HELP_224.md` i `IMPLEMENTATION_AFTER_225.md`.
Ten projekt nie jest poleceniem modyfikowania źródeł hosta ELTEN.

## 17. Plan przyszłej weryfikacji i wydania

To lista prac po osobnym sygnale wdrożenia. W ramach samego zapisania
projektu nie wykonywano testów gry ani budowania paczki.

Regresje zasad i stanu:

- 2–8 graczy, liczba talii, jokerów, rozdanych i wszystkich fizycznych kart;
- wszystkie cztery warianty odrzucania;
- wielokrotne dobieranie dokładnie do wskazanej głębokości, bez wymogu
  natychmiastowego zagrania;
- próg pierwszego wyłożenia z wielu układów i blokady działań przed nim;
- kolejność dobieranie–wykładanie–odrzut oraz brak drugiego dobierania;
- poprawna kolejność zaznaczeń, brak automatycznego sortowania szkicu;
- as niski i wysoki, zakaz zawijania i sekwencji czternastokartowej;
- zwykłe zestawy kontra fizycznie identyczne karty;
- ograniczenia długości i jednego jokera w układzie;
- położenie jokera, niejednoznaczny kolor w zestawie i poprawna podmiana;
- podmiana jokera z ręki i późniejsze zabranie całego układu;
- zabieranie, łączenie i budowanie nowych układów z zachowaniem liczby kart;
- legalne zatrzymanie zabranych kart, 300 za każdą, jednokrotne rozliczenie;
- brak zakleszczenia z samymi jokerami lub zabranymi kartami;
- równoważne identyczne egzemplarze przy rozliczaniu zwrotu;
- kary przy odrzuceniu ostatniej karty, zakończeniu rozdania i upływie czasu;
- czas przed dobraniem i po nim, kara 50 oraz sumowanie z 300;
- niewysłany szkic nie jest wyłożeniem i nie cofa wcześniej zabranych kart;
- wartości, premie, mnożniki, limity po całym rozdaniu i remisy;
- brak limitu liczby rozdań i brak dodatkowej premii minus 100 w eliminacji;
- przetasowanie odrzutów, brak kart i dwa obiegi do blokady.

Regresje interfejsu i integracji:

- formularz ma tylko jedną listę wariantu, resztę odpowiednich pól wyboru
  i edycyjnych; brak limitu rozdań oraz opcji wszechwiedzy;
- Enter pokazuje cele nawet przy jednym; brak celu daje legalny odrzut
  i anulowanie; Delete odrzuca bez wyboru celu;
- Enter w szkicu zaznacza zamiast odrzucać;
- menu układu zawiera tylko merge, zabranie całego i konkretne legalne karty;
- Shift+D prezentuje tylko nazwy w kolejności od najnowszej;
- joker jest słyszalny, ale bez dopisku „zastępuje kartę…”;
- kursor po pojedynczym ruchu, paczce, wielu dobranych, sortowaniu
  i przy identycznych egzemplarzach;
- aktualizacje nie przerywają pisania i nie kradną fokusu czatu lub historii;
- pomoc, tłumaczenia, dźwięki i brak powtórzeń przy odświeżeniu;
- odtworzenie na kilku klientach, ponowienia, podwójny Enter, późne zdarzenia
  oraz limit wielkości przesyłanych akcji;
- zapis i wznowienie bez zmiany kart, wyników oraz kolejności.

Boty wymagają celowanych sytuacji strategicznych, nie tylko prób, w których
udało im się zakończyć partię. Sprawdzić wszystkie warianty, pierwsze
wyłożenie, jokery, identyczne karty, dobieranie pakietów, manipulację,
ocenę ryzyka i faktyczny czas obliczeń. Nie testować ani nie tworzyć bota
wszechwiedzącego. Przy zmianach wspólnych dodać celowane regresje dotkniętych
komponentów, nie zmieniać zachowania pozostałych gier.

Numer przyszłego wydania i budowanie/podpisywanie nie zostały tym projektem
ustalone. Wersja istniejącej aplikacji pozostaje bez zmian. Nie instalować
ani nie publikować niczego bez właściwego osobnego polecenia.

## Rejestr korekt po przedstawieniu pełnego planu

Poniższe punkty są już uwzględnione w treści wyżej, a nie dodatkowymi
sprzecznymi wariantami:

1. Enter w zwykłej ręce wybiera pasujące układy, a przy braku dopasowania
   proponuje odrzucenie i anulowanie. Delete odrzuca bez wyboru.
2. Joker ma być słyszalny jako joker wszędzie w prezentacji układów.
   Odczyt np. „joker, 3 i 4 pik”, bez „joker jako…” lub „zastępuje…”.
3. Usunięto dodatkowy wybór dopasowania jokera w sekwencji: decyduje
   kolejność budowania.
4. Wymagana jest poprawna kolejność zaznaczania kart. Wycofano automatyczne
   sortowanie i naprawianie przygotowanych układów.
5. Jedyna lista ustawień to Discard mode. Eliminacja, punktacja co 5,
   manipulowanie i identyczne karty to pola wyboru z krótkimi opisami;
   minimum, limit, czas i opóźnienie bota to pola liczbowe.
6. Usunięto limit liczby rozdań również z logiki końca gry.
7. Wolno zatrzymać zabrane karty za 300 kary od każdej. Nie wymuszać zwrotu
   jako warunku końca tury. Po rozliczeniu zachowane karty są zwykłe.
8. Menu układu ograniczono do merge, zabrania całego układu i nazw konkretnych
   kart do zabrania. Nie dodawać dokładania, odzyskiwania ani rozdzielania.
9. Usunięto całkowicie możliwość bota wszechwiedzącego w Rummy.
10. Shift+D zawiera tylko nazwy kart od najnowszej do najstarszej, bez
    dopisków liczby dobieranych kart i bez dodatkowego potwierdzania.

## Materiały źródłowe i granice potwierdzenia

- Podstawowy tekst zasad: przekazany przez użytkownika opis
  [QC Rummy](https://qcsalon.net/en/rami).
- Porównawcze objaśnienia: [włoski opis QC](https://qcsalon.net/it/rami)
  i [poradnik społeczności](https://blog.tecwindow.net/3177/rummy/).
- Dodatkowa premia eliminacyjna, świadomie niewłączona do naszego projektu:
  [wyjaśnienie na forum QC](https://qcsalon.net/en/forum7/topic143668).
- Doniesienia o zakleszczeniach odzyskanego jokera nie są regułami do
  skopiowania: [wątek 2017](https://qcsalon.net/en/forum7/topic28502)
  i [wątek 2026](https://qcsalon.net/en/forum7/topic144853).
- Starsza dyskusja o blokadzie rozdania:
  [forum QC](https://qcsalon.net/en/forum7/topic5757).
- Potwierdzona luka botów QC w rozpoznawaniu identycznych układów nie jest
  wzorcem dla naszego planera:
  [forum QC](https://qcsalon.net/en/forum7/topic143726).

Nie pozyskiwano nowych danych z QC w ramach zapisania tego dokumentu.
Nie traktować niepotwierdzonych szczegółów, starych błędów ani propozycji
forumowiczów jako obowiązujących reguł serwera. Przyjęte świadomie decyzje
użytkownika są wymaganiami naszego projektu, nawet jeśli QC działa inaczej.
