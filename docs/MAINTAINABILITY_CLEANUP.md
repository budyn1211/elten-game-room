# Porządki kodu — zakres 1–8

Ten etap nie przepisuje gier ani transportu realtime i nie zmienia strategii
botów. Punktem odniesienia jest robocza integracja ELTEN 3.0.4, nie starsza
wydana paczka wymagająca 3.0.3.

1. **Transport:** usunięto nieosiągalne backendy Hybrid/Signals/bootstrap.
   Fasada korzysta z `GameRoomLiveSessionStore`. Kolejki, subskrypcje i oba
   niezależne zabezpieczenia starego `closed` pozostają.
2. **Repozytoria:** usunięto dawne gałęzie zapisu stołów, członkostwa,
   zaproszeń i ruchów w tabelach. Nie usunięto aktywnych tabel rejestru,
   lobby, subskrypcji i Krowy. Test utraty odpowiedzi sprawdza teraz atomowy
   wpis LiveSessions, a nie martwy adapter tabelowy. Format archiwum jest
   oddzielony od miejsca przechowywania; konto nie dziedziczy lokalnego I/O.
3. **Runtime:** trening, kampanie, arena, `MatchRunner`, MCTS i nieużywane
   modele faz/punktacji są w `tools/training/`. Produkcyjne polityki,
   profile, heurystyki, generator i `Simulation::Environment` pozostają.
4. **Wykonawcy:** wspólna czysta polityka zastępstw i przygotowania bota.
   Oddzielne harmonogramy realtime/turowe; zachowane ziarna, budżety,
   lease, blokady i weryfikacja aktualności po planowaniu.
5. **Prezentacja:** kopia ostatniego prefiksu i gotowego stanu końcowego
   ogranicza powtórne replay. Wszystkie zdarzenia pośrednie pozostają.
   Cache jest nieważny przy zmianie sesji/opcji/obsady/prefiksu; pełna
   rekonstrukcja pozostaje ścieżką awaryjną. Nie dzieli mutowalnego stanu.
6. **Wyjątki:** znane błędy transportu zachowują recovery. Błąd programu
   nie uruchamia kolejnych prób zapisu i trafia z miejscem błędu do logu
   oraz do UI. Celowy fallback planera Spades pozostaje, lecz jego
   nieoczekiwany wyjątek jest diagnozowalny bez zalewania logu.
7. **Testy:** jeden resolver `ELTEN_HOST_SOURCE`, osobne procesy, raport
   każdego skryptu i limit czasu. Brak wymaganej zależności nie jest
   sukcesem. Najczęściej współdzielone atrapy UI, kanałów, wykonawcy,
   ustawień i ładowania binarnego są w `test/support/`, bez odpalania
   cudzych scenariuszy. Pozostałe starsze testy zbiorcze nie zostały
   hurtowo przepisane; nie należy dopisywać nowych zależności od `*_test.rb`.
8. **Dokumentacja i narzędzia historyczne:** README i architektura opisują
   obecny model. AGENTS zawiera bieżący kontrakt i trwałe reguły pracy;
   pełna dawna chronologia pozostaje w `WORK_HISTORY.md`. Usunięto
   nieużywaną starą listę skrótów. Trzy dawne
   aplikatory/importery quizu mają jawną granicę zapisu opisaną poniżej.

## Narzędzia dawnych audytów pytań

`apply-quiz-factual-audit.rb`, `apply-quiz-recovery-audit.rb` i
`import-reviewed-quiz-packs.rb` służą odtwarzaniu konkretnych historycznych
etapów, nie automatycznej aktualizacji dzisiejszej bazy. Bez flag drukują
manifest wejścia i celów bez ich zapisu. Nie jest to kolejny audyt merytoryczny.

Po świadomym przeglądzie decyzji i manifestu można podać `--apply --expect
MANIFEST.json`. Muszą zgadzać się SHA-256 wszystkich wejść i istniejących
celów; zmiana choćby treści pytania wymaga ponownej weryfikacji. Cofnięcie
wersji jest odrzucane także z taką zgodą. Starszy aplikator faktyczny zapisuje
wersję 3 i **nie może zastąpić obecnych danych wersji 4**. W historycznym
checkoutcie dodatkowo porównuje pełne pytanie z oryginałem/decyzją, nie tylko ID.
Importer PR nadal wymaga własnych przypiętych sum i sprawdza wszystkie pakiety
przed pierwszym zapisem. W razie zmiany algorytmu trzeba osobno ocenić jego
decyzje; manifest nie dowodzi ich merytorycznej poprawności.

Pozostałe jednorazowe narzędzia budowania decyzji/raportów są materiałem
historycznym. Nie uruchamiać ich seryjnie jako „czyszczenia” bazy. Nowe pytania
podlegają zasadom audytu w AGENTS; nie usuwamy pytań na podstawie samej heurystyki.

## Granice i sprawdzanie

Porównywać stany przed/po, komunikaty, sygnały, liczbę zapisów i uprawnienia,
nie tylko końcowy wynik. Obowiązkowe przypadki: niepewny zapis, stary callback
i zakolejkowane zamknięcie, powrót obserwatora, zmiana obsady/gospodarza,
prywatne fazy, tło i zachowanie fokusu. Testy lokalne nie są odsłuchem ani
testem wielu komputerów. Nie usuwać ograniczeń i zabezpieczeń tylko dlatego,
że lokalna próba przebiegła poprawnie.

Pełną regresję uruchamia `ruby tools/run-tests.rb --report test-results.json`
z zainstalowanym gettext i zgodnymi źródłami hosta. Pierwsze niepowodzenia
zachować obok wyników ponownych prób; nie przedstawiać pominiętych testów
albo prób przerwanych zmianą kodu jako zaliczonych.

## Wynik lokalnej kontroli — 25 września 2026

Pierwszy pełny przebieg wykonał 428 skryptów: 394 zaliczone i 34 nieudane,
bez timeoutów i pominięć. Niepowodzenia ujawniły m.in. zależności od efektów
ubocznych importowanych testów, stare atrapy lokalnego zapisu/transportu,
indeksy kategorii sprzed „Ogólne” i brak katalogu języka w kopii hosta do CI.
Poprawiono zależności i scenariusze, zachowując kontrolę uprawnień, kolejności,
fokusu i pojedynczych zapisów. Wszystkie 34 próby zaliczono po poprawkach.
Końcowy dodatkowy zestaw 10 prób obejmował zmienioną klasyfikację błędów,
wykonawcę, poczekalnię, prezentację w tle i ładowanie binarne: 10/10.
Zgodnie z późniejszym poleceniem użytkownika pełnego przebiegu nie powtarzano.
To wyniki pełnego pierwszego przebiegu oraz selektywnych powtórek, nie jeden
końcowy przebieg 428/428.

Kontrola bajtów potwierdziła niezmienność 296 plików gier, danych, nagrań,
tłumaczeń i manifestu względem roboczego stanu sprzed porządków. Kod
produkcyjny w `lib/` i `__app.rb` zmniejszył się netto o 100 007 bajtów.
Nie oznacza to pomiaru przyspieszenia sieci albo instalatora. Porównania
prezentacji zachowały identyczne stany, komunikaty i sygnały; przy jednym
nowym ruchu z aktualną pamięcią podręczną nie trzeba ponownie odtwarzać
stanu sprzed i po ruchu. Przy nadrabianiu partii stany pośrednie nadal są
rekonstruowane, więc nie obiecujemy jednakowego zysku dla dużych pakietów.

Nie uruchamiano nowych żywych stołów, nie wgrywano źródeł do ELTEN-a,
nie zmieniano serwera, paczki, wersji, changelogu ani GitHuba. Prywatne
raporty etapów i pierwotne niepowodzenia są w katalogu roboczym
`../diagnostics/maintainability-cleanup-2026-09-25/`.
