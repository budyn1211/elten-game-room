# Taboo — projekt gry głosowej

Aktualizacja wykonania: użytkownik zlecił wdrożenie 17 września 2026.
Źródła 2.0/227 zawierają grę i po 500 zredagowanych kart PL/EN.
Kontrola: `RELEASE_2_0_VERIFICATION.md`; pochodzenie kart:
`../content/TABOO_CONTENT_NOTICE.md`. Nie przeprowadzono tur głosowych
z ludźmi. Poniższe ograniczenia „tylko plan” są historycznym zapisem,
zastąpionym nowym poleceniem wdrożenia i podpisania paczki.

Stan: 17 września 2026. Plan zatwierdzony, gotowy do wdrożenia.
Implementacja jeszcze nie została zlecona ani rozpoczęta.

## 1. Zatwierdzony projekt i granice zgody

Użytkownik chce wyłącznie rozgrywkę przez konferencję, inny komunikator
albo rozmowę na żywo ze słuchawkami. Poprosił o dokładny plan i źródła kart.
Nie polecił jeszcze implementacji Taboo ani importu jego danych.

Późniejsze doprecyzowanie użytkownika: brzęczyk zgłoszenia naruszenia ma
używać tego samego dźwięku co powiedzenie UNO lub Makao, czyli `buzzer2.ogg`.
Powiązanie potwierdzono w obecnym `lib/game_sounds.rb`. To uzgodnienie planu,
nie polecenie wdrożenia.

Następnie użytkownik potwierdził wszystkie trzy zadane kwestie:

- 4, 6 albo 8 graczy w dwóch równych drużynach;
- zestawy polski i angielski, docelowo po 500 sprawdzonych kart;
- zatwierdzanie rozliczenia każdej tury przez mastera, z możliwością
  wcześniejszej korekty spornych kart.

Przy kartach polecił wzorować się na istniejących zestawach, aby dobór haseł
i zakazanych słów był sensowny. Nie jest to zgoda na bezkrytyczny import,
kopiowanie komercyjnej talii ani deklaracja wykonania audytu danych.
Po doprecyzowaniu dźwięków użytkownik polecił zapisać cały plan jako gotowy
do wdrożenia. Obejmuje to opisane poniżej zasady, interfejs, ustawienia,
rozliczenie, przygotowanie danych oraz przypisania dźwięków.
Wcześniejszy status propozycji został zastąpiony zatwierdzeniem projektu,
nie poleceniem implementacji. Gotowy plan nie oznacza gotowej gry, talii
ani wykonanych testów. Źródła kart nadal wymagają opisanej kontroli.

Użytkownik przechodzi teraz do trzeciego planu z kolejnymi poprawkami:
[NEXT_FIXES_PLAN.md](NEXT_FIXES_PLAN.md). Nie dopisywać tam domniemanego zakresu.

Nie zmieniać wersji 1.1.10/build 226, nie budować, nie podpisywać,
nie instalować i nie publikować na podstawie tego dokumentu.

## 2. Rozmowa i uczestnicy

Game Room obsługuje karty, role, zegar, wyniki i historię, nie samą rozmowę.
Gracze samodzielnie łączą się na jednej konferencji ELTEN-a lub w innym
komunikatorze. Wszyscy muszą słyszeć opisującego i odpowiedzi jego drużyny,
w tym przeciwnicy kontrolujący zakazane słowa.

Bez przechwytywania mikrofonu, nagrywania, rozpoznawania mowy, automatycznego
oceniania odpowiedzi oraz wymagania konkretnego komunikatora. Zwykły czat
pozostaje dostępny, ale nie jest alternatywnym trybem zgadywania.

Zakładamy osobnego klienta/konto każdego uczestnika, również podczas gry
w jednym pomieszczeniu. Jedna współdzielona klawiatura i przekazywanie jednego
komputera byłyby odrębnym trybem, nie domyślną częścią tego projektu.
Słuchawki chronią odczyt kart przed usłyszeniem przez zgadujących. Nie należy
udostępniać dźwięku systemowego ani obrazu karty. Program nie może zapobiec
przekazaniu hasła przez głośnik, mikrofon czy celowe podpowiadanie.

Uzgodniony zakres liczby osób: 4, 6 albo 8 ludzi, dwie równe drużyny.
Plan nie przewiduje botów.
Użyć istniejącego przydzielania drużyn, nie tworzyć drugiego ekranu ustawiania
składu. Parzysta liczba wynika z uzgodnionego projektu i wspólnego przydziału;
nie twierdzimy, że wszystkie wydania planszowego Taboo zabraniają nierównych drużyn.

## 3. Role i widoczność

W każdej turze jedna osoba opisuje, jej partnerzy zgadują, przeciwnicy kontrolują.
Kolejność drużyn jest naprzemienna, a opisujący zmieniają się kolejno w drużynie.
Losujemy pierwszą drużynę; skład i kolejność zapisujemy w stanie gry.

Opisujący i przeciwnicy otrzymują hasło oraz pięć zakazanych słów.
Zgadujący i obserwatorzy nie mają odczytu aktywnej karty w interfejsie,
skrótach, pomocy, powiadomieniach ani publicznej historii. Mogą odczytywać
wynik, role i czas. Po zakończeniu tury wszystkie wykorzystane karty można
ujawnić w jej rozliczeniu. Niewylosowanych kart nie pokazujemy w historii.

To ograniczenie zwykłego interfejsu, nie obietnica zabezpieczenia przed
zmodyfikowanym klientem analizującym lokalny bank kart i stan odtwarzania.
Nie przedstawiać gry towarzyskiej jako systemu odpornego na oszukiwanie.

## 4. Przebieg tury

Przed turą podać opisującego i zgadującą drużynę. Karta pozostaje zakryta.
Opisujący uruchamia turę Enterem, gdy wszyscy są gotowi. Po krótkim,
trzysekundowym przygotowaniu następują sygnał startu, odsłonięcie pierwszej
karty uprawnionym osobom oraz uruchomienie wspólnego czasu.

Nowa karta jest odczytywana opisującemu i kontrolującym. Można powtórzyć całość
lub pojedyncze pozycje. Czytanie karty i powtórzenia mieszczą się w czasie tury;
nie uzależniamy zegara od tempa syntezatora ani zakończenia lokalnej mowy.

Po usłyszeniu poprawnego hasła opisujący naciska Enter. P pomija trudną kartę.
Przeciwnik zgłasza naruszenie klawiszem B i krótko wyjaśnia je głosowo.
Każde z tych rozstrzygnięć przechodzi do następnej karty w pozostałym czasie,
bez ponownego rozpoczynania zegara i bez dodatkowego zatwierdzania każdej karty.

Zgadujący odpowiadają wyłącznie głosem. Nie muszą wciskać przycisku przy
każdej odpowiedzi. Ich nietrafione propozycje nie są zapisywane ani karane.
Zakaz wypowiadania słów z karty dotyczy opisującego, nie osób zgadujących.

Po sygnale końca zamykamy turę, pokazujemy jej rozliczenie i ewentualne korekty.
Zgodnie z potwierdzeniem użytkownika master zatwierdza rozliczenie każdej tury;
kolejny opisujący rozpoczyna swoją turę dopiero gdy jest gotowy.
Czas między turami nie jest ograniczany.

## 5. Wskazówki i uznawanie odpowiedzi

Klasyczną podstawą jest opisywanie hasła bez niego samego i pięciu zakazanych
słów, ich form oraz znaczących części. Nie podpowiada się gestem, efektami
dźwiękowymi, rymem czy skrótem zakazanego wyrazu. Instrukcja Hasbro opisuje
te ograniczenia i brak kary za błędne zgadywanie:
[zasady klasyczne](https://www.hasbro.com/common/documents/dad288731c4311ddbd0b0800200c9a66/2AA6E9045056900B10CE5D2770FBF05E.pdf).

Doprecyzowanie naszego wariantu: nie literujemy hasła, nie podajemy jego
tłumaczenia i nie obchodzimy zakazu zdrobnieniem lub odmianą. Zakaz części
słowa nie oznacza dowolnego przypadkowego ciągu liter w niezwiązanym wyrazie.
O sensie wypowiedzi rozstrzygają ludzie, nie wyszukiwanie podciągów tekstowych.
Fragment piosenki może być wskazówką słowną, jeśli nie narusza powyższych reguł;
nie dodajemy osobnego wariantu naśladowania dźwięków.

Poprawną odmianę gramatyczną hasła można uznać. Inny wyraz nie staje się
automatycznie poprawny tylko dlatego, że jest skojarzeniem lub bliskoznaczny.
Jednoznaczne równoważne nazwy warto zapisać redakcyjnie przy konkretnej karcie.
Ostateczne zatwierdzenie nadal wykonuje człowiek po usłyszeniu odpowiedzi.

## 6. Punkty i koniec partii

Uzgodniona punktacja:

- odgadnięcie: 1 punkt dla zgadującej drużyny;
- świadome pominięcie: 1 punkt dla przeciwników;
- uznane naruszenie: 1 punkt dla przeciwników;
- niedokończona karta w chwili upływu czasu: 0 dla obu drużyn.

Nie stosować dodatkowego odjęcia punktu drużynie opisującego. Neutralny wynik
karty przerwanej czasem jest jawnym wyborem tego projektu; nie deklarujemy
identycznego rozstrzygnięcia w każdym pudełkowym wydaniu. Zdalny przebieg,
punkty za pominięcie/naruszenie i równe szanse obu drużyn opisują również
[oficjalne zasady gry na konferencji](https://www.hasbro.com/common/assets/Image/Printables/DAD261421C4311DDBD0B0800200C9A66/78216DB2356F4525A29F578AD0A56925/97751D1FE8714FF98F9807128516E74A.pdf).

Zamiast końca natychmiast po osiągnięciu progu punktów stosujemy ustawienie
liczby tur opisywania na osobę, domyślnie 2. Przy sześciu osobach oznacza to
12 tur łącznie, po 6 na drużynę. Każdy ma taką samą liczbę prób.
Wygrywa wyższy wynik po rozliczeniu wszystkich tych tur.

Przy remisie rozgrywamy dogrywkę: po jednej turze każdej drużyny, z następnymi
opisującymi w kolejności. Wyniki porównać dopiero po obu turach. Powtarzać parę
tur, jeżeli nadal jest remis. To nasze doprecyzowanie równości szans, nie
potwierdzenie konkretnego sposobu wyboru opisujących w QC.

## 7. Interfejs i skróty

Aktywna karta jest prostą listą pod strzałkami: hasło, następnie pięć
zakazanych słów. Nie nazywamy jej ręką kart i nie podłączamy mechanizmu Z
ani reguł przesuwania kursora po zagraniu fizycznej karty.
Przejście do nowej karty ustawia tę listę na haśle i czyta nową kartę,
bez odbudowy całego formularza. Nie przechwytuje fokusu z czatu.

Skróty w polu gry:

| Skrót | Działanie |
| --- | --- |
| Enter | Opisujący: start przed turą, odgadnięte podczas tury. |
| P | Opisujący: pominięcie aktywnej karty. |
| B | Przeciwnik: zgłoszenie naruszenia na aktywnej karcie. |
| C | Ponowny odczyt całej karty, tylko dla uprawnionych. |
| 1 | Odczyt hasła, tylko dla uprawnionych. |
| 2–6 | Odczyt kolejnych zakazanych słów, tylko dla uprawnionych. |
| R | Pozostały czas bieżącej tury. |
| S | Wyniki obu drużyn. |
| T | Aktualny opisujący i zgadująca drużyna. |

Zgadujący widzi informację o swojej roli, nie puste pozycje z ukrytej karty.
Kontrolujący nie ma czynnych operacji odgadnięcia i pominięcia. Obserwator
nie może rozstrzygać kart. Menu i dynamiczne F1 pokazują tylko dostępne akcje.
Na ekranie rozliczenia działa zwykła lista wyników kart pod strzałkami.

Ctrl+R pozostaje wspólnym odczytem ustawień. F1, Ctrl+F1, regulacja głośności,
historia i czat korzystają z istniejącego szkieletu. Litery gry nie działają
jako akcje podczas pisania na czacie. Nie zmieniać skrótów innych gier/ELTEN-a.

### Dźwięki — zatwierdzone przypisania

Wszystkie poniższe pliki istnieją już w `Audio/` Game Roomu i są zadeklarowane
w `GameRoomSounds::ASSET_NAMES`. Nie trzeba dodawać nowej biblioteki dźwięków.
Brzęczyk zatwierdzono wcześniej osobno, a pozostałe przypisania wraz
z oznaczeniem całego planu jako gotowego do wdrożenia. Nie zostały wdrożone.

| Zdarzenie | Plik | Odbiorcy |
| --- | --- | --- |
| Rozpoczęcie tury opisywania | `shuffle.ogg` | Wszyscy przy stole, raz na turę. |
| Zatwierdzone odgadnięcie | `replay.ogg` | Wszyscy, jak sygnał poprawnej odpowiedzi używany w Quizie. |
| Świadome pominięcie karty | `skip.ogg` | Wszyscy. |
| Przyjęte zgłoszenie naruszenia | `buzzer2.ogg` | Wszyscy; dźwięk uzgodniony, jak UNO/Makao. |
| Upłynięcie czasu tury | `ding.ogg` | Wszyscy; neutralny sygnał, nie kara ani przegrana. |
| Zwycięstwo w całej partii | `win2.ogg` | Członkowie zwycięskiej drużyny. |
| Przegrana całej partii | `lose3.ogg` | Członkowie przegranej drużyny. |

Odgadnięcie nie oznacza `win1` i `lose1` dla poszczególnych drużyn: wszyscy
słyszą jedno potwierdzenie karty. Koniec pojedynczej tury nie oznacza przegranej.
Obserwator nie otrzymuje dźwięku osobistej wygranej/przegranej.

Nie dodawać osobnego `draw`/`play` do odsłonięcia każdej następnej karty;
sygnał jej poprzedniego rozstrzygnięcia wystarcza. Bez tykania zegara,
dźwiękowego odliczania co sekundę, automatycznego mówienia pozostałego czasu
ani wyniku po każdej karcie. Nie powielać wspólnego sygnału zmiany tury,
jeżeli dla tej samej zmiany został już przypisany powyższy dźwięk.

Dźwięk wynika z przyjętego zdarzenia, raz dla danej odsłony karty, bez
mnożenia przez ponowienia lub kilka zgłoszeń. Korekty i przeglądanie historii
nie odgrywają ponownie sygnałów starych kart. Obowiązują wspólne ustawienia
dźwięków gry i głośności, bez zmiany dźwięków innych gier lub komunikatora.
Po turze zwięzłe podsumowanie: kto zdobył ile punktów oraz wynik łączny.
Treść aktywnej karty nigdy nie trafia do wspólnego odczytu zgadujących.

## 8. Sporne rozstrzygnięcia, opóźnienia i przerwanie

Buzzer nie próbuje automatycznie sprawdzić wypowiedzi. Zgłoszenie od razu
rozstrzyga kartę roboczo i pozwala grać dalej. Spór wyjaśnia się głosowo,
a nie przez zatrzymywanie każdej tury dodatkowymi oknami.

Po turze master może skorygować wynik konkretnej karty po uzgodnieniu z graczami:
odgadnięta, pominięta, naruszenie albo neutralna. Program przelicza punkty;
nie oferuje dowolnego wpisywania sumy. Historia zachowuje poprzedni wynik,
korektę i autora. Program nie potrafi sprawdzić, czy głosowa zgoda naprawdę padła.
Korekty są dostępne do zatwierdzenia rozliczenia, nie zmieniają już zamkniętej
tury w środku kolejnej. Poprawa wyniku nie daje nowej karty ani dodatkowego czasu.

Ta sama ścieżka obejmuje odpowiedź wypowiedzianą przed sygnałem, lecz zatwierdzoną
za późno wskutek sieci. Nie obiecujemy automatycznego ustalenia czasu wypowiedzi.
Ostateczny wynik karty rozstrzygają uczestnicy, nie czas dostarczenia głosu.

Każda akcja wskazuje turę i konkretną odsłonę karty. Powtórzenie wysłania,
przytrzymany Enter, kilku przeciwników naciskających B i opóźnione zdarzenie
nie mogą punktować podwójnie ani rozstrzygać następnej karty. Przy zbiegu buzzera
i odgadnięcia pierwsza przyjęta poprawna akcja jest roboczym rozstrzygnięciem;
ewentualną niesprawiedliwość można poprawić w rozliczeniu.

Czas pochodzi ze wspólnego zegara i zapisanego terminu, nie lokalnego licznika
restartowanego wejściem w okno. Odczyt czasu jest lokalny; nie wysyłać ruchu
co sekundę. Zdarzenia zakończenia muszą być idempotentne, także po reconnect.
Jeśli nie ma łączności, nie potwierdzać graczowi punktu przed przyjęciem akcji.

Na awarię rozmowy przewidujemy jedną jawną czynność mastera „Powtórz turę z powodu
problemu technicznego”, dostępną podczas tury lub jej rozliczenia. Po zgodzie
głosowej unieważnia wszystkie jej punkty i powtarza ją temu samemu opisującemu
z nowymi kartami. Stare odsłonięte karty są zużyte, a unieważnienie widoczne
w historii. Nie używać tego automatycznie przy każdym krótkim opóźnieniu sieci.
Nie obiecuje to zachowania pokoju po jego zamknięciu przez właściciela;
nie zmieniamy globalnego cyklu LiveSession ani migracji właściciela.

## 9. Ustawienia i zapis

Na początek tylko trzy ustawienia właściwe gry:

1. Język kart: polski lub angielski, niezależnie od języka interfejsu.
2. Czas tury: pole liczbowe w sekundach, zakres 30–300, domyślnie 60.
3. Tury opisywania na osobę: pole liczbowe, zakres 1–10, domyślnie 2.

Jeden ogólny zestaw w każdym języku. Kategorie służą redakcji i mieszaniu
tematów, nie wymagają od razu kolejnego menu i dziesiątek wariantów.
Brak trybu tekstowego, botów, rozpoznawania głosu oraz kostki wariantów
z niektórych pudełkowych wydań. Nie pokazywać niepotrzebnego opóźnienia bota.

Prywatność stołu i zaproszenia są wspólne. Lokalny Ctrl+S jest przewidziany dopiero
między turami po zatwierdzeniu rozliczenia. Nie zapisywać aktywnego opisywania
ani niedokończonego sporu. Zapis ma zachować drużyny, kolejność opisujących,
wyniki, zużyte karty, stan talii i jej wersję, bez nagrania rozmowy.
Wznowienie korzysta z obecnego mechanizmu i oryginalnych ludzi, nie z chmury.

## 10. Skąd karty

Uzgodniony zakres pierwszego wydania: zredagowane zestawy Game Roomu,
docelowo 500 kart polskich i 500 angielskich. To zakres przyszłej pracy,
nie istniejące ani już zweryfikowane 1000 kart. Użytkownik wymaga wzorowania
się na istniejących zestawach, nie wymyślania przypadkowych skojarzeń.

Istniejące talie mają służyć jako rzeczywisty materiał porównawczy: dobór
popularnych haseł, siła pięciu ograniczeń i poziom trudności. Dla otwartych
zestawów rozważyć selekcję i adaptację po sprawdzeniu pochodzenia oraz licencji,
z redakcją każdej przejętej karty i oznaczeniem źródła. Własne uzupełnienia
też porównywać jakościowo ze sprawdzonymi przykładami. Nie uznawać słabych
skojarzeń za dobre tylko dlatego, że pochodzą z istniejącego repozytorium.

Karty przygotować partiami: hasło i pięć mocnych, różnych zakazanych słów.
Nie przepisywać kart z pudełkowego Taboo, cudzych skanów ani quizowych pytań.
Warianty językowe opracowywać oddzielnie: popularność hasła, skojarzenia
i naturalne nazewnictwo nie są identyczne po dosłownym tłumaczeniu.

Przykłady własne, poglądowe, nie import gotowej talii:

- Rower: koło, pedał, kierownica, siodełko, jechać.
- Biblioteka: książka, czytać, wypożyczać, czytelnik, półka.

Wyszukano także następujące rzeczywiste źródła:

- [pawelblaszczyk5/tabooo](https://github.com/pawelblaszczyk5/tabooo): repozytorium
  z kartami PL/EN i plikiem licencji MIT. Odczytano licencję i próbkę kart,
  w której występują problemy redakcyjne. Nie potwierdzono niezależnie pochodzenia
  każdej karty; licencja repozytorium nie jest dowodem wykonania takiego audytu.
  Rewizja `0ffb860bdb3753093f040b423bf1debb3cea1b1a`, karty w
  `frontend/src/helpers/card.ts`, [licencja](https://github.com/pawelblaszczyk5/tabooo/blob/0ffb860bdb3753093f040b423bf1debb3cea1b1a/LICENSE).
- [Kovah/Taboo-Data](https://github.com/Kovah/Taboo-Data): baza deklarowana jako
  GPL-3.0, EN/DE, bez polskiego. Odczytano README i dwa pliki przykładowych
  danych EN. Występują karty z mniej niż pięcioma zakazanymi słowami, więc
  wymagają selekcji i opracowania. Rewizja
  `02001345db07d7f440103c35ad9ef1ccf83f8065`, dane `src/data/en/*.json`.
- `monolithpl/taboo-cards`: generator wykorzystujący zewnętrzne bazy skojarzeń,
  nie przyjęta przez nas gotowa talia. Nie zweryfikowano wszystkich warunków
  danych źródłowych; nie rekomendujemy automatycznego importu.

Żadnej z tych talii nie dodano do projektu i nie wykonano pełnego audytu ich
zawartości. To kandydaci na materiał wzorcowy i dopuszczoną warunkowo adaptację,
nie gotowe, wybrane zależności ani automatycznie zatwierdzona zawartość.
Jeżeli przyjmiemy cudze karty, najpierw sprawdzić pochodzenie, zakres licencji,
zachować wymagane oznaczenia autorów i zanotować adaptacje. Nie nazywać wtedy
całości oryginalną talią własną. Oficjalne instrukcje są źródłem reguł,
nie zgodą na skopiowanie komercyjnej kolekcji kart.

## 11. Redakcja danych i integracja

Każda karta przed przyjęciem wymaga kontroli:

- jednoznaczne, znane hasło i naturalna pisownia;
- dokładnie pięć różnych zakazanych pozycji, bez pustych wpisów;
- brak tego samego słowa w kilku odmianach udających pięć ograniczeń;
- sensowne skojarzenia, ale realna możliwość opisania hasła innymi słowami;
- brak niezamierzonej podpowiedzi w treści, błędnego faktu lub krzywdzącego
  stereotypu użytego jako definicja;
- jednolity poziom ogólny, różnorodne tematy i brak duplikatów;
- poprawne oznaczenie autorstwa/adaptacji oraz źródła przy pozycjach zapożyczonych.

Przygotowanie maszynowe nie zastępuje redakcji. Sprawdzić każdą kartę osobno,
a zrozumiałość i trudność potwierdzić próbnymi turami z ludźmi. Same testy
struktury nie dowodzą, że wszystkie skojarzenia są dobre. Nie generować kart
na żywo przez zewnętrzne AI podczas partii.

Użyć istniejącego mechanizmu wersjonowanych zestawów content, ładowanych leniwie
według języka. Każda karta ma stabilne ID; dane UTF-8/NFC. Przykładowe pola:
hasło, pięć zakazanych pozycji, ewentualne równoważne odpowiedzi oraz metadane
redakcyjne. Manifest zestawu wskazuje wersję, sumę kontrolną i licencję.
Klienci muszą uzgodnić zgodną wersję danych przed startem, nie dopiero w turze.

Talię mieszać dla partii, bez powtórzeń do wyczerpania. Przy wyczerpaniu
przetasować ponownie i uniknąć natychmiastowego powtórzenia ostatniej karty.
Ponowne wykorzystanie po wyczerpaniu całej talii opisać w zasadach.

Przesyłać małe zdarzenia rozpoczęcia, wyniku karty, końca tury i korekt,
nie całe talie, nagrania ani liczniki sekund. Użyć zwykłej walidacji aktora,
stanu i replaya Game Roomu. Brak nowej tabeli serwerowej i osobnego transportu.

## 12. Sprawdzenie po ewentualnym wdrożeniu

Plan przyszłej weryfikacji, nie testy wykonane teraz:

- role, brak ujawnienia hasła zgadującym/obserwatorom we wszystkich odczytach;
- układ drużyn i rotacja 4/6/8 osób, równa liczba tur, dogrywka;
- punkty za każde rozstrzygnięcie i korekty bez podwójnego naliczania;
- buzzer kilku osób, zderzenie buzzera z Enterem i końcem czasu, ponowienia;
- brak rozstrzygnięcia następnej karty przez spóźnione lub powtórzone naciśnięcie;
- wspólny zegar, powrót do okna, reconnect i zakończenie przy braku aktywności UI;
- techniczne unieważnienie całej tury, bez odzyskiwania ujawnionych kart;
- zapis wyłącznie w bezpiecznej fazie i zgodne odtworzenie z wersją talii;
- kompletność danych, polskie znaki, PL/EN, brak duplikatów i utrata zgodności;
- celowane sprawdzenie wspólnego UI, czatu, pomocy, dźwięków i informacji stołu;
- ręczna rozgrywka co najmniej czterech ludzi, także jakość odsłuchu przez
  słuchawki i obsługa spornego końca czasu.

Na etapie tego planu odczytano źródła i dokumentację, ale nie wdrożono
gry, nie importowano talii i nie uruchamiano testów ani prawdziwej partii.
