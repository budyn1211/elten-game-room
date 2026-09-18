# Ctrl+F1: zachowanie bieżącej listy skrótów

## Przyczyna

Otwarcie zasad zwracało `:rules` z `GameScreen#wait_for_action`. Jego
blok `ensure` wywoływał `layout.begin_bindings`, usuwając obsługę zdarzeń,
timery i dynamiczne opisy skrótów. Dopiero potem `show_game_rules`
odczytywało pomoc pól gry. W Scrabble lista 19 opisów stawała się pusta;
w innych kontrolkach mogły pozostać wyłącznie opisy wbudowane.

Poprzedni test `rules_live_help_test` otwierał zasady bezpośrednio po
przypięciu skrótów, pomijając zakończenie oczekiwania na akcję. Sprawdzał
filtrowanie opisów, ale nie obejmował kolejności powodującej zgłoszony błąd.

## Poprawka

Przy wyjściu z oczekiwania z akcją `:rules` ekran zachowuje kopię opisów
widocznych pól gry, zanim usunie powiązania. Okno zasad zużywa tę kopię
jednorazowo. Inne akcje oraz nowa sesja ją czyszczą. Bezpośrednie otwarcie
pomocy nadal może odczytać bieżące pola; rzeczywiście pusta lista nie jest
zastępowana przypadkowymi opisami z wcześniejszej fazy.

Źródło pozostaje wspólne z F1. Nie dodano drugiej listy skrótów, obsługi
czatu, skrótów globalnych ani stałych opisów nieaktualnych dla fazy gry.
Nie zmieniono przypisań klawiszy, stanu rozgrywki, transportu, zegarów,
sprzątania timerów, zasad ani sposobu odczytywania innych kontrolek.

## Weryfikacja

Nowy `test/rules_help_lifecycle_test.rb` przechodzi przez rzeczywiste
`wait_for_action`, Ctrl+F1 lub menu, sprzątanie i listę zasad. Przed naprawą
odtwarzał pustą listę Scrabble. Obejmuje własną i cudzą turę, obserwatora,
zakończoną grę, wejście z pola gry/czatu/historii/listy osób, ponowne
otwieranie, Enter/Escape, zmianę definicji pomiędzy fazami oraz natywną
pomoc paczek Makao i wymiany Pokera. Sprawdza zachowanie stanu gry,
kursora, tekstu i zaznaczenia czatu oraz usunięcie aktywnych timerów.

Test działa również przy binarnym wczytaniu źródeł i z argumentem ścieżki
gotowej paczki. Obejmuje PL/EN i angielski tekst obok innego języka hosta;
może korzystać z rzeczywistego słownika ELTEN-a. Są to symulacje kontrolek
i lokalnego przebiegu aplikacji, nie test żywych klientów.

## Wydanie

Użytkownik polecił ponowne zbudowanie i podpisanie tej samej wersji
2.0.1/build 229. Zachowano wcześniejsze 27 punktów changelogu i dopisano
jeden PL/EN pod tym samym nagłówkiem. Wynik testów i podpisanej paczki:
`../diagnostics/rules-shortcuts-229/SOURCE.json` i `PACKAGE.json`.
Sam ten dokument nie potwierdza ukończenia pakowania. Bez instalacji,
publikacji, GitHuba, zmian serwera i profili użytkownika.
