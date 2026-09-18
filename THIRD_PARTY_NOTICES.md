# Informacje o składnikach zewnętrznych

## Unicode normalization

Katalog `lib/vendor/unicode_normalize/` zawiera awaryjną implementację
normalizacji Unicode pochodzącą z biblioteki standardowej Ruby. Jest używana
tylko wtedy, gdy środowisko ELTEN-a nie udostępnia `unicode_normalize`.
Odpowiednie informacje licencyjne znajdują się w nagłówkach tych plików oraz w
`LICENSES/RUBY.txt` i `LICENSES/RUBY-BSDL.txt`.

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
