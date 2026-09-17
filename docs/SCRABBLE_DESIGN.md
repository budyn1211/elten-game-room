# Scrabble — zaakceptowany projekt

Nowsze uzgodnienie, 17 września 2026: użytkownik zaakceptował uproszczenie
interfejsu opisane w [kolejnym planie](POST_227_GAME_CHANGES_PLAN.md#1-scrabble--jeden-sposób-układania-liter).
Enter na polu → lista płytek → Enter, Backspace usuwa płytkę pod kursorem,
1–7 tylko odczytuje rękę. Bez wpisywania słów, menu kontekstowego i trybów
H/V/N. Ten nowy plan zastępuje starszą propozycję sterowania poniżej,
ale nie został jeszcze wdrożony; silnik i reguły bez zmian.

Aktualizacja wykonania: 17 września 2026 użytkownik zlecił wdrożenie.
Silnik, interfejs i oba słowniki są zaimplementowane w źródłach 2.0/227.
Sprawdzenie punktów i ograniczenia opisuje `RELEASE_2_0_VERIFICATION.md`.
Poniższe wzmianki „tylko plan”, „nie pobrano” i o braku zgody opisują
wcześniejszy etap uzgodnień, nie bieżący stan. Bez instalacji/publikacji.

Data: 17 września 2026. Baza: lokalne źródła po czterech planach 2.0,
nadal z numerem 1.1.10/build 226. Użytkownik wskazał Scrabble jako kolejną
grę i poprosił na razie o zaplanowanie na podstawie przesłanego opisu QC,
z uwzględnieniem polskiego słownika SJP. Nie ma polecenia implementacji,
zmiany wersji, budowania, podpisywania, instalowania ani publikacji.

Użytkownik zaakceptował plan 17 września 2026 i zlecił sprawdzenie w sieci
końcowego rozliczenia oraz angielskiej bazy słów. Akceptacja dotyczy planu,
nie rozpoczęcia implementacji. Poniżej nadal rozróżniono potwierdzone
źródła, nasze ustalenia i nową rekomendację angielskiego słownika.
Cztery wcześniejsze plany pozostają wdrożone; ten projekt nie rozszerza
ich wykonanej weryfikacji.

Decyzje użytkownika: bez bota, od początku polski i angielski. Zaakceptowany
układ to jedna gra Scrabble i pierwszy wybór „Język gry” w ustawieniach
stołu. Nie otwierać ponownie uzgodnień tylko dlatego, że wcześniejsza
wersja dokumentu nazywała je propozycjami. Nie utożsamiać jednak akceptacji
naszego projektu z potwierdzeniem nieprzetestowanych szczegółów QC.

## 1. Źródła i granice potwierdzenia

- Przesłany przez użytkownika opis angielski: zasady, punktacja, wymiana,
  blokada partii, podstawowe skróty oraz propozycja słownika SJP.
- [QC, opis angielski](https://game.qcsalon.net/en/scrabble): odpowiednik
  przesłanego materiału. Bezpośredni odczyt zwracał błąd narzędzia; treść
  była dostępna w wyniku wyszukiwarki. Nie sprawdzano żywego klienta QC.
- [QC, opis włoski](https://www.qcsalon.net/it/scrabble): wyszukiwarka
  udostępniła dokładniejszą sekcję o sześciu reakcjach na błędne słowo,
  limicie czasu i grze samodzielnej. To opis, nie test zachowania serwera.
- [QC, opis hiszpański](https://www.qcsalon.net/es/scrabble): dodatkowe
  skróty I/P/Y/L/Z. Rozbieżności językowych nie uznawać za rozstrzygnięte.
- [SJP, słownik growy](https://sjp.pl/sl/growy/) i
  [zasady dopuszczalności SJP](https://sjp.pl/sl/dp.phtml).
- [Polska Federacja Scrabble, reguły](https://pfs.org.pl/reguly.php):
  punkt odniesienia dla polskiego zestawu i nieopisanych szczegółów,
  nie powód do cichego zastępowania wariantu QC zasadami turniejowymi.
- [Wordnik, otwarta lista do gier](https://github.com/wordnik/wordlist)
  i [jej licencja MIT](https://github.com/wordnik/wordlist/blob/main/LICENSE):
  rekomendowane źródło angielskie, sprawdzone 17 września 2026.
- [Oryginalna dokumentacja ENABLE2K zachowana w kopii](https://github.com/BartMassey/wordlists/blob/main/README-enable2k.txt):
  porównany starszy, publicznie udostępniony słownik, nie wybór domyślny.
- [NASPA, licencjonowanie list](https://www.scrabbleplayers.org/w/Licensing):
  oficjalna lista turniejowa to odrębny produkt; publiczna dostępność
  przypadkowej kopii nie daje zgody na jej dołączenie do programu.

## 2. Zakres i dwa języki gry

Zakres zaakceptowanego planu: osobna gra Scrabble, 2–4 graczy i obserwatorzy,
plansza 15 × 15. Zgodnie z decyzją użytkownika bez botów. Nie zmieniać
globalnego limitu stołu 8.
Możliwość gry solo jest opisana we włoskiej instrukcji QC, ale nie należy
do obecnego zakresu, podobnie jak 5–8 osób.

Użytkownik wybrał dwa zestawy od pierwszej implementacji: polski oraz
angielski. Każdy obejmuje własny słownik, alfabet, liczebność i punktację
płytek. Dla polskiego przewidziano 100 płytek, w tym dwa blanki. Dokładne
tabele obu zestawów zweryfikować przed kodowaniem; nie stosować
angielskiego zestawu z samym polskim słownikiem. Polskie znaki pozostają
odrębnymi literami. Rekomendacja angielskiej listy i granice jej zgodności
są opisane niżej; nie obiecywać identyczności z QC ani listą turniejową.

Uzgodnione miejsce w interfejsie: jedna pozycja „Scrabble” na liście
gier, a po jej wybraniu w zwykłym formularzu ustawień stołu pierwsze
pole „Język gry”: „Polski”, „Angielski”. Nie tworzyć dwóch gier ani
osobnego okna języka przed formularzem. Pozostałe opcje są dalej pod Tabem.
Wybór wspólny dla stołu, ustalony przed rozpoczęciem partii i utrwalony
przy zapisie; niezmienny w trwającej partii. Ctrl+R i zasady ustawionego
stołu podają ten język i źródło słownika. To nie przełącznik języka
interfejsu: polski interfejs może obsługiwać angielską partię i odwrotnie.

Od strony projektu wykorzystać istniejące profile GameRoomContent
w content/languages.rb (pl-PL oraz en), wspólny formularz i mechanizm
wersjonowanych zestawów. Słowniki i rozkłady liter umieścić jako odrębne
dane w content, z własnym typem danych dla gry słownej, nie w tłumaczeniach
locale, bazach pytań ani dwóch kopiach silnika Scrabble. Obecna ogólna
obsługa treści dodaje pola języka i zestawu; przy jednym słowniku na
język nie pokazywać w Scrabble zbędnej jednopozycyjnej listy zestawu.
Potrzebne dostosowanie nie może zmienić wyboru zestawów Quiz Party.

SJP udostępnia obecnie archiwum sjp-20260901.zip i wskazuje licencje GPL 2
oraz CC BY 4.0. Do projektu proponowana jest ścieżka CC BY 4.0:
oznaczenie źródła, wersji, licencji i dokonanych przekształceń danych.
[Warunki CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Nie pobierano ani nie analizowano jeszcze pełnego archiwum słownika.

To ma być jawnie „Polski — SJP”, nie OSPS i nie obietnica identyczności
z oficjalną listą turniejową. Przyjmować gotową listę do gier, nie dowolne
hasła ze strony internetowej i nie sam słownik podstawowych form.
Odmiany słów rozstrzyga lista. Nie odrzucać wpisów na podstawie domysłów,
np. dlatego, że poprawny wyraz pospolity przypomina nazwisko.

### Angielski — wynik sprawdzenia bazy

Rekomendacja po sprawdzeniu: „Angielski — Wordnik”, otwarta lista do gier,
nie płatny Wordnik Games Dataset zawierający definicje i inne metadane.
Licencja tego repozytorium to MIT: pozwala dołączyć i przetworzyć dane
z zachowaniem informacji o autorze i pełnego tekstu licencji. Nie wymaga
wywoływania płatnego API podczas gry. To nowa rekomendacja źródła,
nie informacja o wdrożonym słowniku ani osobna decyzja użytkownika.

Sprawdzono w pamięci pełny plik `wordlist-20210729.txt` z wersji
`46e6215d0f90356afe9c8ba4be347e7e98cb425c` repozytorium Wordnika:

- 198 422 wpisy, bez duplikatów; każdy to małe litery a–z w cudzysłowach;
- po usunięciu wyłącznie cudzysłowów formatu i ograniczeniu do długości
  2–15 pozostają 194 152 słowa; odpadają dwa jednoliterowe i 4 268 dłuższych;
- oryginał ma 2 366 872 bajty, SHA-256
  `bfd1b4eb4ade1ba81e84c7e24248b9a1aecec9d9baa427453b367a83e30e0451`;
- [konkretny plik źródłowy](https://github.com/wordnik/wordlist/blob/46e6215d0f90356afe9c8ba4be347e7e98cb425c/wordlist-20210729.txt).

To kontrola struktury całej listy i próbka zawartości, nie niezależny
audyt językowy każdego słowa. Są m.in. `qi`, `za`, `blog`, `selfie`,
`color` i `colour`. Lista nie jest jednak pełną listą brytyjskich form:
np. `favorite` występuje, a `favourite` nie. Nie dodawać automatycznie
brakujących form, nazw własnych ani odmian przez reguły programu.
Wersja pochodzi z 2021 roku; nie przedstawiać jej jako aktualnej listy
NWL/Collins z 2026 roku ani jako sprawdzonego słownika QC.

Porównany ENABLE2K ma 173 528 unikalnych słów, w tym 169 266 długości
2–15. Autorzy pozwalają używać go w grach, lecz sprawdzona wersja nie
zawiera m.in. `qi`, `za`, `blog` i `selfie`. Dlatego na start rekomendowany
jest Wordnik. Nie tworzyć bez uzgodnienia mieszanki obu list ani listy
wyjątków. Oficjalny słownik turniejowy wymagałby oddzielnego wyboru
i sprawdzenia warunków jego licencji.

Sprawdzanie lokalne, bez żądań SJP podczas gry. Ustalić wersję i skrót
danych dla całej partii; rozbieżny słownik oznacza jasną odmowę udziału,
nie różne decyzje klientów. Nie aktualizować słownika w trakcie partii.
Wspólna normalizacja Unicode, wielkości liter i długości 2–15, bez
usuwania diakrytyków. Przed startem wykrywać brak/uszkodzenie danych.
Języki inne niż polski i angielski wymagają osobnego uzgodnienia.

## 3. Układanie i tura

- Każdy dostaje siedem płytek; po poprawnym ruchu uzupełnia do siedmiu,
  o ile wystarcza woreczka. Propozycja startera: wspólne losowanie.
- Pierwszy wyraz obejmuje środek H8. Nowe płytki jednego ruchu leżą
  w jednym wierszu albo kolumnie, bez luk w końcowym słowie; luki mogą
  wypełniać litery już znajdujące się na planszy. Nie gra się po skosie.
- Kolejny ruch łączy się z istniejącą krzyżówką. Nie wymagać przecięcia
  wcześniej istniejącej litery w głównym słowie: legalne są też układy
  równoległe, o ile wszystkie utworzone styki tworzą poprawne słowa.
- Sprawdzać wszystkie nowo powstałe/przedłużone wyrazy, nie tylko główny.
  Pojedyncza płytka bez sąsiada w jednej osi nie jest osobnym słowem.
- Zatwierdzonych liter nie wolno ruszać. Przed zatwierdzeniem gracz
  może dowolnie poprawiać własny szkic i wycofać nowe płytki.
- Blank: jawny wybór litery z alfabetu zestawu; zero punktów przez resztę
  partii, także po przedłużeniu słowa. Odczyt np. „A, blank, 0 punktów”.
  Nie używać blanka zamiast brakującej litery bez decyzji gracza.

## 4. Punktowanie

Podstawa z materiału: suma wszystkich wyrazów utworzonych w tym ruchu;
litery wspólne liczą się w każdym takim wyrazie. Premie liter i słów
działają tylko przy pierwszym przykryciu pola. Najpierw premie liter,
potem mnożniki słów; kilka premii słownych mnoży się. Nie mnożyć przez
siebie premii liter leżących na różnych polach. Blank nie daje punktów
za literę, ale może uruchomić premię słowną.

Przyjęte doprecyzowanie: +50 wyłącznie za użycie siedmiu płytek z ręki
w jednym ruchu, po pozostałych obliczeniach. Potwierdza to sekcja premii
w regułach PFS. Zapis „wszystkie litery” w opisie QC nie rozstrzyga
końcowej ręki złożonej np. z dwóch płytek; nie ogłaszać osobnego
potwierdzenia zachowania QC dla tej sytuacji.

Ruch układający same blanki może legalnie zdobyć 0 punktów: nadal zmienia
planszę i zeruje licznik blokady. Nie utożsamiać zerowej punktacji z pasem.

## 5. Wymiana, pas i błędne słowa

Wymiana: wybrać 1–7 płytek na jednej liście z polami wyboru pod strzałkami,
zatwierdzić jedną operację, otrzymać tyle samo płytek i zakończyć turę.
Zgodnie z przesłanym wariantem QC przy siedmiu lub mniej w woreczku
wymiana jest zabroniona, czyli dostępna od ośmiu. Nie zastępować tego
progu inną regułą bez uzgodnienia.

Opis QC mówi o zwrocie płytek przed losowaniem nowych; opis PFS podaje
odwrotną kolejność. W zaakceptowanym planie trzymać się materiału użytkownika: zwrot,
przetasowanie, losowanie, a więc możliwość ponownego otrzymania zwróconej
płytki. Akceptacja tego projektu nie oznacza, że kolejność została
sprawdzona w aplikacji QC. Nie zmieniać jej przy okazji końcowej punktacji.

P pomija turę. Jeśli istnieje szkic, przed pasem/wymianą jasno zaoferować
jego wycofanie; nie zatwierdzać części liter ani nie gubić ich ze stojaka.

Opis włoski QC wymienia sześć reakcji na zatwierdzenie niedozwolonego słowa:

1. Popraw ruch, bez kary.
2. Zakończ turę, bez kary punktowej.
3. Popraw ruch, odejmij 5 punktów.
4. Zakończ turę, odejmij 5 punktów.
5. Popraw ruch, odejmij 10 punktów.
6. Zakończ turę, odejmij 10 punktów.

Uzgodniony plan: jedna lista wyboru, domyślnie poprawianie bez kary. Przy
odrzuceniu wszystkie nowe płytki wracają na te same miejsca stojaka;
nie losować uzupełnienia i nie zużywać premii planszy. Kara raz za
zatwierdzoną próbę, nie od każdego złego wyrazu — to rozstrzygnięcie
naszego planu, nie wynik testu QC. Powtórzenie dostarczenia tej
samej akcji nie może ponownie naliczać kary.

Przyjęte rozróżnienie: lokalny błąd obsługi lub geometrii (zajęte pole,
brak litery, wyjście poza planszę) nie jest karanym błędem słownikowym.
Nie resetować thinking time po błędnej próbie. Podgląd punktów nie
sprawdza słownika, aby nie omijał reguły kary. Bez podpowiedzi słów.

## 6. Ustawienia i zakończenie

Kolejność ustawień: język gry (polski/angielski), reakcja na
błędne słowo z sekcji 5, czas na turę (0 = bez ograniczenia).
Nie dodawać ustawień bota ani jego opóźnienia — bot został usunięty
z planu przez użytkownika.
Prywatność, obserwator, Ctrl+R i zasady stołu pozostają wspólne.

Timeout w przyjętym planie: wycofać szkic i oddać turę bez dobierania ani
dodatkowej kary punktowej. Obowiązuje jeden zegar tury, również podczas
wyboru blanka i poprawiania ruchu. Nie zmieniać wspólnej synchronizacji
czasu ani samowolnie wprowadzać zegara na całą partię.

Z materiału użytkownika: koniec po opróżnieniu woreczka i stojaka jednego
gracza albo blokadzie — brak możliwości wymiany i trzy pełne obiegi
stołu bez zmiany planszy. Robocza ścisła interpretacja: 3 × liczba graczy
zakończonych tur bez wyłożenia, nie trzy pojedyncze ruchy przy dowolnej
liczbie osób. Próba odrzucona z pozostawieniem tury nie zwiększa licznika.
Gdy wymiana jest możliwa, sam limit pasów z tego opisu nie zamyka partii;
nie dodawać cichej zmiany zasad, mimo ryzyka celowego pasowania bez końca.

### Końcowe rozliczenie — sprawdzone w źródłach

[Reguły PFS, „Zakończenie gry”](https://pfs.org.pl/reguly.php) potwierdzają
odejmowanie wartości niewykorzystanych płytek i premię dla opróżniającego
stojak. Uzupełniamy w ten sposób lukę opisu QC, bez twierdzenia, że
zweryfikowano to w żywej grze QC.

1. Najpierw normalnie rozliczyć ostatni zatwierdzony ruch, w tym premię
   za siedem płytek, jeśli przysługuje.
2. Każdemu odjąć sumę wartości płytek pozostałych na jego stojaku.
   Blank jest wart zero; nie stosować mnożników pól planszy.
3. Jeżeli przy pustym woreczku ktoś opróżnił stojak, dodać mu sumę
   odjętą wszystkim pozostałym. Nie jest to dodatkowe stałe 50 punktów.
4. Przy końcu przez blokadę każdy tylko traci wartość własnego stojaka;
   nikt nie otrzymuje wartości cudzych liter.
5. Klasyfikację ustalić po korektach. Opróżnienie stojaka nie gwarantuje
   zwycięstwa. Zachować możliwość wyniku ujemnego, nie obcinać do zera.

Przykład obliczeniowy: A kończy z 200 punktami, B ma 190 i litery za 8,
C ma 170 i litery za 5. Wyniki końcowe: A 213, B 182, C 165. Przy blokadzie
i literach A za 4, B za 8, C za 5, z tych samych wyników wyjściowych
otrzymaliby odpowiednio 196, 182 i 165. Rozliczenie wykonywać tylko raz,
również przy ponownym dostarczeniu zdarzenia lub odtworzeniu partii.

Wspólne zwycięstwo przy równym najwyższym wyniku pozostaje wyborem naszego
planu; nie przypisywać tej decyzji instrukcji PFS. Nie przenosić z PFS
innego progu pasów ani kolejności wymiany: powyższe badanie uzupełnia
końcowe rozliczenie, nie zastępuje zasad przebiegu z materiału QC.

## 7. Interfejs planszy i stojaka

Wykorzystać istniejącą bazę GridBox/OrientedGridBox; dodać powierzchnię
gry słownej ze stojakiem i lokalnym szkicem, a nie przerabiać zachowanie
wszystkich planszówek lub oznaczać płytki jako rękę kart.

Stałe współrzędne A–O i 1–15, wiersz 1 na górze; bez obracania dla
drugiego gracza. Strzałki przechodzą po całej planszy. Pole czyta np.
„H8, puste, podwójne słowo”, „H8, K, 2 punkty” albo „H8, A, blank”.
Przy zajętym polu nie ogłaszać wykorzystanej premii jako nadal dostępnej.
Roboczą płytkę odróżniać od już zatwierdzonej. Bez odczytu całego
nagłówka planszy i stojaka po każdej literze.

Klawisze zaakceptowanego planu, działające tylko w polu gry:

| Klawisz | Działanie |
| --- | --- |
| Strzałki | Przegląd pól planszy |
| H / V | Pisanie poziome / pionowe |
| N | Powrót do nawigacji, bez kasowania szkicu |
| Shift+litera | W pisaniu: ułóż tę literę; w nawigacji: następne jej wystąpienie na planszy |
| 1–7 | Odczyt pozycji stojaka |
| Shift+1–7 | W pisaniu: połóż płytkę z tego miejsca; w nawigacji: porządkowanie stojaka |
| Enter | Alternatywny wybór płytki z listy dla bieżącego pustego pola |
| Delete | Zdejmij roboczą płytkę spod kursora |
| Backspace | Cofnij ostatnie dołożenie |
| Z | Wycofaj cały szkic, bez oddawania tury |
| F | Zatwierdź ruch i sprawdź wszystkie powstałe słowa |
| G | Wymiana płytek |
| P | Pas |
| C | Odczytaj dostępne litery stojaka |
| I | Kolejność stojaka: własna, alfabetyczna, samogłoski/spółgłoski |
| Y | Układane słowa i potencjalna punktacja, bez oceny słownikowej |
| L | Lista zatwierdzonych słów z pozycją i kierunkiem |
| E | Liczba płytek w woreczku i na stojakach graczy |
| S / T | Wyniki / czyja tura |

Przyjęte szczegóły: podczas pisania automatyczne
przejście w wybranym kierunku, z pomijaniem zatwierdzonych liter bez
nadpisywania ich. W nawigacji Enter kładzie bez automatycznego przejścia.
Przy porządkowaniu stojaka pierwsze Shift+numer wskazuje pozycję,
drugie zamienia ją z drugą. Nie przestawiać zajętych przez szkic miejsc;
zachować stabilność numerów do zatwierdzenia/cofnięcia. I przy szkicu
powinno wymagać jego cofnięcia, nie cicho zmieniać indeksy płytek.

Nie wymagać trudnych kombinacji do wpisywania polskich liter: Shift+numer
i lista pod Enterem zapewniają pełną obsługę, a tekstowe skróty trzeba
sprawdzić z układem Polski programisty i AltGr. Blank wybierany jawnie
ze stojaka otwiera wybór reprezentowanej litery.

Z w tej grze cofa szkic, nie korzysta z nawigacji legalnych kart:
Scrabble nie jest karcianką. Nie dodawać automatycznego wyboru legalnego
słowa ani podpowiadania anagramów. F1, Ctrl+R, Ctrl+F1, głośność, historia
i czat mają pozostać wspólne. S oznacza wynik, nie licznik pionków.
W trybie obserwatora udostępniać tylko publiczną planszę i informacje.

## 8. Komunikaty i sieć

Krótki publiczny komunikat zatwierdzonego ruchu: kto, słowo/słowa,
położenie i zdobyte punkty. Dokładne składniki w historii i podglądzie,
bez wielokrotnego odczytu całej planszy. Wymiana publicznie podaje liczbę,
nie tożsamość wymienianych i dobranych płytek. Nie ogłaszać przeciwnikom
prywatnego szkicu. Informacje o blanku zawsze dostępne w odczycie pól.

Nawigacja, układanie szkicu, podgląd i cofanie są lokalne. Zatwierdzenie,
wymiana lub pas przechodzą przez zwykły action_for/ActionPlan, wspólną
walidację i replay. Nie pisać do sieci osobno za każdą literę.
Identyfikować fizyczne płytki, nie wyłącznie litery. Wynik, nowe słowa
i dobranie wyliczać z tej samej wersji danych, nie ufać kwocie od klienta.
Przed implementacją dobrać zwarty format do rzeczywistego limitu zdarzeń;
nie obiecywać jednego surowego rekordu bez pomiaru kodowania blanka/pól.

Ponowienia akcji, timeout i wyjście z okna nie mogą zdublować dobrania,
kary ani ruchu. Potwierdzony nowy stan nie może przenosić starego szkicu
do cudzej/następnej tury. Czat i synchronizacja nie są zatrzymywane
podczas układania. Zapis partii tylko między zatwierdzonymi operacjami,
bez prywatnego szkicu i operacji w locie; nie gubić szkicu przy odmowie.
Archiwum zawiera identyfikator reguł, słownika, dane planszy/blanków
odtwarzane z historii i czas potrzebny przy wznowieniu; nie kopię listy
słów. Brak historycznej wersji słownika ma dawać jasny komunikat.

## 9. Bez botów — decyzja użytkownika

Nie implementować bota, planera ani generatora najlepszych ruchów.
Gra deklaruje brak obsługi komputerów przez istniejący mechanizm
supports_bots?, co wyklucza też wspólne ustawienie ich opóźnienia.
Nie udostępniać dodawania komputera do tego stołu. Nadal potrzebny jest
szybki, oszczędny pamięciowo słownik do sprawdzania wyrazów ludzi;
sprawdzanie słowa nie oznacza wyszukiwania ruchu lub anagramów.

## 10. Stan uzgodnień i dalsze kroki

Użytkownik zaakceptował plan, w tym jedną grę z wyborem polskiego albo
angielskiego w ustawieniach stołu, brak botów i opisany interfejs.
Końcową korektę sprawdzono w regułach PFS. Wordnik jest nową rekomendacją
angielskiej bazy po jej zbadaniu, z jawnymi ograniczeniami z sekcji 2.

Przed implementacją utrwalić wybór angielskiego źródła oraz zweryfikować
dokładne rozkłady i wartości liter PL/EN. Nie dopisywać trybu solo,
5–8 graczy, nowych słów ani pełnej zgodności ze słownikami turniejowymi.
Nadal potrzebne jest polecenie rozpoczęcia wdrożenia; sama akceptacja
planu i zlecenie badań nie upoważniają do zmian kodu lub wydania paczki.

## 11. Przyszła kontrola, nie testy już wykonane

- Liczebność/wartości płytek, dwa blanki, zachowanie pełnego zestawu
  przy losowaniu, wymianie i replayu w obu językach; polskie znaki
  i ich kodowanie oraz brak mieszania polskich i angielskich danych.
- Otwarcie, jeden kafelek, oba kierunki, mostek, układ równoległy,
  nielegalne luki/rozłączne fragmenty i każde słowo poprzeczne.
- Wszystkie premie, iloczyny, blank na premii, brak ponownego naliczania,
  siedem płytek a krótsza końcówka, legalny ruch za zero.
- Granice woreczka 0/6/7/8, pasy, licznik blokady i końcowe punkty:
  wyjście i blokada, 2–4 osoby, blank, wynik ujemny, remis i finisher,
  który nie wygrywa; brak ponownej korekty przy replayu.
- Każda polityka błędu, powtórne dostarczenie, timeout i aktualizacja UI.
- Polskie litery, AltGr, stabilne miejsca stojaka, szkic/cofanie, czat,
  fokus, obserwator, F1 i brak dodatkowych żądań podczas układania.
- Wspólny słownik/wersja, brak i uszkodzenie danych, zapis/wznowienie,
  rozłączenie w czasie zatwierdzenia, granice wartości zdarzeń.
- Brak możliwości dodania bota i brak jego ustawień. Koszt wczytania
  słowników i sprawdzania słów, niezależność języka partii od interfejsu.
  Potem rzeczywiste klienty, bez twierdzenia, że sam test modelu dowodzi
  płynności ELTEN-a.

Na etapie tego dokumentu zmieniono wyłącznie dokumentację. W ramach
badań pobrano do pamięci listy Wordnika i ENABLE2K oraz sprawdzono ich
format, liczby wpisów i wskazane przykłady; nie dodano słowników do gry.
Nie wykonano testów Scrabble, ponieważ gra nie jest jeszcze zaimplementowana.
