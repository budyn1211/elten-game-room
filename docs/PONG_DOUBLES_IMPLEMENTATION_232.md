# Debel Axel Ponga — build 232

Włączono PR [#11](https://github.com/papierek1997/elten-game-room/pull/11)
autorstwa budyn1211, z tipa `a526401e385991adff7f4d3a46916539a55e8d9f`.
Zachowano commity autora. Integracja obejmuje wybór Single/Doubles,
standardowe przypisywanie drużyn, cztery paletki, naprzemienne odbicia,
rotację serwisów, boty, wspólne punkty i wynik drużyny, lokalną symulację
oraz protokół deblowy Communications. LiveSessions utrwala punkty meczu.
Nie zmieniano innych reguł ani kolejności odczytu wyniku drużyn pod S.

## Uzgodnione poprawki do PR

- Obserwator wybiera gracza, nie drużynę: 1–4 w deblu, nadal 1/2 w Single.
  Potwierdzenie zawiera nazwę gracza. Wybór nie zmienia stanu meczu,
  nie daje prawa do sterowania i nie przechwytuje cyfr w czacie.
- Dźwięki kroków, dojścia do krawędzi, serwisów i zwykłych odbić mają osobne
  odtwarzacze dla każdej paletki. Dodatkowe 18 głosów powstaje podczas
  przygotowania deblowego klienta, nigdy w klatce ruchu. Ponowne odświeżenie
  ich nie tworzy, a zamknięcie klienta zwalnia wszystkie głosy.
- Pierwszy uczestnik każdej drużyny ma kroki, serwisy i odbicia (również
  tarczą) o 3 półtony niższe. Drugi zachowuje standardową wysokość.
  Przy A–B przeciw C–D niżej brzmią A i C. Przypisanie wynika z zespołu,
  nie z perspektywy słuchacza. Współczynnik `2 ** (-3 / 12)` jest mnożony
  przez istniejącą krzywą wysokości kroku. Panorama, poziomy i dźwięki
  przełączania tarczy nie zostały zmienione.
- Pauza po zapowiedzi serwującego i odbierającego wynosi 2,7 sekundy,
  jak w Single, zamiast 5,4. Natywna synteza musi zakończyć zapowiedź.
  Nadal wymagane są gotowość uczestników i świeże naciśnięcie serwisu.
- Zaktualizowano zasady i polskie tłumaczenia. Changelog bieżącej
  2.0.2.1/build 232 otrzymał jeden krótki punkt o deblu z autorstwem.

## Weryfikacja i wydanie

Regresje obejmują wszystkie rozmieszczenia zespołów i perspektywy,
jednoczesne ruchy, wysokości dźwięków, zasoby/mute/close, opóźnioną mowę,
gotowość i ponowienie połączenia, rotację, cztery klienty symulowane,
boty oraz binarne źródła i słownik PL/EN/fallback. Dokładne wyniki bieżącej
weryfikacji źródeł i instalatora: `../diagnostics/pong-doubles-release-232/`
w katalogu roboczym (poza repozytorium). Nie jest to test czterech żywych
graczy ani odsłuch urządzenia.

Pakować z aktualnych źródeł wraz z runtime-only listą, nie ze starej bazy PR.
123 nagrania Opus pozostają bez zmiany bajtów; różna wysokość jest ustawiana
przy odtwarzaniu. Wersja 2.0.2.1, build 232, API 3.0.3. Poprzednią podpisaną
paczkę zachować. Bez instalacji, publikacji i wysyłki na GitHub.
