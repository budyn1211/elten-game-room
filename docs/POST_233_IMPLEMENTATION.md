# Pięć poprawek po 233 — wdrożenie w źródłach

Stan: 21 września 2026. Wdrożono na polecenie użytkownika pięć punktów
`POST_233_FIXES_PLAN.md`. Nie budowano ani nie podpisywano nowej paczki;
podpisana 2.0.2.2/build 233 nie zawiera tych poprawek. Bez zmiany wersji,
changelogu, instalacji, publikacji, serwera lub profili użytkownika.

## Ping na żądanie

Ctrl+F4 działa w formularzach Game Roomu i na jego widgecie. Jeden odczyt
HTTP do serwera ELTEN-a jest wykonywany w tle, dopiero po naciśnięciu
skrótu. Od poprawki 234 komunikat mówi „HTTP: … ms.”. Jest to czas żądania
i odpowiedzi HTTP, nie ping ICMP ani opóźnienie do drugiego gracza Ponga.
Pomiar używa zegara monotonicznego i istniejącego System.server_time
z limitem pięciu sekund. Nie powstaje stałe odpytywanie, zapis na dysku
ani wiele równoległych pomiarów. Błąd nie jest przedstawiany jako zero.

Wynik jest odczytywany raz w aktywnym interfejsie. Odświeżenie formularza
Game Roomu nie gubi trwającego pomiaru, ale powrót po dłuższej przerwie
nie odczytuje starego wyniku. Poza Game Roomem nie zmieniamy Ctrl+F4
ani konfiguracji skrótów ELTEN-a.

## Bot usunięty ze składu

Odtworzono konkretny przypadek: po przerwaniu partii stan stołu jest już
oczekujący, lecz lista osób korzystała ze starego, niedokończonego replayu.
W ten sposób przywracała wizualnie usuniętego bota i dawne drużyny.
W oczekującym stole lista korzysta teraz wyłącznie z bieżących uczestników.
Historia poprzedniej partii, jej gracze i przypisania pozostają niezmienione.
Sprawdzono odczyt gospodarza i drugiego uczestnika, zastąpienie bota oraz
rozpoczęcie następnej partii. Nie jest to twierdzenie, że każdy możliwy
przypadek nieaktualnego składu miał tę samą przyczynę.

## Historia podczas pisania

Ctrl+przecinek/kropka odczytuje poprzedni/następny wpis, a z Shiftem
przełącza kategorię także w polu wiadomości. Fokus, tekst, pozycja kursora
i zaznaczenie nie zmieniają się. Skróty są uwzględnione w pomocy pola.
Zwykła interpunkcja nadal służy do pisania. Ctrl+Home/End oraz inne skróty
edycji pozostają natywne w polu wysyłania wiadomości; w historii tylko
do odczytu Ctrl+Home/End nadal wybiera początek/koniec kategorii.

## Trzydzieści makr

Ustawienia → Widget → lista skrótów stołów zawiera kolejno Ctrl+1–0,
Alt+1–0 i Shift+1–0. Dotychczasowe dziesięć przypisań pozostaje, nowe
dwadzieścia jest początkowo puste. Na widgecie skrót tworzy zapisany stół.
W kategorii Widget ustawień ten sam skrót tylko wybiera odpowiedni wiersz
listy i odczytuje przypisanie. Enter otwiera dotychczasowy wybór gry oraz
ustawień; zapis nadal jest natychmiastowy i niezależny od późniejszego
Anuluj w głównym formularzu ustawień. Inne kategorie nie przechwytują cyfr.
Modyfikatory muszą pasować dokładnie, przytrzymanie nie tworzy wielu stołów.

## Szybkie przypisywanie drużyn

Użytkownik potwierdził zamianę sąsiednich osób bez zawijania na końcach.
Wspólna lista przydziału drużyn obsługuje Shift+góra/dół dla ludzi i botów.
Zamienia zaznaczoną osobę z sąsiadem; miejsce określa drużynę, a kursor
podąża za osobą. Zwykłe strzałki i dotychczasowy Enter działają dalej.
Start zapisuje przydział względem pierwotnej listy graczy, nie zmieniając
kolejności tur. Zachowano walidację liczebności, uprawnień i zmian składu
w trakcie ustawiania drużyn. Reset przywraca pierwotne automatyczne drużyny.

## Sprawdzenie

Końcowo przeszło 17 różnych, celowanych skryptów (nie pełny runner):
`post_233_ping_test`, `post_233_presets_test`, `post_233_roster_test`,
`post_233_dictionary_test`, `team_assignment_test`, `volume_and_help_test`,
`room_lifecycle_test`, `surface_framework_test`, `widget_preset_creation_test`,
`game_client_lifecycle_test`, `bot_names_test`,
`observer_and_shortcut_regressions_test`, `concise_shortcut_help_test`,
`history_text_test`, `history_native_text_test`, `widget_presets_test`
oraz `widget_inline_presets_test`. Także 18 kontroli składni, idempotencja
kompilatora polskiego katalogu i kontrola różnic zakończyły się poprawnie.

Testy używają m.in. rzeczywistej kontrolki tekstowej, rozpoznawania skrótów,
dispatchera i Dictionary ELTEN-a (PL/EN/fallback). Nowy ping sprawdzono
z rzeczywistym API na sztucznym kliencie oraz prawdziwym wątkiem roboczym,
bez wysyłania żądania do żywego serwera. Skład stołu sprawdzono na lokalnym
brokerze dwóch uczestników. Nie było żywej partii, odsłuchu ani testu nowej
paczki. Ładowanie binarne w części skryptów oznacza ich symulowany loader,
nie zbudowany instalator.

Pierwszy przebieg `surface_framework_test` wykrył zbyt szerokie dopuszczenie
skrótów historii w edytorze. Ograniczono wyjątek do uzgodnionej interpunkcji;
nie zmieniano tej asercji. Ponowny test przeszedł. Raport celowanych kontroli:
`../diagnostics/post-233-fixes/SOURCE.json` (względem katalogu repozytorium).
