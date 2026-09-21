# Pong — uzgodnione poprawki z audytu źródeł

20 września 2026. Wdrożone w źródłach; bez nowej paczki, podpisu, instalacji,
publikacji, zmian serwera i profili użytkownika. Wersja/changelog bez zmian.
Materiał porównawczy pozostaje poza repozytorium. Nie uruchamiamy oryginalnego
Pythona ani pełnego runnera testów.

## Zakres zatwierdzony

- R01: sieciowa prędkość Nightmare.
- R02: limit wczesnego automatycznego odbicia, niezależny od obrony przy bramce.
- R03: pamięć puszczenia ruchu i tolerancja obrony.
- R04–R06: panorama, nieliniowe tłumienie dalszego kanału, aktualizacja bandy.
- R07/R12: lokalny automat i regulatory własnej paletki, przeciwnika, lektora;
  jeden panel w ustawieniach Game Roomu oraz przy stole (menu i Ctrl+P).
- R11: mysz zawsze w aktywnym polu Ponga, bez przełącznika M; ochrona fokusu.
- R18: bazowa głośność lektora 50%; paletki nadal 50%/20%.
- R25: uporządkowane wejście w pierwszy serwis po gotowości obu stron.
- R28: zachowanie reszty kroku dźwiękowego bota po punkcie.

## Zachowanie po zmianie

Nightmare między ludźmi używa bazowej prędkości 0,323. Wczesne automatyczne
odbicie ma limit czterech jednostek; nie zmniejsza to osobnej tolerancji
obrony przy bramce. Puszczenie ruchu jest pamiętane przez 220 ms, a dodatkowa
tolerancja zależy od czasu i odległości nadlatującej piłki od bramki.

Panorama używa pierwiastkowej krzywej oryginału, z obcięciem do pełnych
procentów i ograniczeniem do zakresu stereo. Dalszy kanał jest tłumiony
potęgą 1,4; nasycenie uwzględnia końcową głośność. Dogasający dźwięk bandy
zmienia położenie i głośność razem z piłką, bez ponownego uruchamiania
nagrania i bez zmiany początkowego tonu uderzenia.

Automatyczne odbijanie jest osobiste, domyślnie wyłączone. Nie ma już tej
opcji w regułach stołu. Trzy osobiste regulatory mają zakres 0–200%,
domyślnie 100%; działają ponad bazowymi proporcjami własnej paletki 50%,
przeciwnika 20% i lektora 50%. Wspólny panel jest dostępny w ustawieniach
Game Roomu, z menu stołu Ponga i pod Ctrl+P. Ustawienia są zapamiętywane
lokalnie, nie narzucają wartości przeciwnikowi. Szybki panel nie pobiera
sieciowych preferencji powiadomień. Odczyty w czasie gry korzystają z pamięci,
a nie z pliku przy każdej klatce. Panel podtrzymuje obsługę własnego klienta,
ale klawisze używane w formularzu nie sterują równocześnie paletką.

Mysz działa zawsze w aktywnym polu Ponga, bez przełącznika M. Czat, menu,
pomoc, panel ustawień i inne aplikacje nadal odbierają jej sterowanie grą.
Nie dodano globalnych przechwytujących hooków ani ukrywania wskaźnika.

Pierwszy serwis między ludźmi staje się dostępny po gotowości obu stron
i trzech sekundach. Najpierw podawane są ustawienia, następnie po
nieblokującej przerwie 120 ms serwujący i zapowiedź startu. Przeciągnięcie
pojedynczej klatki interfejsu nie skleja tych komunikatów. Mecz z botem nie
dostaje tego pierwszego odliczania; odstęp po kolejnych punktach pozostaje
bez zmian. Niewykorzystana część dystansu i czas ostatniego odgłosu kroku
bota przechodzą do następnej wymiany. Nowy mecz lub nowa epoka kanału
zerują tę pamięć.

## Granice

Nie zmieniamy modelu lokalnego lotu, zatwierdzania punktów LiveSessions,
odnawiania kanału, interwału pozycji, zegara fizyki ani rozdzielenia RNG.
Nie dodajemy Showdown, ręcznej pauzy, wyboru perspektywy, muzyki ani publiczności.
Nowy panel nie może zatrzymywać obsługi własnego klienta Ponga, ale nie
rozszerzamy tego na odłożoną ogólną naprawę modalnej pomocy R09/F01.

## Weryfikacja

Końcowe wyniki: `../diagnostics/pong-source-fixes-231/SOURCE.json` względem
katalogu repozytorium. Przeszło 39/39 celowanych skryptów i 33/33 kontrole
składni zmienionych lub dodanych plików Ruby. Oba kompilatory są idempotentne,
a kontrola różnic nie wykazała błędów białych znaków. Nie uruchamiano pełnego
runnera projektu.

Przed naprawą nowe regresje wykazały pięć grup niezgodności fizyki/ustawień
i cztery grupy audio. Po zmianie przechodzą również symulacje obu klientów,
właściciela-obserwatora, ustawień osobistych dla różnych ról, opóźnionej
gotowości, późnej klatki UI, kolejnych punktów i przenoszenia odgłosów bota.
Test rzeczywistego przejścia do następnej wymiany wykrył także potrzebę
zachowania metadanych pierwszej lokalnej epoki kanału; poprawiono ją przed
końcową weryfikacją.

Sprawdzono binarne wczytywanie źródeł z rzeczywistym słownikiem ELTEN-a
w PL/EN/fallback, natywną kontrolkę z niełacińskim komunikatem, wspólny
i szybki panel ustawień, trwałość wartości, anulowanie, Ctrl+P tylko w Pongu,
ochronę wejścia podczas formularza oraz sprzątanie timera. Przeszły także
dotknięte wspólne testy UI, pomocy i Communications.

Nie jest to odsłuch urządzenia, fizyczne sprawdzenie myszy ani żywy mecz.
Test binarny dotyczył źródeł, nie nowo zbudowanej paczki. Dotychczasowa
podpisana 2.0.2/build 231 pozostaje bez zmian i NIE zawiera tych poprawek.
Nie deklarujemy pełnego odwzorowania wszystkich funkcji oryginału.
