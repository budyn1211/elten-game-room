# Dodawanie gry

## 1. Wybierz istniejący model

Najpierw sprawdź wspólne klasy. Gra planszowa z ruchem figura–pole powinna
dziedziczyć po `GameRoomGames::TurnBasedBoardGame`. Inne gry dziedziczą po
`GameRoomGames::Base`, ale nadal korzystają z `GameSurfaces`, układu, skrótów,
historii, punktacji, rund i botów.

Nie twórz nowej warstwy tylko dlatego, że jedna gra potrzebuje dodatkowej
akcji. Najpierw spróbuj rozszerzyć specyfikację powierzchni albo dodać mały,
wielokrotnego użytku element do istniejącego szkieletu.

## 2. Zaimplementuj model

Utwórz plik `games/<id>.rb` i zaimplementuj co najmniej:

- `id`, `name` i `rule_sections`;
- `minimum_players` i `maximum_players`;
- `option_definitions`, jeśli gra ma warianty;
- zdarzenia rozpoczynające partię;
- `replay`, który deterministycznie odtwarza stan;
- `surface_spec`, który opisuje dostępny interfejs;
- `action_for`, który sprawdza kolej, rodzaj akcji i wszystkie reguły;
- czytelne wpisy historii i komunikaty błędów.

Zdarzenie powinno zawierać dane konieczne do odtworzenia ruchu, ale nie dane,
które można bezpiecznie wyliczyć ze stanu. Prywatne informacje, takie jak ręce
kart albo odpowiedzi przed ujawnieniem, muszą korzystać z istniejących
mechanizmów ukrytych danych.

## 3. Podłącz wspólny interfejs

Wybierz właściwą powierzchnię z `lib/game_surfaces/`:

- `piece_board` dla planszy z figurami;
- `pawn_track` dla toru pionków;
- `dice_tray` dla kości;
- powierzchnię kart dla ręki i stosu;
- `answer_sheet` albo `review_surface` dla odpowiedzi i oceniania;
- `command_panel` dla niewielkiego zestawu poleceń.

Historia, lista użytkowników, pomoc F1, zasady Ctrl+F1 i ogólny układ ekranu są
wspólne. Skróty charakterystyczne dla rodziny gry dodawaj do wspólnego
szkieletu tylko wtedy, gdy ich znaczenie jest rzeczywiście takie samo.

## 4. Dodaj bota opcjonalnie

Ustaw `supports_bots?`, wystaw pełną listę legalnych akcji i zarejestruj
strategię. Bot może używać heurystyk lub przeszukiwania, ale wybrana akcja musi
wrócić do zwykłego `action_for`; strategia nie może sama dopisywać zdarzeń.

Sprawdź osobno:

- brak legalnego ruchu;
- koniec rundy i koniec partii;
- kilka botów wykonujących kolejne ruchy;
- informację niepełną i pełną, jeśli gra ma wariant bota „oracle”.

## 5. Zarejestruj grę

Dodaj `require_relative` oraz klasę do `GAME_REGISTRY` w `__app.rb`. Rejestr
wywołuje `rule_book`, dlatego brak zasad zostanie wykryty przy starcie.

## 6. Napisz testy

Minimalny zestaw obejmuje:

- prawidłowy start dla skrajnych liczb graczy;
- legalny i nielegalny ruch;
- pełne zakończenie partii;
- deterministyczny replay;
- powierzchnię i podstawowe skróty;
- bota, jeśli jest obsługiwany;
- regresję dla każdego naprawianego błędu.

Na końcu uruchom `ruby tools/run-tests.rb`.
