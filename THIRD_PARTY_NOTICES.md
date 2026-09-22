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

21 września 2026 r. ujednolicono wszystkie 123 nagrania do Ogg Opus
144 kb/s VBR (48 kHz, ramki 20 ms, libopus audio, complexity 10).
Trzy podkłady Krowy miały już te parametry; pozostałe 120 plików
przekodowano z dotychczasowych źródeł WAV/Vorbis, nie przez zmianę
samego rozszerzenia. Zachowano mono/stereo, informacje o autorach
i pozostałe dostępne metadane, bez normalizacji głośności i przycinania.
Powielony rok i pełną datę w niektórych WAV-ach reprezentuje pełna data.
Oryginały zachowano poza dystrybucją. Konwersja stratna nie nadaje
nowych praw do nagrań i nie gwarantuje identycznego brzmienia.

Większość plików w katalogu `Audio/` pochodzi z opublikowanego buildu 176.
Dźwięki `connect.opus` i `disconnect.opus` zostały później zastąpione, a
`chatmsg.opus` dodany z dostarczonego przez autora zestawu dźwięków. Repozytorium
nie zawiera osobnego dokumentu potwierdzającego pierwotne źródło i licencję
tych plików. Przed objęciem zasobów jednolitą licencją należy uzupełnić tę
informację albo zastąpić je dźwiękami o jednoznacznej licencji.

Plik `hit1.opus`, używany przy skompletowaniu grupy w Monopoly, oraz plik
`notice.opus`, używany przez powiadomienia Game Roomu, pochodzą z dostarczonego
zestawu Quentin Playroom. Dla tych plików również nie ma w repozytorium
osobnego potwierdzenia licencji.

### Cat, head, tail

Gra i jej pierwotna implementacja zostały dostarczone przez **TD Programs**
(konto `td-programs`) w [PR #12](https://github.com/papierek1997/elten-game-room/pull/12),
commit `7930486d9051e557b36d392af558139921fda606`. Autor wskazuje inspirację
grą Pig z RS Games. Integracja zachowuje punktowanie autora; dopracowano
opis zasad PL/EN, decyzję bota przy zabezpieczonym remisie oraz interfejs D.

Pięć dostarczonych nagrań `Audio/cht-*.opus` zachowano bez zmiany bajtów
i bez ponownej konwersji. Zgłoszenie nie zawiera informacji o pierwotnym
źródle ani osobnych warunkach licencyjnych nagrań. Przed publiczną
dystrybucją należy uzyskać te informacje od autora; nie przypisuje się
im automatycznie licencji kodu ani nie zakłada naruszenia praw.

### Dźwięki kostek Domino i Mexican Train

Trzy nagrania autora **poenia**, dostarczone przez użytkownika wraz z
informacją o licencji [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/):

- `Audio/domino_refill.opus` — [Domino_sfx_refillPlayers](https://freesound.org/s/745031/), rozdawanie kostek;
- `Audio/domino_move_tile.opus` — [Domino_sfx_moveTile](https://freesound.org/s/745028/), zagranie kostki;
- `Audio/domino_take_chip.opus` — [Domino_sfx_takeChip](https://freesound.org/s/745032/), dobranie ze stosu.

Źródłem są pliki Freesound `preview-hq-ogg`, pobrane 18 września 2026 r.
Pierwotnie zmieniono tylko nazwy; następnie wykonano opisaną wyżej konwersję.

### Ponowne tasowanie kart

`Audio/card-shuffle.opus` — [Card Shuffle](https://freesound.org/s/201253/)
autorstwa **empraetorius**, na licencji
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Użytkownik dostarczył plik Freesound `preview-hq-ogg` wraz z informacją
licencyjną, pobrany 18 września 2026 r. Pierwotnie zmieniono wyłącznie nazwę;
21 września przekodowano nagranie do Opusa według powyższych parametrów.

### Dodatkowe kroki debla i brzęczyk UNO

`Audio/pong_move_double.opus` pochodzi z dostarczonego przez użytkownika
pliku `pong-move-double.ogg` z jego katalogu Freesound.
`Audio/buzzer.opus` pochodzi z dostarczonego zestawu Quentin Playroom.
21 września 2026 r. przekodowano je do Opusa 144 kb/s VBR, 48 kHz,
z ramkami 20 ms, zachowując mono, metadane i poziomy, bez przycinania.
Oryginały pozostają poza dystrybucją. Nie potwierdzono odrębnych licencji
tych nagrań; nie przypisuje się im na tej podstawie licencji całego projektu.

### Nowe dźwięki Statków

Użytkownik dostarczył z własnego katalogu Freesound pliki `hit_ship1.ogg`,
`hit_ship2.ogg`, `rocket_launch1.ogg`, `rocket_launch2.ogg`, `rocket_launch3.ogg`
i `rocket_miss.ogg`. Początkowo zachowano ich nazwy i zawartość bez przekodowania;
obecne odpowiedniki mają rozszerzenie `.opus` i parametry opisane wyżej.
Nie dodawano niedostarczonego `hit_ship3.ogg`. Wśród materiałów użytkownika
są informacje licencyjne nagrań, ale nie potwierdzono jednoznacznego
przyporządkowania oryginalnych nazw do tych sześciu przemianowanych plików.
Nie przypisuje się im na tej podstawie jednej wspólnej licencji.

### Krowa — słownik i nagrania

Gra Krowa została dostarczona przez **paulinux** w PR #10 z konta GitHub
`paoscripts` (commit `50ea3081e6d6e7a59ee63eee8b7809cb643d7e50`). Bazę
rzeczowników oraz osiem nagrań `Audio/krowa-*` pierwotnie zachowano bez zmiany bajtów.
21 września 2026 r., na polecenie użytkownika, trzy podkłady muzyczne
`krowa-single`, `krowa-race` i `krowa-word-tower` przekodowano do Opusa
144 kb/s VBR stereo (48 kHz, ramki 20 ms), bez filtrów zmiany głośności. Ostatni plik
zmienił rozszerzenie z `.mp3` na `.opus`. Następnie również pięć efektów
przekodowano do tego formatu, zachowując ich liczbę kanałów; muzyki nie
kodowano ponownie. Bazy nie zmieniano. Oryginały zachowano poza dystrybucją.
Metadane podkładu Wieży słów wskazują utwór „Once Again”, Moavii, 2024,
wydawca „Free To Use Music”; zachowano je w pliku Opus. Nie zastępują
one informacji o warunkach licencyjnych.
Nie usuwano powtórzeń ani nie zmieniano kolejności słów. Zgłoszenie nie
podaje pełnego pochodzenia bazy i warunków dystrybucji nagrań; przed
publicznym rozpowszechnieniem należy uzyskać te informacje od autora.
Brak informacji nie jest stwierdzeniem naruszenia ani przypisaniem tym
zasobom licencji całego repozytorium. Definicje wyświetlane na żądanie
pochodzą z serwisu SJP.pl i wskazują to źródło w oknie.
