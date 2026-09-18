# Statki: dźwięki, wybór rozstawienia i fokus formularza

Zmiany do ponownie budowanej wersji 2.0.1/build 229, 18 września 2026.
Użytkownik zatwierdził dwa dostępne dźwięki trafienia zamiast trzech.
Późniejsze polecenie zatwierdziło przebudowanie i podpisanie tej samej 229.

## Rozstawianie floty

Po rozpoczęciu partii każdy niegotowy gracz dostaje wybór „Losowo” albo
„Ręcznie”. Losowanie od razu zapisuje prywatną flotę i wysyła jej istniejące
64-znakowe zobowiązanie; nie ujawnia współrzędnych innym uczestnikom.
Uwzględnia oba zestawy floty i dopuszczalność stykania się statków.
Ponowienie niezakończonego wysłania korzysta z już zapisanego ustawienia.
Nie trzeba potwierdzać dziesięciu automatycznie ustawionych statków.

Ręczny wybór otwiera dotychczasową planszę, bez zdarzenia sieciowego.
Odświeżenie zachowuje tryb, postawione statki i zaznaczony początek następnego.
Zatwierdzona flota nie wraca do pytania. Nowa partia pyta ponownie.
Obserwator nie dostaje pytania, a komputer nadal ustawia się automatycznie.
Pozostałe reguły i sposób sprawdzania ukrytych flot są bez zmian.

## Dźwięki i kolejność zdarzeń

- Strzał: losowo `rocket_launch1`, `rocket_launch2` lub `rocket_launch3`.
- Trafienie i zatopienie: losowo `hit_ship1` lub `hit_ship2`.
- Chybienie: `rocket_miss`.

Pliki użytkownika skopiowano bez edycji z Dokumentów/freesound. Ich długości
to odpowiednio około 3,366 / 1,800 / 3,266 sekundy, 2,862 / 3,157 sekundy
i 3,352 sekundy. Te liczby służą dokumentacji, nie są zakodowanymi pauzami.
Pochodzenie i ograniczenia informacji licencyjnych: `THIRD_PARTY_NOTICES.md`.

`GameRoomEventPresentation` jest lokalną kolejką widocznych stanów, mowy
i efektów. Włącza ją tylko `Battleship#serial_event_presentation?`.
Dotychczasowy zegar formularza sprawdza `Sound#finished?`; nie ma `sleep`,
czekania blokującego UI ani dodatkowego odpytywania serwera po dźwięku.
Następna odpowiedź/strzał czeka na ukończenie poprzedniego nagrania.
Wynik partii i możliwość restartu nie pojawiają się przed końcem jego efektu.

Odbiór i potwierdzanie zdarzeń nadal pracują na najnowszym stanie. Jeśli
szybszy klient już wykona kolejny ruch, lokalna prezentacja go kolejkuje,
nie odrzuca. Czat, przeglądanie plansz, historia i zamknięcie ekranu pozostają
obsługiwane. Nowe ruchy gracza, odpowiedzi automatyczne i decyzje bota
czekają tylko na lokalne dźwięki. Zmiana etapu prezentacji korzysta z już
odebranego snapshotu; nie generuje nowego żądania sieciowego.

Wyłączony, brakujący lub niedostępny dźwięk nie tworzy sztucznej pauzy.
Dla uszkodzonego uchwytu jest awaryjne zwolnienie po długości nagrania
plus dwie sekundy (maksymalnie 120 s; brak odczytu długości: 30 s).
Wyjście lub nowa sesja usuwa kolejkę i zamyka tylko jej własne uchwyty.
Odtworzenie historii nie odgrywa starych dźwięków. Inne gry zachowują
równoczesne efekty. Losowanie nagrań nie korzysta z losowości silnika gry.

## Początek tworzenia stołu

Po wybraniu dowolnej gry fokus otwiera instrukcję obsługi formularza,
zamiast pomijać ją i wskazywać „Stół prywatny”. Pierwszy Tab przechodzi
na to pole, następne na ustawienia gry. Nie zmieniono kolejności pól,
prywatności, edycji Ctrl+X ani zachowania przy zmianie języka/zestawu.

## Kontrole i wydanie

Testy celowane obejmują wybór i pełne ustawienie w rzeczywistym kodzie
ekranu, oba zestawy floty, ponowienie zapisu, prywatność, nieudany zapis,
kolejkę z kontrolowanymi uchwytami audio oraz formularz i transport na
symulowanych klientach. Sprawdzają napływ zdarzeń podczas nagrania,
chat z polskimi znakami, brak dodatkowych odczytów po zakończeniu dźwięku,
blokadę ruchu podczas prezentacji i późniejszą automatyczną odpowiedź.
Osobno: binarne źródła, rzeczywisty słownik ELTEN-a, kontrolki hosta,
regresje pozostałych gier, oba manifesty i niezmienione bajty nagrań.

Końcowe wyniki są zapisywane poza repozytorium w
`diagnostics/battleship-audio-setup-229/SOURCE.json` oraz `PACKAGE.json`.
Nie utożsamiać symulacji formularzy i transportu z ręczną grą żywych klientów
ani z odsłuchem rzeczywistego urządzenia. Nie uruchamiać pełnego runnera.
Changelog zachowuje 24 wcześniejsze punkty i dopisuje trzy w PL/EN,
pod tym samym nagłówkiem 229. Poprzednią podpisaną paczkę zachować osobno.
Bez instalacji, publikacji, GitHuba, serwera i zmian profili.
