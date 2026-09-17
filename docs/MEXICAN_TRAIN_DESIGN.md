# Mexican Train — uzgodniony projekt i stan wdrożenia

Nowsze uzgodnienie, 17 września 2026: zaakceptowano zmianę wyboru pociągów
z [kolejnego planu](POST_227_GAME_CHANGES_PLAN.md#2-mexican-train--wszystkie-pociągi-świadomy-wybór-celu).
Enter pokazuje wszystkie pociągi, również zamknięte i chwilowo zabronione,
a próba zagrania wyjaśnia odmowę. Kostka bez legalnego ruchu daje informację
bez listy. Z/Shift+Z tylko wskazuje legalne kostki, bez automatycznego ruchu.
Plan zastępuje starszy opis UI poniżej, lecz jeszcze nie zmienia kodu.
Reguły dubletów, w tym wyjątek własnej serii, pozostają bez zmian.

Data: 17 września 2026. Punkt wyjścia: Game Room 1.1.10/build 226.

Aktualizacja wdrożenia: Mexican Train jest wdrożone lokalnie i przeszło
celowane testy. Użytkownik wstrzymał wydanie do dodania kolejnych gier;
nie zmieniać wersji ani nie budować paczki. Podczas wdrażania sprawdził
w QC i potwierdził, że autor
własnej serii może zamknąć starszy dublet, pozostawiając nowszy na innym
pociągu. Potwierdzenie dotyczy tego konkretnego wyjątku, nie wszystkich
wcześniej oznaczonych propozycji. Postęp: IMPLEMENTATION_2_0.md;
kontrola punktów: IMPLEMENTATION_2_0_VERIFICATION.md. Poniższe zapisy
o braku zgody i przyszłych testach opisują wcześniejszy etap projektu.

Użytkownik wskazał Mexican Train jako ostatnią z dwóch nowych gier po
Domino i przekazał pełny angielski opis zasad z QC. To osobny projekt,
nie rozszerzenie zasad zwykłego Domino. Poniżej oddzielono reguły zawarte
w materiale od propozycji interfejsu, botów i nierozstrzygniętych sytuacji.
Nie ma jeszcze zgody na implementację, zmiany serwera, wersji, budowanie,
podpisywanie, instalowanie ani publikowanie. Rummy, zakończony plan Domino
oraz dwa punkty widgetu/powiadomień pozostają bez zmian.

## 1. Zakres i ustawienia

Proponowana osobna pozycja „Mexican Train”, gra indywidualna dla 2–8 osób,
z poszanowaniem obecnego limitu szkieletu. Nie jest to potwierdzenie
maksymalnej liczby osób obsługiwanej przez QC.

Podstawą jest pojedynczy Double 12: 91 różnych kostek z wartościami 0–12.
Każda kostka ma trwałe ID; 3–7 i 7–3 to ta sama kostka obrócona na planszy.
W całym interfejsie używać nazwy „kostki”, nie „kamienie”.

Użytkownik zatwierdził ustawienia:

- „Limit punktów”: pole liczbowe, domyślnie 100.
- „Dobieranie mimo posiadania pasującej kostki”: pole wyboru, domyślnie
  wyłączone. To odpowiednik wskazanej opcji Domino, ale z inną wartością
  domyślną. Szczegóły współdziałania z turą i dubletami są w sekcji 4.

Liczba kostek na osobę zależy od liczby grających, bez ręcznego wyboru rozmiaru
ręki: po 15 dla 2–5 osób, po 12 dla 6–7 i po 10 dla 8. Szczegóły
i jawne odczytanie literówki w wiadomości użytkownika są w sekcji 2.

Nie przenosić automatycznie jedenastu zestawów, drużyn, dobierania do skutku,
zakazu dobierania ani kończenia całą drużyną z Domino. Użytkownik wskazał
tylko jedną dodatkową opcję: dobieranie mimo legalnej kostki. Nie kopiować
całej konfiguracji Domino ani nie ustawiać tej opcji domyślnie na włączoną.
Nie dodawać limitu trzynastu rozdań: numer stacji cyklicznie wraca do 12.
Thinking time i bot wszechwiedzący nie zostały uzgodnione. Późniejszy
punkt 3 `SAVES_WIDGET_NOTIFICATIONS_PLAN.md` obejmuje tę grę wspólnym
opóźnieniem bota 0–5 sekund, gdzie 0 wyłącza pauzę; proponowane domyślnie 0.
Prywatność, zaproszenia, głośność i pomoc pozostają wspólnymi funkcjami
Game Roomu.

## 2. Stacja, rozdanie i rozpoczynanie

Pierwsze rozdanie zaczyna się od 12–12 w centrum, drugie od 11–11,
następne schodzą do 0–0 w trzynastym. Czternaste wraca do 12–12.
Zmiana stacji zależy od numeru rozdania, nie od tożsamości zwycięzcy.

Proponowany sposób przygotowania: wyjąć właściwy dublet przed tasowaniem,
umieścić go automatycznie jako stację, a pozostałe 90 kostek rozdzielić
między ręce i stos. Nikt nie musi najpierw wylosować tej kostki.
To propozycja technicznego przygotowania, nie udokumentowana metoda
wyboru pierwszego gracza w QC. Stacja nie jest niezakończonym dubletem
wyłożonym w turze i nie tworzy obowiązku dodatkowego ruchu.

Pierwotny opis mówił o 8–15 kostkach bez dokładnej tabeli. Użytkownik
następnie doprecyzował: do pięciu graczy po 15, sześciu po 12, „17 graczy
też po 12”, ośmiu po 10. Zapis „17” odczytano jawnie jako literówkę
„i 7”, zgodnie z limitem ośmiu osób; nie rozszerza to limitu do 17.
Wariant dla siedmiu osób opiera się na tym odczytaniu, nie na osobnym
potwierdzeniu użytkownika ani próbie w QC.

| Liczba graczy | Kostek na osobę | Kostek w stosie po odłożeniu stacji |
|---|---:|---:|
| 2 | 15 | 60 |
| 3 | 15 | 45 |
| 4 | 15 | 30 |
| 5 | 15 | 15 |
| 6 | 12 | 18 |
| 7 | 12 | 6 |
| 8 | 10 | 10 |

Sprawdzono pojemność: stacja + ręce + stos dają 91 kostek w każdym
wierszu. Nie przyjmować rozdania 7/10 ze zwykłego Domino. Po eliminacjach
proponowana liczebność rozdania ma wynikać z liczby nadal grających.

Nie wskazano osoby rozpoczynającej pierwsze i kolejne rozdania. Propozycja
do zatwierdzenia: pierwszą osobę wylosować, a następnie przesuwać startera
po kolei wśród aktywnych graczy. Nie twierdzić, że tak robi QC, ani nie
przenosić wyboru najwyższego dubletu z Domino.

## 3. Pociągi i możliwość zagrania

Każdy aktywny gracz ma jeden pociąg osobisty. Dodatkowo istnieje wspólny
pociąg meksykański, bez właściciela. Wszystkie wychodzą z jednej stacji;
pusty pociąg wymaga wartości stacji. Kolejne kostki muszą pasować do
aktualnego końca danego pociągu, a program orientuje je automatycznie.

Pociągi osobiste zaczynają zamknięte. Zwykły legalny ruch to zagranie na:

- własnym pociągu, niezależnie od jego otwarcia;
- wspólnym pociągu meksykańskim;
- otwartym pociągu innego gracza.

Nie można zagrać na cudzym zamkniętym pociągu, z wyjątkiem obowiązkowego
zamknięcia dubletu opisanego dalej. Wyłożenie kostki na własnym pociągu
zamyka go. Wyłożenie na cudzym otwartym nie zamyka go. Zagranie na
pociągu publicznym albo cudzym nie zamyka własnego otwartego pociągu.

Pociąg meksykański nie otrzymuje znacznika zamknięcia. Nie znaczy to,
że można ignorować obowiązek zamknięcia dubletu na innym pociągu.
Otwarcie pociągu i bieżąca legalność ruchu to dwie różne rzeczy.

## 4. Dobieranie i koniec zwykłej tury

Gdy istnieje legalne zagranie, gracz wybiera kostkę i pociąg. Zwykła
kostka kończy turę; dublet daje dalszy ruch. Nie ma dowolnego pasowania.
Przy domyślnie wyłączonej opcji nie można dobierać mimo legalnego zagrania.
Po jej włączeniu Spacja pozwala dobrać jedną kostkę również wtedy, gdy
da się zagrać z ręki. Legalność obejmuje aktualny obowiązek dubletu, a nie
dopasowanie do dowolnego pociągu.

Opcja zmienia warunek dopuszczenia pojedynczego dobrania; nie uruchamia
dobierania do skutku ani nie zezwala na nieograniczone ponawianie Spacji
w tej samej nierozstrzygniętej decyzji. Nie znosi obowiązku zamknięcia
dubletu przejętego po innym graczu i nie otwiera sama z siebie pociągu.

Propozycja wymagająca osobnego doprecyzowania: po dobrowolnym dobraniu
nadal wolno zagrać legalną kostkę trzymaną wcześniej. Nietrafiona nowa
kostka nie otwiera pociągu i nie kończy tury, jeśli pozostaje legalny ruch
z ręki. Użytkownik zatwierdził przełącznik i jego domyślny stan, nie
rozstrzygnął osobno tego następstwa dobrowolnego dobrania.

Przy braku legalnego zagrania Spacja dobiera jedną kostkę. Jeśli pasuje,
można ją wyłożyć w tym samym ruchu. Jeżeli nie pasuje, zostaje w ręce,
własny pociąg staje się otwarty i tura przechodzi do następnego gracza.
Proponowany interfejs wykonuje to ostatnie rozstrzygnięcie automatycznie,
bez dodatkowego Entera na „Pas”. Nie dobiera do skutku.

Użytkownik zatwierdził: przy pustym stosie i braku legalnego ruchu własny
pociąg się otwiera i następuje automatyczny pas, bez dodatkowego Entera
i bez próby dobrania. Dotyczy to także braku odpowiedzi na obowiązkowy
dublet; obowiązek pozostaje dla następnego gracza. Sam pusty stos nie
odbiera możliwości zagrania pasującej kostki z ręki.

Nie przenosić ogólnego limitu jednej akcji dobierania na całą turę
z Domino. Trzeba osobno rozstrzygnąć sytuację, w której dobrana kostka
jest dubletem, zostaje zagrana i daje dalszy ruch, ale nie ma już czym
grać. Propozycja: dodatkowy ruch po dublecie daje prawo do jednego nowego
dobrania przy braku legalnego zagrania; nie daje prawa do wielokrotnego
dobierania w tej samej nierozstrzygniętej decyzji. Wymaga zatwierdzenia.

## 5. Dublety — kontynuacja i obowiązek zamknięcia

Z przekazanego opisu wynika, że wyłożenie dubletu daje dodatkowe zagranie
na dowolnym dostępnym pociągu. Kolejny dublet przedłuża turę ponownie.
Nie wolno od razu wymuszać na wykładającym zagrania wyłącznie do jego
najnowszego dubletu, bo usuwałoby to opisaną możliwość kilku dubletów
na różnych pociągach podczas jednej tury.

Dublet na końcu pociągu jest niezakończony, dopóki nie zostanie za nim
wyłożona kolejna kostka. Jeśli jego autor kończy turę bez zamknięcia,
obowiązek przechodzi na kolejnych graczy. Wtedy:

- jedynym celem jest pociąg z dubletem wymagającym zamknięcia;
- wolno na nim zagrać także wtedy, gdy jest cudzy i zamknięty;
- kostka pasująca wyłącznie do innego pociągu nie jest legalną obroną;
- przy braku odpowiedzi gracz dobiera jedną kostkę;
- nietrafione dobranie otwiera jego własny pociąg i przekazuje turę,
  ale nie usuwa obowiązku zamknięcia dubletu.

Kilka dubletów pozostawionych następnym graczom zamyka się w odwrotnej
kolejności powstania: ostatni jako pierwszy. Stan musi zachować
uporządkowaną listę zobowiązań, nie tylko jedną flagę „jest dublet”.

Użytkownik jednoznacznie zatwierdził wyjątek dla autora trwającej serii:
wolno mu zamknąć wcześniejszy dublet, pozostawiając późniejszy na innym
pociągu. Zwykła kostka zamykająca wcześniejszy dublet kończy turę.
Następny gracz odpowiada wtedy na najnowszy spośród nadal niezakończonych
dubletów. Swoboda dotyczy własnej serii; nie pozwala zignorować obowiązku
otrzymanego po poprzednim graczu.

Z listy usuwać konkretny zamknięty dublet, nie bezwarunkowo ostatnią
pozycję. Zachować wzajemną kolejność wszystkich pozostałych. Ta decyzja
pochodzi od użytkownika; podczas wdrażania potwierdził ją własną próbą QC.

Przykład kolejności: A zostawia 6–6 na swoim pociągu, potem 9–9 na
meksykańskim i kończy turę bez zamknięcia. B musi najpierw odpowiedzieć
na 9–9. Gdy je zamknie, pozostaje obowiązek odpowiedzi na 6–6,
nie dowolny wybór pomiędzy tymi pociągami.

Przykład zatwierdzonej swobody: A wykłada 6–6, potem 9–9 na innym pociągu,
a następnie dokłada 6–4 do wcześniejszego 6–6. Tura A się kończy;
6–6 jest zamknięte, a B ma obowiązek zamknąć pozostawione 9–9.

Publiczna informacja o obowiązku nie zmienia trwale znaczników otwarcia.
Zamknięcie cudzego dubletu nie robi z jego pociągu własnego ani nie
zamyka go z powodu ruchu obcej osoby. Zagranie właściciela na własnym
pociągu nadal zamyka ten pociąg zgodnie z regułą ogólną.

Wyłożenie dubletu jako ostatniej kostki kończy rozdanie natychmiast.
Nie wymaga kolejnego ruchu, dobrania ani domykania pozostałych dubletów.

## 6. Zakończenie, blokada i punkty

Pierwsza pusta ręka wygrywa rozdanie i dostaje zero punktów. Pozostali
otrzymują sumę oczek z kostek w ręce, z wyjątkiem 0–0, zawsze wartego
10 punktów. Nie przenosić wyjątku Domino „10 tylko jako jedyna kostka”.

Blokada wymaga pustego stosu i pełnego obiegu bez możliwości zagrania.
Legalność musi uwzględniać otwarcie pociągów i obowiązkowy dublet, nie
samo dopasowanie wartości gdziekolwiek. Otwarcie pociągu może dać ruch
osobie, która wcześniej nie mogła grać; nie kończyć przedwcześnie
rozdania samym licznikiem pasów bez kontroli aktualnej legalności.
Każde rzeczywiste zagranie unieważnia poprzedni obieg bez ruchów.

Przy blokadzie nikt nie ma zerowania za wygraną; wszyscy liczą pozostałe
ręce. Punkty i eliminacje rozliczać wspólnie na końcu rozdania.
Osiągnięcie lub przekroczenie progu eliminuje. Ostatni pozostający wygrywa.
Kolejne rozdanie ma nowe pociągi dla pozostających graczy, bez pociągów
osób już wyeliminowanych.

Propozycja rozstrzygnięcia nieopisanego remisu/eliminacji wszystkich:
tak jak uzgodniono w Domino, wygrywa najniższy łączny wynik, a remis
na minimum daje wspólne zwycięstwo. Decyzja użytkownika o Domino nie
jest automatycznie zatwierdzeniem tego wyjątku w Mexican Train.

## 7. Proponowany interfejs

Główna lista to własne kostki pod strzałkami, bez Tabowania po każdej.
Enter na kostce:

- jeśli ma jeden legalny cel, od razu wykonuje zagranie;
- jeśli pasuje do kilku pociągów, otwiera krótką listę tylko tych celów;
- jeśli nie ma legalnego celu, daje krótki komunikat bez zmiany stanu.

Lista celów: własny pociąg, meksykański, następnie pozostałych w kolejności
graczy, z pominięciem niedostępnych. Nazwa właściciela i końcowa wartość
wystarczają do wyboru; przy wymuszonym dublecie legalny jest jego pociąg,
nie cała lista. Escape anuluje sam wybór, nie zagrywa i nie kończy tury.
Nie łączyć na stałe wyboru kostki z ostatnio wybranym pociągiem.

Skróty z opisu oraz proponowane zachowanie:

- Spacja: dobranie według aktualnej fazy.
- C: lista pociągów pod strzałkami, z końcem i stanem otwarty/zamknięty
  oraz oznaczeniem dubletu do zamknięcia. Po późniejszym doprecyzowaniu
  użytkownika nagłówek brzmi tylko „Pociągi”, bez stacji. W wierszach
  podajemy samą liczbę zamiast „koniec N”.
  Enter na pociągu pokazuje jego kostki od stacji do końca; to podgląd,
  nie akcja zagrania. Escape wraca z zachowaniem pozycji ręki.
- E: zwięzłe liczby kostek, np. „papierek, 6; peterman, 4; stos, 20”.
- S: wyniki graczy.
- T: czyja tura; w razie obowiązku także konkretny dublet i pociąg.
- Z / Shift+Z: proponowane przejście po legalnych fizycznych kostkach.
  Automat wyłącznie przy jednej legalnej kostce i jednym legalnym celu;
  przy wyborze pociągu tylko ustawić kursor.

Przykładowe pozycje pod C: „papierek, koniec 6, zamknięty”;
„peterman, 9, otwarty”; „Meksykański, 9, dublet do zamknięcia”.
Zawsze otwarty charakter meksykańskiego nie wymaga powtarzania tej samej
informacji przy każdej akcji. Nie przypisywać mu fikcyjnego właściciela.

Proponowany kursor: po wyłożeniu poprzednia kostka, a z pierwszej pozycji
nowa pierwsza; po dobraniu dobrana kostka na końcu ręki. Odczytać nazwę
pod kursorem bez ponownego nagłówka „Twoja ręka” i przebudowy formularza.
Zamknięcie podglądu ani anulowanie listy celów nie przesuwa ręki.

Obecny kontrakt karcianej ręki dotyczy kart. W przyszłym wdrożeniu Domino
i Mexican Train współdzielą neutralną obsługę ręki kostek; nie oznaczać
planszy jako ręki kart dla uzyskania skrótów. Nie zmieniać zachowania
innych gier. F1, Ctrl+F1, Ctrl+R, głośność i czat korzystają ze wspólnego
szkieletu; literowe akcje gry nie działają podczas pisania na czacie.

## 8. Komunikaty i dźwięki

Proponowane krótkie komunikaty do historii:

- „papierek zagrywa 6–9 na swój pociąg”.
- „peterman zagrywa 9–4 na pociąg papierek”.
- „papierek zagrywa 4–7 na pociąg meksykański”.
- „peterman dobiera. Jego pociąg jest otwarty”.
- „Do zamknięcia 9–9 na pociągu meksykańskim”.
- „papierek wygrywa rozdanie”, następnie punkty pozostałych.
- „Rozdanie zablokowane”, następnie punkty wszystkich.

Otwarcie/zamknięcie ogłaszać przy rzeczywistej zmianie. Nie odczytywać
wszystkich pociągów po każdym ruchu ani ujawniać publicznie dobranej kostki.
Koniec tury, otwarcie pociągu i kara punktowa nie mogą dostawać kilku
sprzecznych komunikatów. Dźwięki przez istniejące kategorie i poziomy;
dobór konkretnych plików pozostaje do ustalenia.

## 9. Proponowany bot

Bot zwykły zna swoją rękę, publiczne pociągi i historię, liczby kostek
przeciwników oraz stosu. Nie odczytuje cudzych rąk ani kolejności stosu.
Nie dodano do zakresu odrębnego wariantu wszechwiedzącego.

Wybiera parę kostka–pociąg, nie samą kostkę. Najpierw respektuje obowiązek
dubletu i natychmiastowe wyjście, następnie ocenia:

- możliwości kolejnych połączeń własnej ręki i unikanie izolowanych kostek;
- korzyść z zamknięcia własnego otwartego pociągu, ale nie za wszelką cenę;
- użycie pociągu wspólnego/cudzego, aby pozbyć się trudnej kostki;
- wartość punktową pozostałej ręki i zagrożenie eliminacją;
- dalszy legalny ruch po dublecie i skutki pozostawienia zobowiązania;
- ryzyko ułatwienia końcówki przeciwnikowi z małą ręką;
- możliwość i opłacalność blokady przy pustym stosie.

Plan własnego pociągu nie może być sztywny: inni mogą zmieniać wspólny
lub otwarty pociąg. We własnej serii bot ocenia także zamknięcie starszego
dubletu z pozostawieniem nowszego; nie narzuca sobie kolejności obowiązującej
następnych graczy. Publiczny pas przy obowiązkowym dublecie mówi tylko
o braku odpowiedzi na ten dublet, nie o braku kostek do innych pociągów.
Przy włączonym dobrowolnym dobieraniu samo dobranie nie dowodzi braku
legalnego ruchu. Bot uwzględnia koszt dodatkowych oczek i ryzyko eliminacji,
nie dobiera automatycznie tylko dlatego, że opcja na to pozwala.
Informacja o braku wartości starzeje się po dobraniu.

Liczyć wszystkie legalne cele przy ograniczonym koszcie; ewentualne
płytkie przewidywanie kontynuacji po dublecie ma mieć ścisły budżet,
nie pełne przeszukiwanie wszystkich permutacji ręki blokujące ELTEN-a.
Ruch bota przechodzi przez zwykłą walidację i zapis zdarzenia. Jakość
oceniać na celowanych pozycjach, odróżniając rozsądne ryzyko od błędu,
bez obietnicy optymalnej gry i setek partii jako jedynej metody kontroli.

## 10. Wspólne elementy i przyszłe testy

Z planowanym Domino można współdzielić tworzenie zestawu, tożsamość
kostek, orientację, nazwy, neutralną listę ręki i zasady kursora. Nie ma
jeszcze gotowej implementacji Domino do skopiowania. Oddzielić reguły
pociągów, stacji, dodatkowych zagrań, otwarć i punktacji 0–0.

Zdarzenie zagrania zawiera ID kostki i stabilne ID pociągu, nie indeks
chwilowej listy dostępnych celów. Dobranie jest krótkim zdarzeniem;
otwarcie pociągu i przekazanie tury przy braku legalnego ruchu po dobraniu
wynikają z tego zdarzenia zgodnie z ustawieniami, bez dodatkowego żądania
dla każdej zmiany etykiety. Nie utożsamiać nietrafionej nowej kostki
z brakiem legalności wcześniej trzymanych po dobrowolnym dobraniu. Kontynuacje
po dubletach są osobnymi świadomymi zagraniami, nie zgadywaną serią bota.
Transport, kontrola powtórzeń i odtwarzanie pozostają wspólne.

Stan musi zachować także kolejność niezakończonych dubletów, fazę
kontynuacji, informację o dobraniu w danej decyzji, otwarcie pociągów,
stację i postęp rozdania. Nie uzależniać tego od lokalnie otwartego menu.
Lokalny zapis/wznowienie przez wspólny mechanizm po określeniu bezpiecznych
faz; nie przywracać odłożonego projektu zapisów serwerowych.

Przyszłe celowane testy:

1. 91 unikalnych kostek, wyłączenie stacji z rozdania, brak brakujących
   i podwójnych egzemplarzy; rozdania 15/12/10 i dokładne pozostałości
   stosu dla wszystkich liczebności 2–8 z tabeli w sekcji 2.
2. Cykl stacji 12 do 0 i ponownie 12; stacja nie wymusza zamknięcia.
3. Własny, cudzy otwarty, cudzy zamknięty i publiczny pociąg; poprawna orientacja.
4. Zamknięcie własnego pociągu i brak zamykania cudzego przez obcą osobę.
5. Dobranie trafione/nietrafione, oba stany przełącznika dobrowolnego
   dobierania z domyślnym false i poprawne Ctrl+R. Pusty stos bez ruchu
   otwiera własny pociąg i automatycznie pasuje; z legalnym ruchem nie pasuje.
   Dobrowolne dobranie nie obchodzi obowiązku dubletu; zachowanie po nim
   zgodne z przyszłym doprecyzowaniem.
6. Kontynuacje dubletów na różnych pociągach i kolejność ich zamykania;
   autor może zamknąć starszy i zachować nowszy obowiązek dla następnego.
   Przy trzech dubletach zamknięcie środkowego zachowuje kolejność dwóch
   pozostałych. Obowiązkowa odpowiedź także na prywatnym pociągu, bez
   obejścia przez Enter/Z lub włączenie dobrowolnego dobierania.
7. Dobranie dubletu i dalsza decyzja zgodnie z przyszłym rozstrzygnięciem;
   odrzucenie podwójnego wykonania tej samej akcji.
8. Ostatnia kostka, także dublet, kończy bez dodatkowego dobierania.
9. 0–0 z innymi kostkami i samodzielnie daje 10; prawidłowe rozliczenie blokady.
10. Otwarcie pociągu udostępnia ruch wcześniejszemu graczowi i nie powoduje
    fałszywej blokady; obecność obowiązku zawęża rzeczywistą legalność.
11. Równoczesna eliminacja, reset pociągów i rozdanie w mniejszym składzie.
12. Różne legalne pociągi jednej kostki, jedyny cel, anulowanie wyboru,
    C/E/S/T/Z, kursor, brak utraty czatu i nadmiernego odświeżania.
13. Odtworzenie identycznego stanu u kilku klientów, ponowienia i lokalny
    zapis z niezakończonymi dubletami; brak dodatkowego odpytywania serwera.
14. Bot: natychmiastowe wyjście, świadomy wybór pociągu, kontynuacja po
    dublecie, brak mylenia publicznego z zawsze legalnym, punkty i blokada.

Nie uruchamiano testów gry, bo to dokument planu, a nie implementacja.

## 11. Otwarte ustalenia

- Ewentualne sprostowanie odczytania „17” jako „i 7” w tabeli rozdania;
  pozostałe liczebności zostały wprost określone przez użytkownika.
- Wybór rozpoczynającego i przechodzenie tej roli pomiędzy rozdaniami.
- Kolejne dobranie po zagraniu właśnie dobranego dubletu.
- Zachowanie po dobrowolnym dobraniu, gdy nadal można zagrać kostkę
  trzymaną wcześniej; sam przełącznik i domyślne wyłączenie są zatwierdzone.
- Proponowane rozliczenie jednoczesnej eliminacji wszystkich/remisu.
- Akceptacja pozostałych propozycji interfejsu i botów. Limit punktów 100,
  swoboda zamykania starszego dubletu we własnej serii oraz otwarcie
  pociągu i automatyczny pas przy pustym stosie zostały już zatwierdzone.

## Materiał źródłowy

Podstawą jest opis Mexican Train wklejony przez użytkownika. Dwa zapytania
do wyszukiwarki potwierdziły zgodną treść na oficjalnej stronie:
[Mexican train — QuentinC's Playroom](https://radio.qcsalon.net/en/mexicantrain).
Strona również podaje jedynie zakres 8–15 kostek bez dokładnej tabeli.
Dokładne rozdanie w sekcji 2 pochodzi z późniejszego doprecyzowania
użytkownika, z wyraźnie oznaczoną interpretacją zapisu dotyczącego 7 osób.
Nie sterowano klientem QC i nie potwierdzono dodatkowych wyjątków w grze.
Brakujące szczegóły nie są uzupełnione regułami z innych edycji Mexican Train.
