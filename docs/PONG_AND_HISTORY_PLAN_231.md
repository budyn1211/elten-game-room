# Pong, historia i pomoc — następna lista poprawek

21 września 2026. Status: zatwierdzony do wdrożenia.
Użytkownik polecił wdrożyć całość, poprawić zdiagnozowaną konfigurację testu
odzyskiwania quizu oraz zbudować i podpisać nową paczkę 2.0.1.1.
Naprawy testów pozostają wyłącznie w dokumentacji technicznej, nie w
changelogu dla graczy. Bez pełnego runnera, instalacji lub publikacji.
Wcześniejsza poprawka rewanżu pozostaje w źródłach i wejdzie do paczki.

## 1. Lista trybów Ponga

- Zamiast pola wyboru „Arcade” pierwsze ustawienie to lista „Tryb gry”.
- Pozycje: Classic (domyślna) i Arcade, wybierane strzałkami.
- Lista umożliwi przyszłe rozszerzenia, ale teraz nie dodajemy innych trybów,
  w szczególności Showdown.
- Zmiana prezentacji nie zmienia reguł, dotychczasowych ustawień stołu ani
  zgodności jego odtworzenia. Najprościej zachować istniejące wartości
  ustawienia arcade i zmienić kontrolkę oraz etykiety.
- Ujednolicić nazwy w formularzu, Ctrl+R, zasadach i tłumaczeniach PL/EN.

## 2. Nazwa opcji brzmienia band

- Dotyczy istniejącego Shift+E, nie samego Shift.
- Proponowana nazwa: „Brzmienie band”. Opis skrótu: „Zmień brzmienie band”.
- Stany pozostają: wyłączone, szum, tony. Krótkie potwierdzenia używają tej
  samej nazwy; pomoc i zasady zostają ujednolicone.
- To dodatkowe wskazówki dźwiękowe położenia przy bandach, a nie zamiana
  odgłosu uderzenia piłki. Sama zmiana nazwy nie zmienia działania funkcji.
- Użytkownik traktuje nazwę jako propozycję do oceny, nie polecenie usunięcia
  funkcji. Nie usuwać echolokacji bez kolejnego uzgodnienia.

## 3. Pełny odczyt liczb w wyniku

- Nie ucinać nagrania liczby następnym elementem odczytu. Obecny kod
  uruchamia kolejne nagrania co 500 ms i zatrzymuje poprzedni głos.
- Dostosować kolejkę do rzeczywistego końca nagrania, bez blokowania UI.
  Podane przez użytkownika około +200 ms od 11 punktów i +300 ms od 21
  potraktować jako wskazówki do odsłuchu, nie potwierdzone stałe rozwiązania.
- W zasobach są liczby 0–21. Dla wyniku zawierającego 22 lub więcej zapewnić
  pełny, jednoznaczny odczyt syntezą ELTEN-a; nie odtwarzać tylko części wyniku.
  Kod pomija w takim przypadku kolejkę nagrań i zakłada zwykłą mowę, lecz
  użytkownik zgłasza ciszę — sprawdzić rzeczywistą ścieżkę ogłaszania.
- Nie zakładać dostępności nowych nagrań. Inny nagrany głos jest możliwością
  na przyszłość, nie częścią zatwierdzonego zestawu zasobów.
- Nie zmieniać naliczania punktów, transportu ani fizyki przy okazji naprawy
  lektora. Osobno sprawdzić, czy zapowiedź nie jest ucinana na nowym serwisie.

## 4. Nieprzerywane ogłoszenie zwycięstwa

- Pozwolić dokończyć komunikat o wygranej/przegranej przed kolejną zapowiedzią
  wyniku lub automatycznym odczytem pola interfejsu.
- W obecnej kolejce wynik startuje już 300 ms po rozpoczęciu komunikatu
  końcowego. Sprawdzić ten przypadek oraz zamykanie klienta i zmianę fokusu;
  nie uznawać wszystkich możliwych przyczyn za już zdiagnozowane.
- Nie dublować zwycięstwa. Ręczne wyjście/wyciszenie nadal ma być możliwe,
  bez zamrażania interfejsu na czas nagrania.

## 5. Perspektywa obserwatora Ponga

- Umożliwić wybór gracza, z którego strony obserwator słucha meczu.
- Uzgodniona korekta interfejsu: 1 wybiera perspektywę pierwszego gracza,
  2 drugiego, zgodnie z kolejnością uczestników meczu. Bez listy w Ctrl+P
  i bez otwierania dodatkowego okna. To bezpośredni wybór, nie cykliczny
  przełącznik zależny od poprzedniego stanu.
- Skróty działają wyłącznie dla obserwatora w polu gry Ponga. Nie przejmują
  cyfr w czacie, ustawieniach, historii ani innych grach. Zwykły gracz
  zachowuje własną perspektywę.
- Krótkie potwierdzenie: „Perspektywa: [nazwa gracza]”. Skróty opisać w F1
  dla obserwatora i w zasadach. Ponowny wybór nie restartuje meczu ani audio
  wyniku i nie odtwarza ponownie już usłyszanych zdarzeń.
- Wybór lokalny: zmienia orientację dźwięków i kolejność odczytu punktów,
  nie sterowanie paletkami, stan meczu, właściciela ani uprawnienia.
- Nie przedstawiać zwycięstwa obserwowanego gracza jako własnego zwycięstwa
  obserwatora; wynik pozostaje związany z rzeczywistymi uczestnikami.
- Obecna domyślna perspektywa w kodzie to miejsce 0, czyli pierwszy gracz,
  niekoniecznie administrator. Zachować taki start do ręcznego wyboru.
- Wybór utrzymywać podczas wymian i odświeżeń; przy zmianie składu zweryfikować
  obecność wskazanej osoby. Administrator-obserwator nie jest trzecim graczem.

## 6. Historia i F1 jako tekst tylko do odczytu

Zmiana wspólna dla Game Roomu, nie tylko Ponga. Nie modyfikuje F1 poza
aktywnymi oknami Game Roomu ani natywnych ustawień skrótów ELTEN-a.

- Historię prezentować w wielowierszowym polu tylko do odczytu. Zachować
  oddzielenie zdarzeń, możliwość czytania literami/słowami/wierszami oraz
  zaznaczania i kopiowania tekstu. Nie udostępniać edycji historii.
- F1 otwiera analogiczne pole tekstowe: jeden skrót w osobnym wierszu,
  zachowana kolejność pomocy (gra, bieżący ekran, funkcje ogólne) i brak
  duplikatów. Treść nadal pochodzi z rzeczywistych definicji skrótów.
- Enter i Escape zamykają pomoc, przywracając poprzednie pole i pozycję.
- Nowe wpisy historii nie przesuwają kursora ani zaznaczenia podczas
  przeglądania starszego tekstu; na końcu można nadal śledzić nowe wpisy.
  Nie odczytywać automatycznie całej zawartości przy każdej aktualizacji.
- Zachować rozróżnienie kategorii: wszystko, gra, czat, zdarzenia pokoju.

Uzgodniony nowy zestaw skrótów historii (zastępuje propozycję z Altem):

- Ctrl+przecinek: poprzedni wpis w wybranej kategorii, np. wiadomość.
- Ctrl+kropka: następny wpis w wybranej kategorii.
- Ctrl+Shift+przecinek: poprzednia kategoria.
- Ctrl+Shift+kropka: następna kategoria.
- Ctrl+Home: pierwszy wpis w wybranej kategorii.
- Ctrl+End: ostatni wpis w wybranej kategorii.

Nie dodawać proponowanych wcześniej skrótów Alt+strzałki ani Alt+Home/End.
Skoki Ctrl+Home/End dotyczą bieżącej kategorii, nie całej wspólnej historii.
Tak jak przejście do poprzedniego/następnego wpisu odczytują całe zdarzenie.
Obsłużyć przecinek i kropkę z modyfikatorami także wtedy, gdy host przekazuje
znaki < i > po naciśnięciu Shift. Zwykłe znaki interpunkcyjne nadal służą
do pisania, a użycie skrótu nie może dopisywać znaków do pola czatu.

Przejście odczytuje całe zdarzenie, również gdy zajmuje kilka wierszy.
W polu historii ustawia także kursor przy tym zdarzeniu; użyte z pola gry
nie przenosi fokusu z gry do historii. Zwykłe strzałki, Shift+strzałki,
Ctrl+strzałki i Ctrl+Shift+strzałki pozostają do standardowej pracy z tekstem.
Dotychczasowe kombinacje historii Shift/Ctrl+Lewo/Prawo trzeba zastąpić,
bo kolidują z zaznaczaniem tekstu i poruszaniem się po słowach. Przed
wdrożeniem potwierdzić brak kolizji nowego zestawu z aktywnymi skrótami hosta;
nie nadpisywać ich globalnie. Zachować natywne pisanie w polu czatu.

## Późniejsza weryfikacja

Tylko celowane regresje: formularz i PL/EN, kolejka głosu dla 10/11/20/21/22
i większych wyników, zakończenie meczu obu stron, obie perspektywy obserwatora,
zmiana składu/rewanż, historia z wielowierszowym wpisem i dopisaniem podczas
czytania/zaznaczenia, nawigacja kategorii, F1 i powrót fokusu, pisanie czatu.
Przy odczytach sprawdzić prawdziwe kontrolki hosta i kodowanie binarnych
źródeł. Test kolejki nie zastępuje odsłuchu nagrań. Żadnych testów ani
zmian działającej partii na etapie samego zapisywania tego planu.
