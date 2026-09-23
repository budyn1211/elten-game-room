# Testowanie i budowanie

## Testy bez ELTEN-a

Testy logiki gier są samodzielnymi skryptami Ruby. Testy narzędzi tłumaczeń
wymagają dodatkowo standardowego gema GetText:

```console
bundle install --gemfile tools/Gemfile.i18n
```

Zalecana jest wersja Ruby 4.0, zgodna ze środowiskiem bieżącego ELTEN-a.

```console
ruby tools/run-tests.rb
```

Runner zatrzymuje się po pierwszym nieudanym teście i zwraca niezerowy kod.

## Tłumaczenia interfejsu

Edytuj jeden plik PO na język, np. `locale/PL.po`. Po edycji uruchom
`ruby tools/translations.rb compile PL`, następnie
`ruby tools/translations.rb check PL`. MO i dawne widoki JSON są generowane
z PO, nigdy odwrotnie. Słowniki wyrazów, pytania i karty gier nie należą do
tej migracji. Pełna instrukcja: `locale/README.md`.

## Uruchomienie ze źródeł

Do testu integracyjnego umieść katalog aplikacji tak, aby `__app.rb` znajdował
się w katalogu programu deweloperskiego ELTEN-a, na przykład
`dev_apps/game_platform/`. Uruchom ELTEN-a ze źródeł lub w trybie debugowania i
otwórz ELTEN Game Room z menu programów.

Używaj oddzielnego profilu testowego, jeśli test może zmieniać dane stołów.
Nie kopiuj profilu, logów ani ustawień MCP do repozytorium.

## Paczka niepodpisana

### Domyślny format nagrań

Wszystkie efekty, głosy, pętle i muzyka w `Audio/` mają format **Ogg Opus,
144 kb/s VBR, 48 kHz, ramki 20 ms**, tryb audio i complexity 10.
Zachowuj oryginalne mono/stereo, poziom głośności, pełne nagranie i metadane.
Nie zwiększaj mono do stereo, nie usuwaj autorstwa i nie normalizuj przy okazji.

```console
ruby tools/encode_audio.rb C:/originals/new-sound.wav C:/src/elten-game-room/Audio/new-sound.opus
```

Narzędzie wymaga FFmpeg z libopus i FFprobe w PATH; można też podać ich
ścieżki jako trzeci i czwarty argument. Odmawia nadpisania istniejącego pliku.
Oryginał zachowaj poza paczką. Do następnego kodowania używaj oryginału,
nie poprzedniej stratnej konwersji. Poprawnego Opusa 144 VBR nie koduj ponownie.
Identyfikator zasobu pozostaje bez rozszerzenia, np. `new-sound`.

Pakowanie nie wykonuje konwersji: odrzuca inne formaty oraz plik tylko
przemianowany na `.opus`. Sprawdza nagłówek Ogg/Opus; bitrate i ramki
zapewnia profil narzędzia, nie samo rozszerzenie. Przed przyjęciem nagrań
sprawdź dekodowanie przez BASS/bassopus ELTEN-a, restart, pętle używane przez
grę, długość, poziomy i odsłuch. Kontrola techniczna nie zastępuje odsłuchu.

### Staging instalatora

Paczki buduje narzędzie z repozytorium ELTEN-a, ale nie należy przekazywać
mu całego katalogu projektu. Najpierw przygotuj nowy, nieistniejący katalog
wydania poza repozytorium. Przykład:

```console
ruby C:/src/elten-game-room/tools/release_files.rb C:/src/elten-game-room C:/build/game-room-runtime
ruby C:/src/elten3/tools/build-eltsetup.rb --unsigned C:/build/game-room-runtime C:/build/ELTEN-Game-Room.eltsetup
```

Ruby używane do budowania musi mieć zależności wymagane przez narzędzie ELTEN-a,
w szczególności `zstd-ruby`. Najprościej użyć środowiska uruchomieniowego
przygotowanego razem ze źródłami ELTEN-a.

## Paczka podpisana

Podpisaną paczkę przygotowuje wyłącznie autor wydania:

```console
ruby C:/src/elten3/tools/build-eltsetup.rb --cert C:/private/author.crt.pem --key C:/private/author.key.pem C:/build/game-room-runtime C:/build/ELTEN-Game-Room-signed.eltsetup
```

Certyfikat i klucz muszą pozostać poza repozytorium. Pliki `.eltsetup` również
nie są śledzone — dystrybucja odbywa się przez katalog programów ELTEN-a.

`tools/release_files.rb` jest wspólną listą zawartości wydania. Zachowuje kod,
dane, audio, gotowe tłumaczenia, manifesty, licencje i informacje o źródłach.
Pomija testy, narzędzia, dokumentację roboczą, raporty importu, materiały
redakcyjne i źródłowe katalogi tłumaczeń. Te pliki pozostają w repozytorium.
Skrypt sprawdza zależności Ruby, obecność wymaganych zasobów i zgodność kopii.
W tym workspace `../tools/build-game-room.ps1` wykonuje staging automatycznie
i nadaje mu krótką ścieżkę na Windows. Zbyt długa ścieżka może spowodować
puste wyniki globu narzędzia ELTEN-a; sama poprawna sygnatura nie dowodzi
obecności kodu w paczce.

## Przygotowanie wydania

1. Wykonaj kontrole zgodnie z zatwierdzonym zakresem. Przy zmianie samego
   pakowania sprawdź `test/release_files_test.rb` oraz celowane testy binarne,
   w tym `test/release_binary_loading_test.rb GOTOWA_PACZKA`. Testy i ich
   pomocniki pochodzą z repo; kod produkcyjny musi pochodzić z instalatora.
2. Numer wersji, build i changelog zmieniaj tylko zgodnie z poleceniem autora.
   Ponowne wydanie tego samego buildu nie wymaga nowego wpisu changelogu.
3. Przygotuj staging, zbuduj podpisaną paczkę i zweryfikuj manifesty, runtime,
   podpis autora, dokładną listę plików oraz zgodność każdego pliku ze źródłem.
   Nie maskuj braków danych wczytaniem ich z lokalnego repozytorium.
4. Wykonaj celowane wczytanie gotowej paczki, także danych ładowanych na
   żądanie, zasad, tłumaczeń i wymaganych dźwięków. Nie umieszczaj testów
   w instalatorze tylko po to, żeby przechodziły stare założenia narzędzi.
5. Instalacja, publikacja i wysyłka na GitHub wymagają osobnego polecenia.
