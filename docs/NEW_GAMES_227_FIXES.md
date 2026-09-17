# Nowe gry po wydaniu 227 — poprawki i przegląd, 17 września 2026

Wersja i manifesty pozostają 2.0/build 227. Po zakończeniu przeglądu użytkownik
polecił ponowne zbudowanie i podpisanie tej samej wersji, z niezmienionym
changelogiem. Wynik kontroli nowego artefaktu jest zapisywany poza repozytorium
w `diagnostics/new-games-227-postrelease/PACKAGE.json`. Bez instalacji,
publikacji i wysyłania zmian na GitHub. Poprzednia paczka 227 jest zachowana
osobno i nie zawiera opisanych poniżej poprawek.

## Potwierdzone błędy

### Historia ruchów była widoczna, ale nie odczytywana

Rummy, Domino, Mexican Train, Scrabble i Taboo zapisywały publiczne opisy
ruchów do historii, lecz nie dostarczały ich przez `describe_event`.
Domyślna implementacja w `Base` zwracała `nil`; ekran gry nie miał więc
komunikatu do wypowiedzenia. Dotyczyło to ruchów własnych, przeciwników
i komputerów, nie ustawienia mowy danego gracza.

Dopisano jawnie wybierany moduł `PublicHistoryAnnouncements`. Zwraca on
publiczne wpisy przypisane do przyjętego zdarzenia. Nie powtarza komunikatów
startu, zmiany tury ani wyniku całej partii, które obsługuje wspólny ekran.
Rummy, wspólna klasa kostek, Scrabble i Taboo korzystają z tego modułu.
Dotychczasowe gry zachowują swoje opisy i domyślne zachowanie `Base`.

Moduł nie jest automatycznie włączany dla każdej przyszłej gry: historia
musi rzeczywiście zawierać wyłącznie informacje publiczne. Prywatne ręce,
odpowiedzi lub hasła wymagają odrębnej kontroli odbiorcy. W Taboo bieżące
hasło i słowa zakazane nie trafiają do tych wspólnych komunikatów.

Przed poprawką nowy test wykazał 136 brakujących odczytów w początkowych
scenariuszach pięciu gier. Po poprawce oraz rozszerzeniu scenariuszy test
przechodzi dla graczy, obserwatorów i ruchów przypisanych komputerom.
Sprawdza także brak mowy dla niekompletnych fragmentów ruchu, brak powtórzeń
po odświeżeniu i brak odczytywania archiwalnej historii po wejściu do gry.

### Mexican Train mieszał kodowania przy tworzeniu nagłówka

Źródła wczytywane binarnie przez ELTEN bez jawnej deklaracji kodowania
tworzyły część napisów jako ASCII-8BIT. Separator w nazwie stacji, np.
`12–12`, trafiał do polskiego szablonu UTF-8. Odtworzono zgłoszony wyjątek
w `MexicanTrain#table_header` poprzez binarne wczytanie źródeł.

Dopisano deklaracje UTF-8 w Mexican Train, Domino, ich wspólnej klasie,
nazwach kostek i powierzchni ręki kostek. Tak samo zabezpieczono źródła
Rummy i jego interfejs. Nie zmieniano globalnego kodowania ELTEN-a ani
nie zastępowano polskich liter znakami ASCII.

Test binarnego wczytywania obejmuje teraz nagłówki, ręce, skróty,
aktualizację istniejącego ekranu i opisy rzeczywistych ruchów wszystkich
pięciu gier. Używa polskiego katalogu tłumaczeń i uczestnika z polską
literą w nazwie. W tej kontroli badano aktualne źródła, nie starą paczkę.

## Dodatkowy przegląd

Sprawdzono kod silników, ekranów i istniejące testy poniższych obszarów.
Nie potwierdzono kolejnego błędu wymagającego zmiany w badanych scenariuszach.

| Gra | Zakres kontroli |
| --- | --- |
| Rummy | Kolejność dobierania i pierwszego wyłożenia, jokery, manipulacje i długi za zabrane karty, punktacja i eliminacja, pusty stos, blokada, zegar, edytor układów, zachowanie kursora, planer, fragmenty ruchów i odtwarzanie zapisów. |
| Domino | Liczebność zestawów i rozdań, dozwolone końce, jedno zbiorcze dobieranie, zakaz dobierania, czas, drużyny, kończenie całą drużyną, blokada, punktacja, decyzje bota i ręka kostek. |
| Mexican Train | Cykl stacji i rozdania, dostęp do pociągów, otwieranie i zamykanie, pozostawione dublety i wyjątek własnej serii, ponowne dobieranie po dublecie, blokada, eliminacja, decyzje bota i podgląd pociągów. |
| Scrabble | Legalność i punktacja ułożenia, premie, blanki, odrzucenie nielegalnego słowa, wymiana, końcowe rozliczenie, zegar, polskie litery, lokalny projekt słowa, kursor i atomowe odtwarzanie. |
| Taboo | Widoczność karty według roli, przejścia faz, zegar, spóźnione i równoczesne decyzje, korekty i zatwierdzenie, autor decyzji moderatora, master-obserwator, rotacja, dogrywka oraz zgodne odtwarzanie pięciu klientów testowych. |

Nie zmieniano zasad gier, strategii botów ani budżetu ich obliczeń na podstawie
samych podejrzeń. Przejrzane scenariusze nie są dowodem braku wszystkich
błędów ani porównaniem siły bota z dobrym człowiekiem.

## Wykonane sprawdzenia

Przeszły 24 celowane skrypty, bez pełnego runnera:

- `rummy_test`, `rummy_edges_test`, `rummy_variants_test`,
  `rummy_surface_test`, `rummy_save_strategy_test`;
- `domino_test`, `mexican_train_test`, `tile_hand_test`;
- `scrabble_test`, `scrabble_surface_test`;
- `taboo_test`, `taboo_surface_test`, `taboo_network_test`;
- `three_games_integration_2_test`;
- `new_games_2_announcements_test`, `packaged_rules_encoding_test`;
- `game_messages_ui_test`, `game_sounds_test`, `game_screen_network_test`;
- `card_hand_cursor_test`, `playable_card_navigation_test`;
- `saved_games_test`, `saved_games_ui_test`, `table_lifecycle_controls_2_test`.

Sprawdzono składnię 12 zmienionych/dodanych plików Ruby i `git diff --check`.
Wyniki uruchomień zachowano poza repozytorium:
`diagnostics/new-games-227-postrelease/TESTS.json`.

Testy używają lokalnych atrap UI i transportu; nie zastępują odsłuchu
w rzeczywistym ELTEN-ie ani partii głosowej Taboo. Nie przeprowadzono
ponownego pełnego audytu słowo po słowie słowników Scrabble i kart Taboo.
Przed następnym wydaniem należy ponownie zbadać gotową podpisaną paczkę.

Poprzedni artefakt (kopia sprzed poprawek): 12 377 336 bajtów,
SHA-256 `60eb979917ffccfb13540b650dd757309629c8f1d2e97eb9dc9f8aa832684b4f`.
