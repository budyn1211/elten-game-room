# Informacje o składnikach zewnętrznych

## Unicode normalization

Katalog `lib/vendor/unicode_normalize/` zawiera awaryjną implementację
normalizacji Unicode pochodzącą z biblioteki standardowej Ruby. Jest używana
tylko wtedy, gdy środowisko ELTEN-a nie udostępnia `unicode_normalize`.
Odpowiednie informacje licencyjne znajdują się w nagłówkach tych plików oraz w
`LICENSES/RUBY.txt` i `LICENSES/RUBY-BSDL.txt`.

## Statki i Mankala

Gry autorstwa **Dawida Piepera** włączone z jego propozycji dla tego projektu:

- [PR #8 — Statki](https://github.com/papierek1997/elten-game-room/pull/8),
  źródło `f19504ba298eaefff14e86ebfda8c6e37bcf312e`;
- [PR #9 — Mankala](https://github.com/papierek1997/elten-game-room/pull/9),
  źródło `4c847c8beb5eb2dd7e4b6f45af0f7587a6ee72cd`.

Lokalna integracja obejmuje uzgodnione poprawki, polskie tłumaczenia i nowe
instrukcje. Wariant Ayoayo zachowuje reguły autora. Nie jest to deklaracja
scalenia PR-ów na GitHubie. Źródła pomocnicze i zakres zmian opisuje
`docs/BATTLESHIP_MANCALA_229.md`.

## Dźwięki

Większość plików w katalogu `Audio/` pochodzi z opublikowanego buildu 176.
Dźwięki `connect.ogg` i `disconnect.ogg` zostały później zastąpione, a
`chatmsg.ogg` dodany z dostarczonego przez autora zestawu dźwięków. Repozytorium
nie zawiera osobnego dokumentu potwierdzającego pierwotne źródło i licencję
tych plików. Przed objęciem zasobów jednolitą licencją należy uzupełnić tę
informację albo zastąpić je dźwiękami o jednoznacznej licencji.

Plik `hit1.ogg`, używany przy skompletowaniu grupy w Monopoly, oraz plik
`notice.ogg`, używany przez powiadomienia Game Roomu, pochodzą z dostarczonego
zestawu Quentin Playroom. Dla tych plików również nie ma w repozytorium
osobnego potwierdzenia licencji.

### Dźwięki kostek Domino i Mexican Train

Trzy nagrania autora **poenia**, dostarczone przez użytkownika wraz z
informacją o licencji [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/):

- `Audio/domino_refill.ogg` — [Domino_sfx_refillPlayers](https://freesound.org/s/745031/), rozdawanie kostek;
- `Audio/domino_move_tile.ogg` — [Domino_sfx_moveTile](https://freesound.org/s/745028/), zagranie kostki;
- `Audio/domino_take_chip.ogg` — [Domino_sfx_takeChip](https://freesound.org/s/745032/), dobranie ze stosu.

Są to pliki Freesound `preview-hq-ogg`, pobrane 18 września 2026 r.
Nagrania zachowano bez zmian zawartości, zmieniono jedynie nazwy plików.

### Ponowne tasowanie kart

`Audio/card-shuffle.ogg` — [Card Shuffle](https://freesound.org/s/201253/)
autorstwa **empraetorius**, na licencji
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Użytkownik dostarczył plik Freesound `preview-hq-ogg` wraz z informacją
licencyjną, pobrany 18 września 2026 r. Nagrania nie edytowano ani nie
przekodowywano; zmieniono wyłącznie nazwę pliku.

### Nowe dźwięki Statków

Użytkownik dostarczył z własnego katalogu Freesound pliki `hit_ship1.ogg`,
`hit_ship2.ogg`, `rocket_launch1.ogg`, `rocket_launch2.ogg`, `rocket_launch3.ogg`
i `rocket_miss.ogg`. Zachowano ich nazwy i zawartość bez przekodowania.
Nie dodawano niedostarczonego `hit_ship3.ogg`. Wśród materiałów użytkownika
są informacje licencyjne nagrań, ale nie potwierdzono jednoznacznego
przyporządkowania oryginalnych nazw do tych sześciu przemianowanych plików.
Nie przypisuje się im na tej podstawie jednej wspólnej licencji.

### Krowa — słownik i nagrania

Gra Krowa została dostarczona przez **paulinux** w PR #10 z konta GitHub
`paoscripts` (commit `50ea3081e6d6e7a59ee63eee8b7809cb643d7e50`). Bazę
rzeczowników oraz osiem nagrań `Audio/krowa-*` zachowano bez zmiany bajtów.
Nie usuwano powtórzeń ani nie zmieniano kolejności słów. Zgłoszenie nie
podaje pełnego pochodzenia bazy i warunków dystrybucji nagrań; przed
publicznym rozpowszechnieniem należy uzyskać te informacje od autora.
Brak informacji nie jest stwierdzeniem naruszenia ani przypisaniem tym
zasobom licencji całego repozytorium. Definicje wyświetlane na żądanie
pochodzą z serwisu SJP.pl i wskazują to źródło w oknie.
