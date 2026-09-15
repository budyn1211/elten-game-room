# Instrukcje dla agentów pracujących nad ELTEN Game Room

## Stan bazowy

Gałąź `main` zaczyna się od opublikowanego ELTEN Game Room 1.1.0, build 176.
Nie przenoś do niej eksperymentalnych zmian z późniejszych lokalnych buildów bez
osobnego zgłoszenia i przeglądu.

## Sposób pracy

Własne okna aplikacji używają `GameRoomUI::Form` lub
`GameSurfaces::RefreshAwareForm` z referencją `program:`. Wspólny szkielet
zapewnia lokalne F1 jako listę oraz F2/F3 i Shift+F2/F3 do głośności.
Nie dubluj tych klawiszy w klasach gier, nie zmieniaj źródeł ani zapisanych
QuickActions ELTEN-a. Dynamiczną pomoc gry i pokoju aktualizuj przez te same
definicje co rzeczywiste skróty (`GameRoomContextHelp`), nie dopisuj na stałe
tipsów zależnych od fazy. Szczegóły: `docs/VOLUME_AND_HELP_224.md`.

- Najpierw odtwórz problem i wskaż warstwę, która jest jego właścicielem.
- Wprowadzaj małe, spójne poprawki i dodawaj celowany test regresji.
- Korzystaj z nowego, event-driven API ELTEN-a. Nie pisz ręcznych pętli UI.
- Rozszerzaj wspólny szkielet, gdy zachowanie jest wspólne dla rodziny gier;
  nie kopiuj tej samej obsługi do wielu klas gry.
- Nie przenoś reguł gry do `GameScreen` ani szczegółów interfejsu do transportu.
- Nie omijaj `action_for`, `GameRepository` i odtwarzania zdarzeń.
- Nowe karcianki mają korzystać ze wspólnej obsługi ręki, nie kopiować kursora:
  stabilne, unikalne ID kart, `hand_order` w faktycznej kolejności dobierania
  oraz `hand_epoch` identyfikujące właściciela i rozdanie. Szczegóły są w
  `docs/CARD_HAND_CURSOR_213.md`. Innych list, plansz i kości nie oznaczać jako
  ręki; ich zachowanie i odczyty nie mogą być zmieniane przez ten mechanizm.
- Nowa gra z rzeczywistą ręką kart implementuje `playable_card_navigation` i
  grupuje wszystkie legalne akcje według stabilnego ID fizycznej karty. `Z` i
  `Shift+Z` zapewnia wspólny szkielet. Automatyczny ruch wolno oznaczyć tylko,
  gdy karta nie wymaga dalszego wyboru, deklaracji, meldunku ani pakietu.
- Bot wybiera akcję, ale wykonuje ją przez standardową ścieżkę gry.
- Stan stołu i partii synchronizuje stos LiveSessions. Publiczne stoły wyszukuj
  przez discovery i dołączaj do nich bezpośrednio; nie przywracaj bootstrapu
  ani synchronizacji przez Signals.
- Unikaj okresowego odpytywania i pełnej odbudowy formularza. Aktualizacja nie
  może przesuwać fokusu ani powodować zbędnych komunikatów czy dźwięków.

## Weryfikacja

Nowe wspólne funkcje stołu opisuje `docs/IMPLEMENTATION_AFTER_225.md`:

- Wariant/ustawienia Ctrl+R pochodzą z `table_options_announcement` i tych
  samych definicji co dokument ustawień. Nie utrzymuj drugiej listy reguł.
- Licznik S planszówki implementuje przez `remaining_piece_counts(replay)`
  w kolejności graczy; licz faktyczną planszę, nie wynik czy stan początkowy.
  Nie przypinaj literowych skrótów gry do edytowalnego czatu.
- Prywatność jest opcją wspólnego tworzenia stołu, nie ustawieniem każdej gry.
  Nie publikuj prywatnej aktywności. Ważność prywatnego powiadomienia musi
  pochodzić z serwerowego zaproszenia, nie z założonego terminu aplikacji.
- Zapis korzysta ze standardowego replaya i `saved_game_schema_version`.
  Nowa gra określa `save_game_error` dla niebezpiecznych faz albo wyłącza
  zapis przez `supports_saved_games?`. Jeśli wartości zdarzeń zawierają nazwy
  kontrolerów, implementuje `restored_event_value` dla tych konkretnych pól.
  Nie zastępuj graczy ani nie zamykaj stołu przed potwierdzonym zapisem na dysku.

- Uruchom celowane testy podczas pracy.
- Przed pull requestem uruchom `ruby tools/run-tests.rb`.
- Zmiana transportu wymaga testów `live_sessions_*`, `transport_test.rb`,
  `game_sync_test.rb` i scenariusza wielu klientów.
- Zmiana wspólnej powierzchni wymaga testu samej powierzchni oraz co najmniej
  jednej dotkniętej gry.
- Nie zmieniaj numeru wydania ani nie podpisuj paczki bez wyraźnego polecenia
  maintenera.

## Dane, których nie wolno dodawać

Nie zapisuj tokenów MCP, kluczy, certyfikatów, profili ELTEN-a, logów z danymi
prywatnymi, poświadczeń serwera ani podpisanych paczek `.eltsetup`.
