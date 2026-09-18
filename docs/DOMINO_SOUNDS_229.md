# Dźwięki kostek — przebudowanie 2.0.1/229

Na polecenie użytkownika z 18 września 2026 dodano trzy dostarczone nagrania
do Domino i Mexican Train. Wspólny selektor korzysta z zaakceptowanych
wpisów historii: `deal` → `domino_refill`, `play` → `domino_move_tile`,
`draw` → `domino_take_chip`. W Rummy pozostają dotychczasowe dźwięki kart.

Dźwięk rozdania zastępuje tasowanie kart, a pozostałe zastępują ogólne
efekty zagrania/dobrania. Jedna akcja dobierania do skutku ma jeden efekt,
nie serię dla każdej kostki. Dobranie po upływie czasu również go wywołuje;
pas bez dobrania, odrzucony ruch i samo przeglądanie kostek — nie.

Efekty są wspólne dla własnych i cudzych ruchów oraz botów, słyszalne także
obserwatorom. Zachowano nakładanie z wynikami rund i partii, głośność gier
i główną oraz wyciszenie. Istniejący `GameScreen#process_new_events`
odpowiada za brak powtórzeń podczas odświeżania i odtwarzania historii.
Bez zmian zasad, strategii, komunikatów, protokołu, zegarów i żądań sieciowych.

## Pliki

Pliki skopiowano bez modyfikacji nagrań z lokalnego folderu freesound.
Źródła autora poenia i dostarczoną informację CC0 zapisano w
`THIRD_PARTY_NOTICES.md`. Potwierdzono odczyt całego strumienia audio
przez FFmpeg i zgodność kopii SHA-256:

- `domino_refill.ogg`: 37 299 bajtów, 1,286 s,
  `e563e8c0a93654f91cdd890b60cad9bcf36134d4799b191e2c8a3fbb6e35c784`;
- `domino_move_tile.ogg`: 13 220 bajtów, 0,429 s,
  `0abca16407716981c716c99bea5237c32c2d95b85a17c5f0d9d16ca36dd6dd43`;
- `domino_take_chip.ogg`: 14 242 bajty, 0,429 s,
  `306be52b5f5363cdf98b4eae0582deb5b342d32a869a64b9d69969e539645e15`.

Oba manifesty i lista akceptowanych zasobów zawierają trzy nowe dźwięki.
Test `game_sounds_test` najpierw odtworzył brak właściwego efektu rozdania,
następnie przeszedł po wdrożeniu. Nowy `domino_sounds_test` sprawdza oba
silniki, zaakceptowane/odrzucone akcje, dobieranie pojedyncze i seryjne,
timeout, boty, widzów, wyniki oraz rzeczywistą ścieżkę przetwarzania
zdarzeń ekranu z atrapą odtwarzacza. Nie jest to test słuchowy klienta.
Przyjmuje też ścieżkę paczki do binarnego ładowania jej kodu.

## Wydanie

Użytkownik polecił przebudować podpisaną 2.0.1, zachowano build 229.
W tym samym changelogu PL/EN zachowano dotychczasowe 11 punktów i dodano
trzy: prywatność we wspólnym formularzu, domyślne gry widgetu i dźwięki
kostek. Nie dodano drugiego nagłówka tego samego wydania.

Przed nadpisaniem paczki zachować dotychczasowy podpisany artefakt 229
o SHA `0ac855519fa89f27fbacea4d90c809d0b5b4699bbed751c81df6c0557a180e92`
jako `ELTEN-Game-Room-build-229-before-privacy-widget-domino-signed.eltsetup`.
Końcowe wyniki źródeł i gotowej paczki zapisują się poza repozytorium:
`diagnostics/release-2-0-1-refresh/SOURCE.json` i `PACKAGE.json`.
Ten dokument opisuje zakres, nie stanowi potwierdzenia podpisania.
Bez pełnego runnera, instalacji, publikacji, GitHuba, zmian profili i serwera.
