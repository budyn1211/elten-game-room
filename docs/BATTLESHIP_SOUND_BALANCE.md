# Ściszenie efektów Statków — 18 września 2026

Po zgłoszeniu zagłuszania komunikatów sześć dostarczonych efektów Statków
otrzymuje mnożnik głośności 0,2: `hit_ship1`, `hit_ship2`, `rocket_launch1`,
`rocket_launch2`, `rocket_launch3` oraz `rocket_miss`.

`GameRoomSounds.play` mnoży przez niego dotychczasową głośność odtwarzania.
Przy ustawieniu wszystkich dźwięków i gier na 100% efekty brzmią na poziomie
wcześniejszego ustawienia gier na 20%. Ustawienie gry na 20% dodatkowo je
ścisza do 4%. Nie zmieniamy zapisanych preferencji, komunikatów, pozostałych
efektów ani dźwięków wygranej/przegranej. Bez ustawień użytkownika stosowany
jest ten sam bazowy mnożnik. Wyłączenie dźwięków nadal blokuje odtwarzanie.

Pliki OGG, ich długości oraz zwracane uchwyty odtwarzacza pozostają bez zmian.
Nie dodajemy nowej pauzy ani nie zmieniamy kolejki prezentacji: kolejne
zdarzenie nadal czeka na faktyczne zakończenie poprzedniego dźwięku.

## Weryfikacja

Nowe oczekiwanie testu audio odtworzyło brak ściszenia przed poprawką.
Po poprawce przeszło osiem celowanych uruchomień:

- `battleship_audio_test.rb`: sześć niezmienionych plików, losowanie,
  760 kombinacji efektów/głośności, wyciszenie, domyślna głośność, zachowanie
  uchwytów i preferencji; pozostałe 32 efekty bez dodatkowego ściszenia.
- `battleship_presentation_test.rb`: normalne i binarne wczytanie źródeł;
  ściszone efekty zachowują długość i kolejność, odbiór zdarzeń oraz czat.
- `game_sounds_test.rb`, `volume_and_help_test.rb`,
  `game_event_presentation_test.rb`, `post_228_sounds_test.rb`,
  `domino_sounds_test.rb`.

Składnia trzech zmienionych plików Ruby poprawna. To próby automatyczne,
nie odsłuch na rzeczywistym urządzeniu ani test żywych klientów. Nie
uruchamiano pełnego zestawu testów. Nie zmieniono wersji ani changelogu.

Pierwszy etap zakończono bez pakowania. Następnie użytkownik polecił
ponownie zbudować i podpisać tę samą 2.0.1/229, zachowując changelog
dokładnie bez zmian. Wszystkie 28 punktów PL/EN i wcześniejsza historia
pozostają takie same, bez dopisywania punktu o ściszeniu.

Wyniki bieżącej kontroli źródeł i gotowego artefaktu są zapisywane w
`../diagnostics/battleship-volume-229/SOURCE.json` oraz `PACKAGE.json`.
Przed zastąpieniem paczki zachować jej poprzednią wersję o SHA-256
`d49e824bdc144709a488fa2be3fc6c334ef99156c8e0f465ce51b09003f25d17`.
Bez instalacji, publikacji, GitHuba oraz zmian serwera i profili.
