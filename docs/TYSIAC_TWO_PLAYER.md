# Tysiąc dla dwóch osób i komunikaty o beczce

Zakres zatwierdzony 19 września 2026. Wariant trzyosobowy pozostaje domyślny.
Nowy wariant wymaga aktualizacji u obu uczestników; nie dodano gry czteroosobowej
ani drużyn. Nie zmieniano dotychczasowych zasad mariaży, licytacji lub beczki.

## Rozdanie i punkty

- Ustawienie wariantu wybiera dokładnie dwóch albo trzech uczestników.
- Dwa musiki po dwie karty oznaczają dziesięć kart na rękę i dziesięć lew.
  Dwa musiki po trzy oznaczają dziewięć kart i dziewięć lew. Domyślnie trzy.
- Zwycięzca licytacji wybiera zakryty pierwszy lub drugi musik. Dopiero wybrany
  musik jest ujawniany i trafia do ręki. Niewybrany pozostaje zakryty.
- Z dwunastu kart rozgrywający odkłada kolejno dwie albo trzy; przeciwnik nie
  otrzymuje kart i nie poznaje treści odłożeń z komunikatów lub historii.
- Domyślnie zaznaczony checkbox przekazuje punkty z niewybranego musiku i kart
  odłożonych zwycięzcy ostatniej lewy, przed oceną kontraktu i zer. Po odznaczeniu
  nikt nie otrzymuje tych punktów. Nie są naliczane mariaże z odłożonych kart.
- Poddanie przed pierwszym odłożeniem zachowuje dotychczasową regułę co najmniej
  60 punktów dla przeciwnika. Nie przyznaje fikcyjnej ostatniej lewy.

## Interfejs i zgodność

Opcje dwóch osób są warunkowe. Wybór musiku to jedna lista pod strzałkami
i Enterem. Odkładanie używa istniejącej ręki kart: zachowuje sortowanie,
stabilne ID, kursor, skróty oraz rozróżnienie prywatnego i publicznego opisu.
Pierwsze zagranie przyjmuje kontrakt tak jak dotychczas. Nowe fazy są zapisywane
i odtwarzane przez zwykłe zdarzenia, bez zmian wspólnego transportu.
Zapis obejmuje wybór musiku, częściowe odłożenie, kontrakt i niepełną lewę;
wznowienie mapuje także identyfikator bota na nowy stół.

Trzyosobowe zdarzenia bez nowych opcji nadal stosują stare rozdanie i RNG.
Nie dodano limitu czasu ani automatycznego wyboru musiku dla człowieka.
Prywatność jest taka jak w dotychczasowym Tysiącu: interfejs nie ujawnia ręki,
ale deterministyczne rozdanie ze wspólnego ziarna nie jest kryptograficznym
ukryciem kart przed zmodyfikowanym klientem.

## Bot

Bot wybiera zakryty musik bez podglądania obu zestawów. Planer ocenia całe
zestawy odrzucanych kart, a nie oddaje ich w symulacji przeciwnikowi. Losowane
próbne rozdania oddzielają cudzą rękę, niewybrany musik i zakryte odłożenia.
Uwzględniają publiczne karty wybranego musiku i kolory, których przeciwnik
już nie ma. Symulacje naliczają premię za ostatnią lewę tylko przy włączonej
opcji. Dotychczasowy skrót nakazujący szybkie zagranie asa nie zastępuje oceny
końcówki, gdy trzeba zachować atut na ostatnią lewę i dodatkowe punkty.
Liczby próbek i strategia trzech osób są zachowane; nie deklarujemy pomiaru
siły gry na podstawie kilku testów ani identycznego czasu obliczeń na sprzęcie.

## Beczka

Nowe wejście tworzy jeden wpis historii i komunikat „gracz jest teraz na
beczce”. S dopisuje „na beczce” wyłącznie do aktualnie objętych nią graczy,
nie zmieniając sortowania i wartości wyników. Po opuszczeniu oznaczenie znika.
Shift+S nadal podaje pozostałe szanse. Dotyczy dwóch i trzech osób.

## Sprawdzenie

Celowane testy `tysiac_two_player_*` obejmują oba rozmiary i oba musiki,
oba ustawienia punktacji, komplet 24 różnych kart, prawidłowe lewy, poddanie,
niedozwolone i spóźnione akcje, odtwarzanie zdarzeń, zapis z nowym ID bota,
izolację wiedzy planerów i końcówkę wymagającą zachowania asa atutowego.
`tysiac_barrel_messages_test` sprawdza pojedynczy odczyt, S i opuszczenie beczki.
Ponawiane są również celowane regresje wariantu trzyosobowego, ręki i pomocy.
Binarna próba używa rzeczywistych powierzchni, słownika ELTEN-a i PL/EN/fallback.
Nie jest to ręczna gra na żywych klientach ani odsłuch urządzenia.

Wyniki końcowe wydania: `../diagnostics/release-2-0-1-1/SOURCE.json` i
`PACKAGE.json` względem repozytorium. Te pliki, a nie samo przygotowanie
tej dokumentacji, potwierdzają zaliczenie kontroli oraz podpisanie paczki.
Wydanie ma wersję 2.0.1.1/build 230 i obejmuje także wcześniejsze poprawki
zegarów, UI, Farkle i pustego stanu opóźnienia bota. Changelog ma osobny nagłówek;
nie skopiowano całej listy 229 jako nowych zmian. Bez instalacji lub publikacji.
