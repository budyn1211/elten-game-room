# Kolejne zmiany gier po buildzie 227 — zatwierdzony plan

Data planu: 17 września 2026. Poniżej zachowano uzgodniony zakres i historyczne
ograniczenia etapu planowania. Następnie użytkownik polecił wdrożenie:
źródła są już zmienione i przeszły testy celowane. **Pakowanie zostało
wstrzymane nowszym poleceniem**, do kolejnej poprawki. Stan wykonania:
`POST_227_IMPLEMENTATION.md`; wyniki: `POST_227_VERIFICATION.md`.

Użytkownik zaakceptował uproszczenie Scrabble, następnie świadomy wybór
pociągów Mexican Train i polecił dodać nowy PR dawidpieper do tego planu.

To nowy zakres. Nie otwiera ponownie siedmiu wykonanych punktów
`NEXT_FIXES_PLAN.md` ani ośmiu napraw z `NEW_GAMES_INTERACTION_AUDIT_227.md`.
Wcześniejsze lokalne poprawki pozostają nienaruszone. Podpisana paczka
2.0/227 nie została przebudowana i nie zawiera tych nowych propozycji.

## 1. Scrabble — jeden sposób układania liter

Użytkownik odrzucił wpisywanie całego słowa w formularzu oraz przenoszenie
czynności do menu kontekstowego. Zachować fizyczne układanie pojedynczych
płytek na planszy i krótką listę skrótów do pozostałych czynności.

### Plansza, ręka i szkic

- Plansza 15 × 15, początek na H8. Strzałki przemieszczają kursor;
  odczyt obejmuje współrzędne, zawartość i ewentualną premię pola.
- Enter na pustym polu otwiera listę dostępnych płytek z własnej ręki.
  Strzałki wybierają płytkę, drugi Enter kładzie ją na wybranym polu.
- Po położeniu płytki kursor pozostaje na tym polu. Kolejne pole gracz
  wybiera strzałką, bez automatycznego przesuwania według kierunku pisania.
- Escape w wyborze płytek zamyka wybór, niczego nie wykładając i nie
  kasując wcześniej ułożonego szkicu.
- Płytka już użyta w szkicu nie jest ponownie dostępna do wybrania.
  Identyczne litery nadal są osobnymi fizycznymi płytkami.
- Wybranie blanku otwiera listę liter do zastąpienia. Blank pozostaje
  rozpoznawalny i wart zero; wybór jego litery należy do gracza.
- Backspace usuwa własną, jeszcze niezatwierdzoną płytkę z aktualnego
  pola i zwraca ją do ręki. Kursor pozostaje na tym polu. To zastępuje
  dotychczasowe cofnięcie ostatniego położenia i osobną funkcję Delete.
  Nie usuwać zatwierdzonych płytek, nawet własnych z poprzednich ruchów.
- Z wycofuje cały szkic. W Scrabble nie służy do nawigacji grywalnych kart.
- Do F szkic jest lokalny; nie wysyłać osobnego zdarzenia za każdą literę.
  Kierunek i legalność wynikają z rzeczywistego rozmieszczenia płytek.

### Skróty

- F: zatwierdzenie całego ruchu według istniejących zasad.
- Y: podgląd powstających słów i punktów, również słów poprzecznych;
  bez wcześniejszego sprawdzania słownika i obchodzenia kary.
- C: odczyt całej ręki.
- 1–7: odczyt pojedynczej płytki z danej pozycji w aktualnie uporządkowanej
  ręce. Bez zaznaczania, zagrywania ani przesunięcia kursora na planszy.
- I: przełączenie sortowania ręki.
- G: wymiana płytek. Strzałki wybierają, Spacja zaznacza, Enter zatwierdza,
  Escape anuluje. Przy istniejącym szkicu najpierw pytanie o jego wycofanie.
- P: pas; zachować zabezpieczenie przed porzuceniem szkicu bez decyzji.
- E: liczebność rąk i woreczka.
- L: przegląd wyłożonych słów.
- S: wyniki, T: czyja tura.

Usunąć tryby H/V/N, układanie przez Shift+literę i Shift+cyfrę, dodatkowe
kombinacje do polskich liter oraz osobne Delete. Nie zastępować ich nowym
menu kontekstowym ani polem do wpisywania słowa. F1 opisuje faktyczną
obsługę bieżącego ekranu, następnie dodatkowe czynności i skróty wspólne,
bez osobnej pozycji dla każdej litery alfabetu. Ctrl+R i pozostałe wspólne
funkcje Game Roomu pozostają bez zmian.

Nie zmieniać słowników, punktacji, kar, czasu, wymiany, rozliczenia partii
ani liczby płytek. Obecne PL i EN mają po 100 płytek, w tym dwa blanki;
ręka ma do siedmiu płytek.

Przy przyszłym wdrożeniu: celowane testy Enter/listy/blanku/Escape,
Backspace pod kursorem i na zatwierdzonym polu, Z/F/Y, sortowania i 1–7,
wymiany, aktualizacji szkicu, pomocy i PL/EN. Sprawdzić brak przechwytywania
edycji czatu i regresji innych powierzchni. To plan testów, nie ich wynik.

## 2. Mexican Train — wszystkie pociągi, świadomy wybór celu

Użytkownik wyraźnie doprecyzował: lista ma pokazywać wszystkie pociągi,
nie tylko pasujące do kostki ani tylko dostępne według bieżących zasad.
Widoczność celu nie oznacza jego legalności.

- Enter na kostce, która ma przynajmniej jedno legalne zagranie, otwiera
  listę wszystkich istniejących pociągów tego rozdania: własny,
  meksykański, potem pozostałych graczy w ich kolejności.
- Pokazywać także cudze zamknięte pociągi oraz pociągi chwilowo niedostępne
  z powodu obowiązkowego dubletu. Nie filtrować listy według dopasowania
  numeru kostki. Bez automatycznego zagrania przy jednym pasującym celu.
- Zachować krótkie etykiety, np. „peterman, 9”, bez słów „stacja” i „koniec”
  z poprzednich korekt. Nie zmieniać zachowania podglądu pod C.
- Enter na pociągu sprawdza aktualny stan i dopiero legalny ruch wysyła
  standardową ścieżką gry. Błędny wybór nie zużywa ruchu, nie zmienia ręki,
  nie dopisuje zdarzenia i pozostawia gracza na liście pociągów.
- Escape wraca do tej samej kostki w ręce, bez zbędnego nagłówka.

Komunikaty odmowy:

1. Obowiązek zamknięcia dubletu ma pierwszeństwo przed odmową z powodu
   zamkniętego pociągu czy samego niedopasowania: „Musisz zamknąć dublet 9
   na pociągu peterman”. Wskazać rzeczywisty numer i właściciela albo
   pociąg meksykański, nie sztywny przykład.
2. Bez takiego obowiązku, przy cudzym zamkniętym pociągu:
   „Pociąg peterman jest zamknięty”.
3. Przy dostępnym pociągu i niedopasowanej kostce:
   „Ta kostka nie pasuje do tego pociągu”.

Wyjątek od otwierania listy: kostka bez żadnego legalnego zagrania daje
od razu „Ta kostka nigdzie nie pasuje”. Jeżeli przyczyną jest obowiązkowy
dublet, wyjaśnić go, np. „Musisz zamknąć dublet 9 na pociągu peterman.
Ta kostka nie pasuje”. Dopasowanie wyłącznie do cudzego zamkniętego
pociągu albo do celu zabronionego przez dublet nie jest legalnym ruchem.

Z i Shift+Z przechodzą wyłącznie po fizycznych kostkach mających aktualnie
co najmniej jedno legalne zagranie, odpowiednio do następnej/poprzedniej.
W Mexican Train tylko ustawiają kursor, również przy jednej takiej kostce;
nie zagrywają automatycznie i nie wybierają pociągu za gracza. Brak legalnej
kostki daje krótki komunikat. Listy widocznych celów nie używać do wyliczania
legalności Z: te dwa zbiory celowo różnią się od siebie.

Zachować reguły otwierania i zamykania pociągów, LIFO obowiązków oraz
potwierdzony wyjątek autora własnej serii, który może zamknąć starszy
dublet. W jego dozwolonej serii nie wymuszać błędnie ostatniego dubletu.
Nie zmieniać botów, punktów, dobierania ani preferencji G/D i Z w Domino.
Wybór pociągu oraz kostki śledzić po stabilnych ID, także po odświeżeniu.

Przy przyszłym wdrożeniu: przypadki pasowania do jednego/wielu/żadnego
pociągu, widoczność zamkniętych, wszystkie odmowy i ich priorytety,
obowiązkowy dublet oraz własna seria, Z/Shift+Z, anulowanie i zmiana stanu
w czasie wyboru, brak nielegalnych zdarzeń sieciowych, PL/EN i F1.
Sprawdzić osobno, że Domino zachowuje dotychczasowe zachowanie.

## 3. Biblios — nowy PR Pajpera do przyszłej integracji

Źródło: [PR #7 „Dodaj grę Biblios”](https://github.com/papierek1997/elten-game-room/pull/7)
autora `dawidpieper`. Odczytano 17 września 2026: PR otwarty, niescalony.
Sprawdzony head: `eee45867b29b9926026499159301cc3e4e038d88`;
baza: `0b2dd09f75b749ba05b3e9d247bee2e4fa9b0a1f`.

Z opisu i wybranych odczytanych fragmentów źródeł wynika:

- Nowa gra karciana Biblios dla 2–4 graczy, ze zwykłym botem.
- Faza rozdzielania kart i faza aukcji; pięć kategorii biblioteki,
  złoto, karty zmieniające wartość kategorii, rozliczenie i remisy.
- Wybór wariantu kary za nieopłaconą licytację.
- Opis zasad, skróty i testy dostarczone w PR.
- Autor celowo nie przygotował tłumaczeń, aby nie powodować konfliktów
  przy scalaniu binarnego katalogu .mo. W przyszłej integracji uzupełnić PL.

Późniejsze wiążące doprecyzowanie: zachować talię i wariant gry z tego PR,
nie zastępować ich składem pudełkowej edycji Biblios. Zgoda na zachowanie
wersji PR nie cofa testów integracji, tłumaczeń ani napraw obsługi zdarzeń
i bota.

PR zmienia sześć plików:

- `__app.rb`;
- nowy `games/biblios.rb`;
- nowy `lib/biblios_strategy.rb`;
- nowy `test/biblios_test.rb`;
- `test/packaged_rules_encoding_test.rb`;
- `test/support/new_games_fixture.rb`.

Zakres przyszłego wdrożenia:

1. Przejrzeć pełny kod i testy oraz poprawność reguł obu wariantów;
   w razie wątpliwości porównać z wiarygodnym opisem zasad. Nie uznawać
   deklaracji autora o testach za własną weryfikację ani audyt strategii.
2. Zintegrować z aktualnymi lokalnymi źródłami 2.0/227, zachowując wszystkie
   nowe gry i poprawki. Nie zastępować całych plików wspólnych ich starszymi
   wersjami z PR, szczególnie rejestracji gier i testu binarnego ładowania.
3. Sprawdzić bota: legalność, wszystkie fazy, dobór kart do płatności,
   ocenę aukcji/kategorii i brak używania niedostępnych informacji. Poprawki
   wynikające z przeglądu mają zachować rozsądny koszt obliczeń, a wspólne
   opóźnienie botów i wykonanie ruchów korzystać z obecnego szkieletu.
4. Uzupełnić polskie komunikaty, zasady, skróty i opcje, zachowując aktualny
   katalog tłumaczeń. Skontrolować jasność komunikatów i brak ujawniania
   prywatnych kart, zgodność ręki/pakietów i pomocy F1 z naszym interfejsem.
5. Celowane testy gry i integracji: replay, rzeczywiste API tasowania
   ELTEN-a, odczyty publicznych zdarzeń, kodowanie przy binarnym ładowaniu,
   obsługa botów i faz aukcji. Sprawdzić obsługę zapisów/cyklu życia oraz
   zgodność nowego ID z katalogiem gier. Nie wykonywać pełnego runnera
   bez osobnego polecenia użytkownika.

Na tym etapie odczytano metadane, listę plików, opis reguł i fragment
strategii. Nie wykonano pełnego audytu PR, testów ani rozgrywki. Nie pobrano
gałęzi do roboczego drzewa, nie scalono PR i nie skopiowano kodu gry.

## Granice i kolejność

Plan: Scrabble, Mexican Train, następnie integracja Biblios po przeglądzie.
Akceptacja planu i dodanie PR nie są poleceniem rozpoczęcia wdrożenia.
Na tym etapie tylko dokumentacja: bez kodu funkcji, testów gry, zmian
serwera, wersji/changelogu, budowania, podpisywania, instalacji i publikacji.
Nie usuwać ani nie cofać wcześniejszych poprawek oczekujących na pakowanie.
