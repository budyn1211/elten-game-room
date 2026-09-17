# Trzeci plan — kolejne poprawki

Nowy zbierany zakres po wykonaniu tego dokumentu: uproszczenie Scrabble,
wybór pociągów Mexican Train i Biblios z PR #7 jest opisany osobno w
[POST_227_GAME_CHANGES_PLAN.md](POST_227_GAME_CHANGES_PLAN.md).
Nie mylić jego statusu „tylko plan” z wykonanymi siedmioma punktami poniżej.

Aktualizacja wykonania: wszystkie siedem punktów wdrożono lokalnie
na polecenie użytkownika z 17 września 2026, do wersji 2.0/build 227.
Zakres i wyniki: `RELEASE_2_0_VERIFICATION.md`. Poniższe zapisy
„bez wdrażania” i lista przyszłych testów przedstawiają wcześniejszy
etap planowania, nie aktualny status. Bez zmiany rodzaju gry pod
Ctrl+Shift+X, instalacji i publikacji.

Stan: 17 września 2026. Zbieranie wymagań, bez wdrażania.

## Miejsce w bieżących ustaleniach

Po zakończeniu wcześniejszych czterech planów użytkownik przygotowuje
kolejną grupę projektów przed wydaniem:

1. [Scrabble](SCRABBLE_DESIGN.md) — zaakceptowany projekt, bez implementacji.
2. [Taboo](TABOO_DESIGN.md) — zatwierdzony plan, gotowy do wdrożenia;
   gra, dane i testy nie są jeszcze wykonane.
3. Ten dokument — kolejne poprawki i propozycje do uzgodnienia.

Ten plan nie zastępuje wcześniej wdrożonego
[planu widgetu, powiadomień, botów i Reversi](SAVES_WIDGET_NOTIFICATIONS_PLAN.md).
Nie przenosić do niego automatycznie dawnych, odłożonych propozycji.

## Uzgodnione poprawki

### 1. D — odczyt wyrzuconych kości

Użytkownik chce, żeby w grach z kośćmi D wypowiadało wyrzucone wartości.
To odczyt stanu, nie rzut, zaznaczanie ani wykonywanie ruchu. Nie zmienia
kursora i nie wymaga osobnego żądania sieciowego. Przed dostępnym rzutem
ma podać krótko, że kości nie zostały jeszcze rzucone.

Przegląd obecnych źródeł:

- Farkle już ma D przez wspólną funkcję `last_roll`; zachować odczyt.
- Yahtzee i Chińczyk nie mają takiego skrótu; uwzględnić je w planie.
- Spacja w Yahtzee nadal odczytuje zachowane i zaznaczone kości.
  D ma podawać same wyrzucone wartości, nie zastępować Spacji.
- W Monopoly D już otwiera niekupione nieruchomości, a Shift+D planszę.
  Użytkownik potwierdził pozostawienie D w Monopoly bez zmian. Nie obejmować
  tej gry nowym odczytem ani nie przenosić dotychczasowych skrótów.
- Kostki Domino i Mexican Train nie są rzucanymi kośćmi; nie dodawać tam
  sztucznego odczytu rzutu.

Wdrożenie oprzeć na istniejącej wspólnej definicji skrótu `last_roll`,
z danymi konkretnej gry. Nie podpinać D do edytowalnego czatu. Pomoc F1
i opis skrótów muszą odpowiadać faktycznej obsłudze.

### 2. Yahtzee — V i Shift+V otwierają karty punktacji

Zatwierdzone wymaganie:

- V otwiera własną kartę pól/kategorii punktacji.
- Shift+V otwiera kartę punktacji przeciwnika.
- To przegląd zapisanych wyników, nie formularz zapisu bieżącego rzutu.

Proponowane doprecyzowanie interfejsu: przy jednym przeciwniku od razu
jego karta; przy kilku najpierw wybór osoby. W samej karcie czytelny
właściciel, kategorie właściwe dla ustawionego wariantu, zapisane punkty,
rozróżnienie pustego pola i wpisanego zera, premie i podsumowanie.
Ten szczegół wyboru osoby jest propozycją, nie osobną decyzją użytkownika.
Odczyt dostępny także poza własną turą, z bieżącego zsynchronizowanego
stanu. Zamknięcie przywraca poprzednią pozycję bez zmiany zaznaczonych
kości. S pozostaje krótkim odczytem wyników. Obserwator nie otrzymuje
fikcyjnej własnej karty; może przeglądać rzeczywistych uczestników.

### 3. Alfabetyczna kolejność gier

Użytkownik chce sortowania gier alfabetycznie. Stosować nazwy widoczne
w wybranym języku interfejsu, a nie techniczne identyfikatory czy kolejność
rejestracji klas. Ujednolicić listy wyboru gier, w tym tworzenie/dołączanie
i listy gier z polami wyboru w ustawieniach. Nie zmieniać przy tym
kolejności uczestników, ruchów ani wpisów historii.

Sortowanie ma zachować wybór i zapisane preferencje według ID gry,
nie dawnego indeksu listy. Uwzględnić polskie litery i przyszłe gry.
Nazwę liczbową „99” traktować jako nazwę wyświetlaną, przed nazwami
literowymi; nie sortować jej według dotychczasowego słownego tłumaczenia.

### 4. Nazwa gry „99”

Użytkownik chce wyświetlać „99”, nie słowną nazwę. Obecne źródło to
`NinetyNine#name`, zwracające tłumaczone „Ninety-nine”. Zmiana dotyczy
nazwy prezentowanej użytkownikowi, także w pomocy i powiadomieniach.
Techniczne ID `ninety_nine`, format zdarzeń, istniejące zapisy partii
i preferencje pozostają zgodne; nie tworzyć nowej gry ani migracji ID.

### 5. Farkle — PR Pajpera, dostosowanie botów i tłumaczenia

Użytkownik zatwierdził uwzględnienie PR #6 w planie wraz z poprawkami
botów i tłumaczeń. To zgoda na zakres przyszłego wdrożenia, nie polecenie
zmiany kodu ani scalenia PR teraz. Pozostałe punkty planu bez zmian.

Na prośbę użytkownika odczytano opis i pełną różnicę
[PR #6 „Dokończenie rundy przed zakończeniem Farkle”](https://github.com/papierek1997/elten-game-room/pull/6)
autora `dawidpieper`. Sprawdzony commit:
`5cbec01d85e797901d8ebb9504afaa3f935164b7`, bazowy
`0b2dd09f75b749ba05b3e9d247bee2e4fa9b0a1f`.
PR zmienia tylko `games/farkle.rb` i `test/farkle_test.rb`.
Nie pobrano gałęzi do pracy, nie scalono i nie zastosowano zmian.

Zatwierdzone zachowanie do przyszłego wdrożenia:

- Zakładany limit nadal trzeba osiągnąć punktami odłożonymi, nie tylko
  uzbieranymi w bieżącym ruchu.
- Po osiągnięciu limitu kończy się bieżący obieg graczy, do ostatniej osoby
  w kolejności partii. Wszyscy mają wówczas tyle samo rozegranych tur.
- Przykład A, B, C, D: B osiąga limit, grają jeszcze C i D. A nie dostaje
  kolejnej tury. Jeżeli limit osiągnie D, zakończenie następuje od razu.
  To nie wariant „każdy inny dostaje jeszcze jedną turę”.
- Wygrywa najwyższy końcowy wynik; remis na najwyższym wyniku kończy grę
  remisem. Pozostałe osoby mogą przebić wynik pierwszej osoby z limitem.
- Dochodzi komunikat historii o osiągnięciu limitu i dokończeniu rundy.
  Zmieniono też tekst zasad, zakończenie po Farkle oraz obsługę remisu.
- Dodane testy obejmują dokończenie rundy, osiągnięcie limitu przez pierwszą
  i ostatnią osobę, przebicie wyniku i remis. Zostały tylko przeczytane;
  w tym etapie nie uruchamiano testów ani gry.

Wymagane uzupełnienia przy wdrożeniu:

1. Uzupełnić polskie tłumaczenia nowego zdania zasad i komunikatu historii
   oraz zgodność źródłowego tekstu angielskiego z nową regułą. Obecny PR
   ich nie zawiera: autor jawnie odłożył tłumaczenia, a jego opis zgłasza
   błąd testu zasad z tego powodu. Nie przedstawiać jego raportu jako
   własnego wykonania testów.
2. PR nie dostosowuje bota do nowego zakończenia. Obecny
   `FarklePlanning::Strategy#choose_roll_or_bank` natychmiast odkłada punkty
   po osiągnięciu limitu, a wycena dalszych punktów jest ograniczona tym
   limitem. Podobne założenie mają wybór kombinacji i `bot_action_score`.
   Przy limicie 1000, liderze 1200 i własnym wyniku po odłożeniu 1050 bot
   odłoży punkty nawet w ostatniej turze, choć to pewna przegrana, a dalszy
   rzut może jeszcze pozwolić wygrać. To wniosek z kodu, nie z rozegranej próby.
   Dostosować zarówno strategię, jak i wybór kombinacji, pomocniczą ocenę
   akcji oraz klucze pamięci wyników do rzeczywistego lidera i pozycji
   w końcowej rundzie. Osiągnięcie limitu rozpoczyna kończenie rundy,
   nie jest już równoznaczne z wygraną.

   Bot ma uwzględniać, kto jeszcze będzie grać, możliwość remisu oraz
   wymagane minimum odłożenia. W ostatniej turze nie powinien wybierać
   pewnej przegranej przez odłożenie, gdy legalny dalszy rzut daje jeszcze
   szansę poprawy wyniku. Jeżeli odłożenie w ostatniej turze gwarantuje
   samodzielną wygraną, nie powinien jej bez potrzeby ryzykować. Wcześniej
   w obiegu ma oceniać przewagę i ryzyko dalszych rzutów, zamiast uznawać
   sam limit za bezwarunkowy nakaz odłożenia. Zachować obecny rząd kosztu
   obliczeń; nie zwiększać automatycznie głębokości wyszukiwania ani
   przenosić zmian strategii do innych gier.
3. Przed wydaniem sprawdzić odtwarzanie starszych zapisów i zgodność wersji
   klientów: PR zmienia interpretację zakończenia tej samej historii zdarzeń
   bez dodania wariantu/starej reguły. Na razie to punkt kontroli integracji,
   nie potwierdzona awaria rzeczywistego zapisu.

Przy przyszłym wdrożeniu wykonać celowane testy Farkle: osiągnięcie limitu
przez pierwszego, środkowego i ostatniego gracza; zakończenie ostatniej
tury przez odłożenie i Farkle; przebicie wyniku i remis; decyzje bota
poniżej lidera oraz przy gwarantowanej wygranej; zachowanie przed końcową
rundą, odtworzenie stanu i kompletność tłumaczeń. Nie oznaczać tych
sprawdzeń jako wykonanych na podstawie samego planu.

Stan wykonania: wyłącznie dokumentacja. PR nie został scalony, kod i boty
nie zostały zmienione, tłumaczenia nie zostały jeszcze dodane, testów gry
nie uruchamiano. Rozpoczęcie wdrożenia wymaga osobnego polecenia.

### 6. Ctrl+X — zmiana ustawień gry przy istniejącym stole

Użytkownik zatwierdził dodanie do planu tylko zmiany ustawień obecnej gry.
Ctrl+Shift+X do zmiany samej gry pozostaje poza zakresem. Nie dodawać
migracji LiveSession ani innego sposobu zmiany rodzaju gry przy okazji.

- Ctrl+X i odpowiednia pozycja wspólnego menu pokoju otwierają istniejący
  formularz ustawień, ale z aktualnymi wartościami stołu i przyciskiem
  zatwierdzenia zmian, nie „Utwórz stół”. Zachować ukrywanie zależnych opcji
  i walidację właściwą dla gry oraz liczby uczestników.
- Zmieniać może wyłącznie master. Edycja jest możliwa przed rozpoczęciem,
  po normalnym zakończeniu lub po przerwaniu partii przez Ctrl+Q.
  Podczas aktywnej partii nie zmieniać zasad; najpierw trzeba ją przerwać.
- Nowe ustawienia dotyczą następnej partii. Nie przeliczać nimi historii
  poprzedniej, punktów ani istniejących archiwów. Formularz ustawień nie
  może modyfikować zasad zapisu oczekującego na wznowienie.
- Anulowanie niczego nie zapisuje. Przy zatwierdzeniu ponownie sprawdzić
  uprawnienia, aktualną partię, ustawienia i skład stołu. Nie nadpisywać
  nowszego stanu ani akceptować edycji, jeśli w międzyczasie ruszyła gra.
- Zatwierdzone ustawienia publikować jako spójną zmianę stanu pokoju,
  nie osobne żądanie przy każdym przestawieniu pola. Wszyscy mają korzystać
  z tego samego zestawu. Do historii pokoju trafia informacja, kto zmienił
  ustawienia; Ctrl+R i zasady ustawionego stołu pokazują nową konfigurację.
- Ten sam pokój i LiveSession, uczestnicy, obserwatorzy, boty, prywatność
  oraz czat pozostają. Bez ponownego zapraszania, automatycznego usuwania
  ludzi/botów ani zgłaszania stołu jako nowo utworzonego. Nowa gra nie
  rozpoczyna się automatycznie po zamknięciu formularza.
- Ctrl+X działa poza edytowalnymi polami. W czacie i innych polach tekstu
  zachować zwykłe wycinanie. Pomoc F1 i menu korzystają ze wspólnej definicji.

Potwierdzone w odczycie źródeł: `update_room` już dopuszcza `game_options`,
a rozpoczęta partia przechowuje własne `options`. To podstawa przyszłej
zmiany, nie dowód, że ekran edycji i wszystkie zabezpieczenia już istnieją.
Należy także oddzielić ustawienia następnej partii od widoku zakończonej
i od początkowych danych discovery, żeby stara konfiguracja nie wracała
przy odświeżeniu lub dołączeniu. Nie zmieniać przy tym publicznego ID gry.

### 7. Ctrl+Q — przerwanie bieżącej partii bez zamykania stołu

Użytkownik chce, żeby master mógł zakończyć obecną partię, pozostać
z uczestnikami w tym samym pokoju, następnie zmienić ustawienia Ctrl+X
i rozpocząć nową partię. Jest to przerwanie całej partii, nie zakończenie
jednego rozdania, dobrowolna przegrana ani wyjście z Game Roomu.

- Wspólna funkcja dla wszystkich gier, tylko dla mastera i tylko przy
  aktywnej partii. Działa niezależnie od tego, czyją jest turą, także
  w turze bota i w fazach oczekiwania. Udostępnić również w menu pokoju
  jako „Przerwij partię” i w dynamicznej pomocy F1.
- Proponowane zabezpieczenie interfejsu: krótkie potwierdzenie przerwania.
  Samo otwarcie lub anulowanie pytania nie przerywa ani nie cofa gry.
  Przy potwierdzeniu ponownie sprawdzić uprawnienia i ID bieżącej partii,
  aby opóźniona odpowiedź nie przerwała nowo rozpoczętej gry.
- Przerwana partia nie otrzymuje sztucznego zwycięzcy, remisu, rozliczenia
  końcowego ani dźwięków wygranej/przegranej. Już odnotowane zdarzenia
  zachowują znaczenie. Historia pokoju zawiera wpis, kto przerwał partię.
- Po potwierdzonej zmianie wszyscy wracają do stanu oczekiwania przy
  tym samym stole. Nie zamykać LiveSession ani nie wywoływać opuszczania
  pokoju. Zachować członków, role, boty, prywatność i czat; nie kasować
  historii w celu przerwania. Nie uruchamiać następnej partii samoczynnie.
- Zakończenie musi być trwałym zdarzeniem wspólnego cyklu życia partii,
  związanym z jej ID i odtwarzanym przez wszystkich klientów. Samo lokalne
  zamknięcie ekranu albo ustawienie stołu jako „otwarty” nie wystarczy.
  Odczyt, ponowne wejście i odzyskanie połączenia nie mogą jej wznowić.
- Po granicy przerwania odrzucić ruchy tej partii, wyniki obliczeń botów,
  automatyczne akcje i timeouty. Zdarzenia utrwalone przed granicą pozostają
  wcześniejszymi ruchami; opóźnione po niej nie mogą ożywić partii ani
  trafić do nowej. Ponowienie żądania po utracie odpowiedzi nie dubluje
  zakończenia ani komunikatu historii.
- Nowy start tworzy nową partię w tej samej sesji pokoju, korzystając
  z aktualnego składu i ustawień. Nie dziedziczy oczekujących ruchów,
  zegarów ani zaplanowanych decyzji botów poprzedniej partii.
- Nie utożsamiać przerwania z odwracalnym zamrożeniem na czas Ctrl+S.
  Nie usuwać istniejących zapisów partii. Zabezpieczyć również scenariusz
  przerwania po wznowieniu archiwum, bez automatycznego wznowienia go
  ponownie przy następnym starcie.
- Skrót ma dotyczyć wyłącznie pokoju Game Roomu, nie zamykać ELTEN-a
  ani działać globalnie poza aplikacją. Dostępność i uprawnienia kontrolować
  również przy odbiorze zdarzenia, nie tylko przez ukrycie pozycji menu.

W odczytanym kodzie normalny status stołu wynika z odtworzonego końca gry;
obsługa `game_boundary` służy obecnie zamrażaniu zapisu. Nie ma jeszcze
gotowej obsługi opisanego ręcznego przerwania. Przy wdrożeniu zapewnić
spójność protokołu i klientów, zamiast dokładać osobną regułę do każdej gry.

Przyszła weryfikacja punktów 6–7: master i niedozwolony użytkownik;
anulowanie; zmiana ustawień przed startem, po końcu i po Ctrl+Q;
pozostawienie stołu/czatu/uczestników; nowa partia z nowymi opcjami;
przerwanie podczas tury człowieka, bota, wyboru koloru, aukcji i oczekiwania
na odpowiedzi; opóźniony ruch lub wynik bota; ponowienie po utracie HTTP;
ponowne wejście, dołączenie nowego klienta, start z odtworzonego archiwum;
brak wycinania tekstu przez funkcję ustawień; zgodność menu, F1 i PL/EN.
Sprawdzić także, że samo Ctrl+Q nie zmienia ukończonej partii, a potwierdzenie
starego okna nie zatrzymuje nowszej. To lista przyszłych testów, nie wyniki.

## Granice prac

Na tym etapie wyłącznie planowanie. Bez implementacji, zmian serwera,
testów gry, zmiany wersji 1.1.10/build 226, budowania, podpisywania,
instalowania i publikowania. Rozpoczęcie wdrożenia wymaga osobnego polecenia.
