# Kolejne poprawki po buildzie 233

Status: pięć punktów wdrożonych i sprawdzonych w źródłach 21 września 2026.
Szczegóły, potwierdzona przyczyna błędu składu oraz granice testów:
[POST_233_IMPLEMENTATION.md](POST_233_IMPLEMENTATION.md).
Użytkownik potwierdził Shift+góra/dół: zamiana z sąsiadem bez zawijania,
drużyna według miejsca i kursor podążający za osobą. Poniższe opisy
„tylko plan” zachowują wcześniejszą historię uzgodnień, nie aktualny stan.
Bez nowej paczki, instalacji, publikacji, GitHuba ani zmian serwera.

## 1. Ctrl+F4 — bieżący ping

Uzgodniony zakres: skrót ma podawać bieżący ping globalnie w obrębie
Game Roomu, na jego ekranach. Użytkownik skorygował pierwszą wiadomość:
nie chodzi o globalny skrót całego ELTEN-a.

Do sprawdzenia przed wdrożeniem:

- Jakiego połączenia dotyczy pomiar i jakie dane udostępnia obecne API;
  nie utożsamiać opóźnienia serwera ze zmierzonym RTT do gracza w Communications.
- Czy Ctrl+F4 koliduje z istniejącą obsługą na którymś ekranie Game Roomu.
- Jak uzyskać aktualny odczyt bez blokowania interfejsu i co podać przy
  niedostępnym lub nieaktualnym pomiarze zamiast fikcyjnego zera.

Propozycja krótkiego komunikatu: „Ping: 42 ms.” Szczegóły pomiaru i komunikatu
pozostają do dopracowania, nie są jeszcze wdrożone.

## 2. Usunięty bot pozostaje w drużynie

Zgłoszenie użytkownika: usunięcie bota się udaje, ale wygląda na to, że
pozostaje on przypisany do drużyny. Przyczyna nie jest jeszcze potwierdzona:
trzeba rozróżnić pozostawione przypisanie w stanie stołu od nieodświeżonej
listy w interfejsie. Nie ustalono jeszcze, której gry dotyczy zgłoszenie.

Przy realizacji sprawdzić wspólną obsługę usuwania botów, przypisania drużyn
oraz aktualizację składu u uczestników. Po usunięciu bot nie może pozostawać
członkiem drużyny ani być liczony do jej składu, również przy ponownym
rozpoczęciu partii. Na razie zapis zgłoszenia, bez wdrażania poprawki.

## 3. Skróty historii również w polach czatu

Ctrl+przecinek i Ctrl+kropka oraz ich odpowiedniki z Shiftem mają działać
również w polu wpisywania/wysyłania wiadomości i w historii czatu
na ekranach Game Roomu. Nie wyłączać ich tylko dlatego, że fokus znajduje
się w jednym z tych pól.

Zachować dotychczasowe znaczenie:

- Ctrl+przecinek / Ctrl+kropka — poprzedni / następny wpis bieżącej kategorii.
- Ctrl+Shift+przecinek / Ctrl+Shift+kropka — poprzednia / następna kategoria.

Podczas pisania odczyt historii nie ma przenosić fokusu, zmieniać treści
wiadomości ani jej kursora lub zaznaczenia. Zwykłe wpisywanie przecinków,
kropek i pozostałych znaków pozostaje bez zmian. Przy wdrożeniu uwzględnić
wspólną obsługę skrótów i pomoc dla tych pól. Na razie tylko plan.

## 4. Więcej makr stołów i szybki wybór przypisania

Rozszerzyć dotychczasowe makra szybkiego tworzenia stołów na widgecie
do 30 pozycji, w trzech grupach po dziesięć, w kolejności:

- Ctrl+1–Ctrl+0 — dotychczasowe dziesięć makr.
- Alt+1–Alt+0 — kolejne dziesięć.
- Shift+1–Shift+0 — ostatnie dziesięć.

Alt i Shift są tu samodzielnymi modyfikatorami, bez dodatkowego Ctrl.
Zachować obecne przypisania Ctrl+1–Ctrl+0; nowe pozycje początkowo
nieprzypisane. Na widgecie każde przypisane makro nadal tworzy stół
z zapisanymi ustawieniami gry i prywatności.

W oknie ustawiania makr (Ustawienia → Widget) naciśnięcie danego skrótu
ma od razu przenosić na odpowiadającą mu pozycję listy i odczytywać jej
bieżące przypisanie. Dotyczy to również makr jeszcze nieprzypisanych.
Nie tworzy wtedy stołu ani automatycznie nie otwiera edycji; Enter nadal
przypisuje lub edytuje wybrane makro przez wybór gry i ustawień stołu.
Zachować dotychczasowy natychmiastowy zapis przypisania, niezależny
od Anuluj w głównym oknie ustawień.

Przed wdrożeniem sprawdzić kolizje z obsługą hosta, rozpoznawanie
Shift+cyfra oraz zakres działania, bez przejmowania pisania w innych
polach lub skrótów podczas gry. Uaktualnić pomoc i opis przypisywania.
Na razie wyłącznie plan, bez zmiany zapisanych makr ani kodu.

## 5. Łatwiejsze przypisywanie do drużyn — Shift+góra/dół

Zachować obecny sposób ustawiania drużyn i dodać szybką obsługę przez
Shift+strzałka w górę / Shift+strzałka w dół, wzorowaną na QC Playroom.
Ma ułatwiać przestawianie wybranego gracza lub bota przy układaniu drużyn
bez każdorazowego otwierania osobnego wyboru.

Kierunek integracji: zwykłe strzałki wybierają osobę na liście, a Shift
ze strzałkami przestawia wybraną osobę. Fokus powinien pozostawać na niej,
a odczyt jasno wskazywać wynik i przynależność do drużyny. Używać wspólnej
obsługi drużyn, nie osobnego rozwiązania dla każdej gry. Zachować kontrolę
uprawnień, liczebności oraz dotychczasowe zatwierdzanie zmian; nie zmieniać
składu rozpoczętej partii przez ten skrót. Uwzględnić również punkt 2:
usunięty bot nie może pozostawać w składzie ani na liście przydziału.

Przed wdrożeniem potwierdzić dokładne zachowanie wzorca QC: przestawianie
pozycji względem podziału na drużyny, zachowanie na granicach i ewentualne
zamienianie osób. Nie zakładać bez sprawdzenia, że każde naciśnięcie oznacza
bezpośrednio zmianę drużyny. Przegląd publicznych opisów potwierdził
przestawianie graczy góra/dół przy wyborze drużyn w kliencie WWW, ale nie
wyjaśnił wszystkich szczegółów obsługi klawiaturą:
[dokumentacja klienta WWW QC, Mobile gestures](https://nidza07.github.io/QC-docs/webclient.html#mobile-gestures).
Na razie tylko plan, bez wdrażania.
