# Domyślne gry w komunikatach lobby — build 231

## Uzgodniona zmiana

Zapisane ustawienia lobby przechowywały wyłącznie zaznaczone gry. Po
rozszerzeniu katalogu brak nowej gry był interpretowany jako jej wyłączenie.
Użytkownik polecił objąć poprawką zarówno obecne nowsze gry, jak i każdą
następną dodaną do projektu.

Starszy zapis otrzymuje zaznaczenia dziesięciu gier dodanych od wersji 2.0:
Rummy, Domino, Mexican Train, Scrabble, Taboo, Biblios, Statki, Mancala,
Krowa i Axel Pong. Wcześniejsze odznaczenia pozostałych gier są zachowane.
Stary format nie pozwala odróżnić brakującego zaznaczenia od świadomego
wyłączenia jednej z tych dziesięciu gier; ich jednorazowe zaznaczenie jest
zamierzonym, zatwierdzonym przez użytkownika zachowaniem.

## Zapamiętywanie wyboru

`lobby_known_games` przechowuje katalog widziany przez ustawienia, niezależnie
od istniejącego `widget_known_games`. Nowe identyfikatory trafiają domyślnie
do zaznaczonych. Zapis formularza zachowuje wybór oraz katalog, więc ręczne
odznaczenie nie jest cofane po ponownym otwarciu, restarcie ani następnej
aktualizacji. Chwilowe usunięcie gry z katalogu nie usuwa wiedzy o niej.
Świeża instalacja nadal ma zaznaczone wszystkie gry.

Sama normalizacja i odczyty lobby pozostają bez zapisu na dysk i bez sieci.
Zapis następuje zwykłym przyciskiem Zapisz w ustawieniach; Anuluj niczego
nie zapisuje. Użyto wspólnej funkcji wyboru dla lobby i widgetu, zachowując
ich oddzielne dane i dotychczasowe zachowanie widgetu.

Nie zmieniono przełączników rodzajów komunikatów, wyciszenia lobby,
zaznaczeń widgetu, filtrów kontaktów, zaproszeń ani serwerowych subskrypcji
powiadomień o stołach. Zaznaczenie w lobby nie włącza tych powiadomień.

## Kontrola i wydanie

`test/lobby_game_defaults_test.rb` odtwarza brakujące zaznaczenia i sprawdza
migrację, dwa przyszłe rozszerzenia katalogu, ręczne wyłączenia, osobne
profile/kanały, przełączniki komunikatów oraz rzeczywistą ścieżkę formularza
Zapisz/Anuluj z zastąpionym dostępem do plików i sieci. Wielokrotne odczyty
nie wykonują zapisów. Test binarny formularza sprawdza zaznaczenia również
z rzeczywistym słownikiem PL/EN/fallback i natywną kontrolką ELTEN-a.

Na polecenie użytkownika pozostają wersja 2.0.2, build 231 i API 3.0.3.
Changelog zachowuje poprzednie dziewięć punktów i dodaje jeden o lobby.
Nowe raporty źródeł i podpisanej paczki:
`../diagnostics/lobby-game-defaults-231/SOURCE.json` oraz `PACKAGE.json`.
Raporty potwierdzają wykonanie testów, nie zastępują testu żywej aplikacji.
Poprzednia paczka a221d435… ma zostać zachowana jako
`ELTEN-Game-Room-build-231-before-lobby-defaults-signed.eltsetup`.
Po poprawnym wydaniu użytkownik zatwierdził wysłanie wszystkich zmian
repozytorium na GitHub. Bez instalowania lub publikowania paczki w ELTEN-ie,
zmian serwera i ręcznego modyfikowania profili; bez pełnego runnera testów.
