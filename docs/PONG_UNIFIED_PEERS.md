# Pong: wspólna obsługa ludzi, botów i meczów mieszanych

Stan: 22 września 2026. Wdrożenie w źródłach na polecenie użytkownika; bez nowej paczki.

## Co zostało ujednolicone

Wcześniej samo dodanie bota przełączało cały mecz na inny model: gospodarz odbierał wejście ludzi i rozstrzygał ich ruchy. Teraz każdy mecz używa `PeerPlay` i `PeerEngine`.

- Klient człowieka rozstrzyga jego własny serw, odbicie i chybienie, po czym wysyła ważną akcję do pozostałych przez relay Communications. Nie potrzebuje echa gospodarza.
- Gospodarz uruchamia kontrolery botów i jest jedynym nadawcą uprawnionym do ich akcji. Nie może przejąć miejsca innego człowieka.
- W singlu właściciel–bot obie strony nadal obliczane są lokalnie, bez czekania na zestawienie Communications. Późniejsze pierwsze połączenie nie kasuje trwającego lotu piłki.
- Gdy gospodarz jest obserwatorem, prowadzi boty, ale nie paletki ludzi. Pozostali obserwatorzy korzystają ze stanu gospodarza.

To ujednolicenie **ważnych akcji rozgrywki**, nie usunięcie wszystkich zadań gospodarza. Okresowe pozycje mają nadal osobną ścieżkę; gospodarz zbiera je i udostępnia stan. Nadal odpowiada też za gotowość meczu, efekty Arcade oraz uzgodnienie i trwałe zapisanie punktu.

## Punkt i dźwięk bramki

Po chybieniu klienci uzgadniają tę samą wymianę, kolejność i zwycięzcę. Gospodarz dopiero po zgodzie wymaganych ludzi wysyła wspólne zdarzenie `point`, pozwalające odtworzyć dźwięk bez czekania na odpowiedź zapisu LiveSessions. Wynik i zwycięstwo partii nadal zatwierdza trwały zapis i jego odtworzenie. Brak zgody nie tworzy punktu; powtórzenie wiadomości lub późniejszy zapis nie powtarza dźwięku.

Nie ma już osobnej ścieżki `goal_confirmed` dla botów. Pauza po wyniku pozostaje 2,7 s; zwykła zapowiedź pary w deblu nie czeka na znacznik zakończenia syntezy. Zachowano wcześniejszą poprawkę z 235.

## Uprawnienia, kolejność i zgodność klientów

Warstwa wspólna nadal sprawdza rzeczywistego nadawcę Communications, mecz, generację, członkostwo, sekwencję i duplikaty. Pong dodatkowo sprawdza, czy nadawca prowadzi dane miejsce i czy ono ma wykonać akcję. Dla bota uprawniony jest właściciel stołu, dla człowieka — wyłącznie jego własne konto. Akcje przychodzące przed poprzedzającą je akcją są odraczane w ograniczonej kolejce.

Dla meczów z botami wprowadzono `pong-mixed-peer-1` i `pong-doubles-mixed-peer-1`. Stare klienty centralizujące wejście nie mogą uczestniczyć w tym samym kanale. Istniejące protokoły meczów wyłącznie ludzkich nie zmieniły się. Do rzeczywistej próby mieszanej wszystkie kopie wymagają zgodnego nowego kodu. Bot nie potrzebuje konta ani sesji sieciowej.

## Zachowanie silnika i dźwięków

Zmiany produkcyjne ograniczają się do `client.rb`, `peer_play.rb` i `peer_engine.rb`. Nie zmieniono `Engine`, `Bot`, strategii, poziomów trudności, parametrów fizyki ani tolerancji obrony. Nowa droga nie przejmuje innego profilu zasięgu obrony z meczu wyłącznie ludzkiego.

Podczas kontroli kandydat ujawnił dwie regresje, które naprawiono przed zakończeniem:

- Efekty Arcade dla lokalnego bota muszą powstać w tym samym miejscu klatki co wcześniej, zanim kolejny bot zacznie śledzić piłkę. Wynik losowania jest zapamiętywany do wysyłki, bez drugiego losowania. Otrzymany serw inicjuje też dotychczasową reakcję bota dokładnie raz.
- Drobne ruchy bota potrafią być celowo bezgłośne. Sama zmiana pozycji nie może tworzyć kroku u odbiorcy. Odbiorca odtwarza rzeczywiste zdarzenia kroków z istniejącej migawki gospodarza i nie powtarza ich przy kolejnych migawkach. Nagrania, proporcje głośności i wysokości dźwięków pozostają bez zmian.

Usunięto starą pętlę centralnego sterowania w `Client`, zamiast utrzymywać dwa aktywne modele. Nie zmieniono wspólnego `Channel`, `EventChannel`, źródeł ELTEN-a, LiveSessions ani serwera.

## Weryfikacja

Końcowy przebieg: **39/39 celowanych skryptów**, **15/15 kontroli składni** i czysty `git diff --check`. Pełnego runnera projektu nie uruchamiano. Dokładne wyjścia zapisano poza repo w `../diagnostics/pong-unified-peers/RESULT.json`.

- Sześć obsad singla/debla, po 16 wymian, z kontrolowanymi sytuacjami serwu, odbić i chybienia; wszystkie pary serwisowe, boty po obu stronach, właściciel grający i obserwator. Zapis punktów tylko przez właściciela.
- Dziewięć konfiguracji symulowanego relay, po osiem wymian, także czterech klientów, mieszane drużyny i Arcade. Zmienność dostawy 20–220 ms, czas pracy wysyłki 120 ms, utrata co siódmej aktualizacji pozycji i przerwy klatek gospodarza.
- Osobna próba z rzeczywistym `EventChannel` i podstawionym natywnym wejściem/wyjściem: odbicie człowieka dotarło do innego człowieka przed gospodarzem, którego odbiór celowo opóźniono o 350 ms. Nadawca wysłał jedną akcję do pełnej listy odbiorców; nie było echa właściciela.
- Zgodność lokalnych botów klatka po klatce ze zwykłym silnikiem dla sześciu poziomów, Classic i Arcade, do końca wymiany lub 3000 klatek. Oddzielne próby uprawnień, inicjalizacji po zdalnym serwie i dźwięków kroków.
- Opóźniony trwały zapis punktu, brak potwierdzenia jednego człowieka, wczesny podgląd dla obserwatora, powtórki, zły nadawca, stara generacja, odzyskiwanie, ponowny mecz i lokalny start bez Communications.
- Dotychczasowe regresje Ponga: mysz/klawiatura, pauza serwisu bez znacznika syntezy, komunikaty, audio bez urządzenia, kolejność akcji i integracja zapisu przez normalny mechanizm LiveSessions.

Na początku stare założenie o centralnej obsłudze botów odtworzyło problem. Testy wcześniejszego modelu zaktualizowano do zaakceptowanego podziału odpowiedzialności, zachowując kontrole kolejności, fokusu, punktów i braku powtórek. Jeden pomocnik próby wymagał uruchamiania podstawionego workera także podczas przygotowania serwu — był to błąd próby, nie gry.

## Ograniczenia i wydanie

To testy **offline**, nie pomiary Internetu, odsłuch ani nowa partia czterech ludzi. Kontrolowane ułożenia piłki w testach są opisanymi scenariuszami, nie pełnymi naturalnymi meczami. Nie dowodzą usunięcia wszystkich historycznych rzadkich awarii; zdarzenia `OwnerChanged` i `PeerStatusTimeout` pozostają osobnymi niewyjaśnionymi tropami.

Nie zmieniano wersji, buildu, changelogu, profili ani serwera. Nie budowano, nie podpisywano, nie instalowano i nie publikowano paczki ani nie wysyłano zmian na GitHub. Dotychczasowa podpisana **2.0.2.4/build 235 nie zawiera tego ujednolicenia**.

## Późniejsze wydanie 236 — 22 września 2026

Po opisanym wdrożeniu użytkownik polecił zbudować paczkę oraz ustawić nową wersję i changelog. Ujednolicenie wydano w podpisanej **2.0.2.5/build 236**, z dwoma nowymi wpisami PL/EN. Poprzednia 235 pozostała zachowana. Weryfikacja podpisu papierek, kompletu 335 plików, zgodności źródeł oraz binarnego wczytania nowych klas, języków i ustawień przeszła. Do próby mieszanej wszyscy potrzebują zgodnej nowej wersji. Raporty: `../diagnostics/release-236/{SOURCE,PACKAGE}.json`. Bez instalacji, żywej partii, GitHuba i zmian serwera.
