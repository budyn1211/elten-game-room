# Przegląd komunikatów po buildzie 211

Aktualizacja: użytkownik zatwierdził poniższy zakres; wdrożono go w buildzie
212, z wyłączeniami Yahtzee opisanymi niżej. Dodatkowo zatwierdzono własną
kwotę i czas decyzji aukcji Monopoly, automatyczne bankructwo bez dostępnej
likwidacji majątku oraz poprawkę powtórzonych skrótów F1. Szczegóły wdrożenia:
`MESSAGES_AND_MONOPOLY_212.md`. Dalsza część zachowuje historyczną treść planu,
w tym jego pierwotny status oczekiwania na zgodę; nie oznacza to blokady zmian.

11 września 2026. Notatka planistyczna, bez zmian kodu, tłumaczeń, numeru
wersji ani paczki. Użytkownik polecił zachować zakres Monopoly do zmian oraz
przejrzeć komunikaty pozostałych czterech nowych gier i przedstawić propozycje.
Nie jest to polecenie wdrożenia w tej turze.

## Monopoly — zakres zapisany do późniejszego wdrożenia

1. Usunąć automatyczne dopisywanie gotówki/salda do kart i podatków. C ma
   jednoznacznie podawać własną gotówkę, S finanse z nazwami graczy.
2. Karty Szansy i Kasy Społecznej opisywać jako zdarzenia konkretnego gracza,
   nie polecenia „otrzymujesz”, „zapłać”, „przejdź” rozsyłane wszystkim.
   Wskazać źródło karty i skutek bez powtórzeń oraz zbędnego salda.
3. Podatki i opłaty: płacący, kwota i powód. Jeśli wymieniany jest odbiorca,
   odpowiada rzeczywistemu bankowi lub puli Darmowego parkingu.
4. Czynsz: płacący, odbiorca, kwota, nieruchomość; wspólne krótkie brzmienie
   dla automatycznego/ręcznego pobrania, bez zdublowania żądania i płatności.
   Rezygnacja wskazuje właściciela i osobę zwolnioną z zapłaty.
5. Oddzielić rzeczywistą wpłatę od należności i pozostałego długu. Odtworzono
   komunikat „zapłacono 160”, gdy odbiorca dostał 20, a 140 zostało długiem.
   Późniejsza spłata ma wskazywać płacącego, odbiorcę i kwotę.
6. Płatności dla/od wszystkich podawać zbiorczo (po X od każdego pozostałego
   gracza), bez osobnego salda/straty każdego bota. Wyjątki jak brak środków
   opisać osobno; nie ukrywać ważnych transferów dotyczących innych osób.
7. Rzut i przemieszczenie przed skutkami pola. Rozróżnić przejście przez
   Start od podwójnej premii za zatrzymanie na nim; ogłaszać premię dwóch
   jedynek. Parking: gracz i wypłacona pula, bez wypłaty zera.
8. Więzienie: rozróżnić trafienie, odwiedziny, pozostanie i wyjście dubletem,
   kartą lub opłatą; przy płatnym wyjściu podać koszt.
9. Oferta zakupu identyfikuje gracza, nieruchomość, kolor i cenę bez
   powtarzania danych. Przyciski nadal Kup/Nie kupuj. Zachować potwierdzenie
   zakupu i ukończenia grupy koloru.
10. Handel: jawne strony oferty, nazwy i kolory nieruchomości oraz kwoty.
    Publicznie nie używać względnych „oddaj/otrzymaj”. Po akceptacji krótkie
    podsumowanie faktycznego transferu; przy odmowie kto odrzucił czyją ofertę.
11. Aukcje: początek, nieruchomość i kolor, kolejne oferty z graczem i kwotą,
    pasowanie, wynik albo zakończenie bez sprzedaży.
12. Podglądy: hotel zamiast technicznego poziomu 5, brak budynków dla stacji
    i przedsiębiorstw, „wartość majątku” zamiast niejasnej „wartości”.
    Oczekiwanie wskazuje rodzaj decyzji, a bankructwo odbiorcę pozostałych
    nieruchomości albo ich powrót do banku.

Krótkie potwierdzenia budowania/sprzedaży budynków i zastawów z 211 zostają.
Listy zarządzania zachowują ceny i stan budynków. Nie wyciszać wszystkich
operacji botów: czynsz lub wymiana może dotyczyć pieniędzy człowieka.
Zmiany mają dotyczyć jasności komunikacji, nie zasad ani ekonomii.

## Pozostałe cztery gry — propozycje do zatwierdzenia

Poniższy zakres jest wynikiem przeglądu kodu gier, wspólnych kontrolek
i polskiego katalogu `locale/PL.mo`. Nie został jeszcze zatwierdzony do
wdrożenia. Nie zmieniono kodu gier ani tłumaczeń.

### UNO

1. Komunikat zwykłego dobierania ma podawać rzeczywistą liczbę kart, także
   przy opcji dobierania aż do karty pasującej. Obecnie `apply_draw` używa
   liczby tylko przy karze; w pozostałych przypadkach zawsze mówi o jednej
   karcie. Nadal nie odczytywać tożsamości dobranych kart, także dobierającemu.
2. G ma opisywać rzeczywistą karę i jej adresata. Dla ruletki kolorów
   `pending_draw == 0` nie oznacza braku kary: należy podać wymagany kolor.
   Podczas buzzera oczekiwanie ma wskazywać naciskanie B, a nie zwykłą turę
   jednego gracza. Nie dodawać przypominania przy każdym odświeżeniu.
3. Wybór po siódemce w wariancie 0–7 ma mieć nagłówek wyboru gracza do
   wymiany rąk, nie „Wybierz kolor”. `surface_spec` obecnie daje wszystkim
   deklaracjom ten sam nagłówek, mimo że `card_choices` zwraca także graczy.
4. Kwestionowanie +4: wskazać kwestionującego, autora karty, wynik i osobę
   dobierającą karę. Nie ujawniać przy tym innych kart z ręki.
5. Dopowiedzieć tylko nieoczywiste skutki specjalnych kart: nową stronę Flip
   i zmienioną kartę/kolor stołu, kierunek przekazania rąk po zerze oraz liczbę
   dodatkowo odrzuconych kart przy karcie odrzucenia koloru. Nie przywracać
   ogólnego „Karta na stole” po każdym zwykłym zagraniu ani dublować kolejki.
6. Użytkownik doprecyzował komunikat nieudanej intercepcji: ma brzmieć
   wyłącznie „Za późno!”, bez dopowiadania punktów ani opisu kary.
   Kara 3 punktów pozostaje i jest naliczana według dotychczasowych zasad.
   Nie zmieniać warunków intercepcji ani pozostałego zachowania z 211.

Zachować rozdzielenie zwycięzcy rundy od punktów poszczególnych graczy,
odpadnięcia z rundy od odpadnięcia z partii oraz zwięzłe wyniki pod S.
Nie zmieniać kar, dźwięków ani reguł.

### Poker — oba warianty

1. All-in ma jednoznacznie podawać właśnie wpłaconą kwotę, nie sumę
   `contributions` z całego rozdania. Podbicie rozróżnia „o” i „do” w tym
   etapie licytacji. Łączna inwestycja w rozdanie nadal dostępna pod I;
   nie dopisywać po każdej akcji stanu pozostałych żetonów.
2. Ogłaszać rzeczywiste wpłaty obowiązkowe z nazwami płacących (mała/duża
   ciemna albo ante stosownie do wariantu) i krótko zmianę ich poziomu.
   Nie nazywać pełną wpłatą sytuacji, gdy gracz miał tylko część wymaganej
   kwoty. To komunikacja istniejących potrąceń, nie zmiana ich naliczania.
3. Wyniki mają mówić „otrzymuje z puli”, rozróżniać pulę główną, boczne
   i podział między remisujących. Obecnie `showdown` sumuje wszystkie wypłaty
   dla gracza i podaje tylko ogólną nazwę układu. Doprecyzować układ, np.
   para dwójek; przy równych typach wskazać istotną kartę rozstrzygającą.
   Nie ujawniać kart graczy, którzy spasowali. Wygraną bez porównania układów
   nazwać wprost: pozostali spasowali.
4. W dobieranym brak wymiany opisać jako zachowanie wszystkich kart, nie
   wymianę zera. Zachować istniejące ogłaszanie etapów: pierwsza licytacja,
   wymiana, druga licytacja; w Hold'em flop/turn/river z nowymi kartami.
5. Naprawić odczyt cyfr 3–5 w dobieranym: obecnie wskazują nieistniejące
   karty wspólne i mówią, że karty brak, mimo pięciu kart na ręce. Zachować
   mapowanie 1–7 w Hold'em. Jest to błąd odczytu, nie tylko redakcja tekstu.
6. Doprecyzować komunikaty niedozwolonej stawki/wymiany według rzeczywistej
   przyczyny: minimum/maksimum, limit podbić, brak środków, limit wymiany
   lub zmieniona kwota wyrównania. Nie zastępować każdej odmowy jednym
   „Ta akcja licytacji nie jest teraz dostępna”. Nie zmieniać walidacji zasad.
7. Dodatkowe zgłoszenie użytkownika: R odczytuje za dużo informacji.
   Proponowane uproszczenie: „Podbij o:” i pole własnej kwoty, bez wyliczania
   wyrównania, obu zakresów i łącznego kosztu przy każdym otwarciu. Kwota nadal
   oznacza podbicie ponad wyrównanie; zachować domyślne minimum i sprawdzanie
   dozwolonych granic. Nieprawidłowa kwota daje krótki komunikat o granicy.
8. Dodatkowe zgłoszenie użytkownika: G ma mówić „Nie masz układu”, gdy
   ocena wynosi wyłącznie wysoką kartę, zamiast np. „Wysoka karta: dama”.
   Przy parze lub lepszym układzie podawać konkretny układ. Brak własnych
   kart nadal opisywać jako brak kart. Zmiana dotyczy wyłącznie odczytu G:
   nie usuwać wysokiej karty z oceny rozdań, porównań i rozstrzygania remisów.

Punkty 7–8 dopisano do planu po uwadze użytkownika. Bez wdrażania kodu.

### Yahtzee

1. Zapis do kategorii i dodatkową premię podawać osobno, np. „papierek
   zapisuje 10 w dwójkach. Premia za kolejne Yahtzee: 100”. Tak samo raz
   ogłosić uzyskaną premię 35 za górną część arkusza. Dziś punktacja rośnie
   o premię, ale historia zapisu kategorii jej nie wyjaśnia. Nie czytać
   automatycznie wszystkich nowych sum po każdym zapisie.

Na polecenie użytkownika usunięto na razie z zakresu wcześniejsze punkty 2 i 3:
podpowiedź dotyczącą Jokera oraz rozdzielenie wyniku arkusza od sumy całej gry.
Nie wdrażać tych dwóch propozycji. Pozostał wyłącznie punkt o komunikatach premii.

Zachować uzgodnione odczyty „Zachowujesz …, rzucasz ponownie …”, Spację
powtarzającą aktualny stan, wybór pojedynczych kości według wartości oraz
brak publicznych komunikatów o każdej lokalnej zmianie zaznaczenia.

### Makao

1. Rozróżnić deklaracje: as zmienia kolor, walet żąda wartości, joker
   reprezentuje konkretną kartę. Podawać znaczenie zamiast samego
   „Deklaracja: …”; dostosować nagłówek listy wyboru. C dla jokera powinno
   podawać także reprezentowaną wartość, nie tylko słowo „joker” i kolor.
2. G ma odróżniać karę oczekującą na przyjęcie/odbicie od przyjętych już
   kolejek postoju. Obecnie po przyjęciu trzech tur `skip_penalty` spada do
   zera, `skip_turns` nadal zawiera dwie, lecz G mówi „Nie ma aktywnej kary”.
   Podać kto ma dobrać ile kart, komu grozi postój oraz ile własnego postoju
   zostało; nie generować ciągłych przypomnień przy każdym odświeżeniu.
3. P powinno rzeczywiście odczytywać przygotowany pakiet w kolejności
   zaznaczenia albo „Nie przygotowano pakietu”. Obecnie odczytuje wyłącznie
   stałą wskazówkę „Przygotowane karty są oznaczone w ręce”. To drobne
   uzupełnienie odczytu istniejącej kontrolki, bez zmiany zagrywania pakietu.
4. Odmowa zagrania ma wskazywać pierwszą kartę pakietu lub konkretną karę.
   `validate_packet` sprawdza `cards.first`, a obecny tekst mówi, że ŻADNA
   karta pakietu nie może rozpocząć ruchu. Nie sugerować automatycznej zmiany
   kolejności ani zmieniać warunku legalności.
5. Poprawić odmianę liczby kart i tur, np. „dobiera dwie karty” zamiast
   „dobiera 2 kart”; wskazywać karne dobieranie, gdy właśnie ono nastąpiło.
   Dla kary za brak Makao zachować wskazanie obu graczy. Polska wersja już
   zawiera słowo „kart”, mimo że brakuje go w angielskim szablonie.

## Wspólne założenia komunikatów

- Publiczne wydarzenia wskazują gracza, a przy przekazaniu także odbiorcę.
  Prywatne odczyty i lokalne podpowiedzi mogą mówić „Twoje”, „zachowujesz”.
- Nie dodawać automatycznych odczytów całych rąk, wszystkich sald i list
  graczy po każdej akcji. Ważne skutki botów nadal są publiczne.
- Poprawić polskie formy kart/punktów/tur w tych czterech grach. Sprawdzić
  faktyczne tłumaczenia, nie wnioskować wyłącznie z angielskich szablonów.
- Publiczne poprawki mają brzmieć zgodnie w mowie i historii; podpowiedzi
  wyboru, odczyt pakietu i stanu kości pozostają lokalne.
- Bez nowych ustawień, odpytywania, zmian transportu, zasad i punktacji.

## Weryfikacja przeglądu (bez zmian produkcyjnych)

Oprócz odczytu źródeł i polskiego katalogu wykonano krótkie próby funkcji
na stanie w pamięci, bez uruchamiania klientów i bez pełnego zestawu testów:

- Poker: przy bieżącej wpłacie 100 i sumie wpłat 300 komunikat all-in
  podaje 300; przy pięciu kartach dobieranego odczyty 3–5 mówią o ich braku.
- UNO: ruletka kolorów z aktywnym kolorem i `pending_draw: 0` zwraca
  komunikat braku obowiązku dobierania.
- Yahtzee: zapis dwójek 10 z premią kolejnego Yahtzee podnosi wynik o 110,
  a historia mówi wyłącznie o 10 w kategorii.
- Makao: przyjęcie trzech tur pozostawia dwie przyszłe kolejki postoju,
  ale odczyt G zwraca brak aktywnej kary.

Paczka 211 jest niezmieniona. Wdrożenie nowych propozycji wymaga zatwierdzenia.
