# Poprawki po audycie semantycznym — 25 września 2026

## Stan i zakres

W źródłach wdrożono 22 zatwierdzone pozycje końcowego audytu oraz osobną
poprawkę wieloetapowej wymiany Monopoly. To kontynuacja porządków opisanych
w [MAINTAINABILITY_FOLLOWUP.md](MAINTAINABILITY_FOLLOWUP.md), nie kolejna
przebudowa zasad gier ani nowe wydanie.

Audyt obejmował pełny odczyt 213 plików produkcyjnego kodu Ruby
(64 668 linii), z wyłączeniem dziesięciu wygenerowanych baz danych.
Loadery baz były w zakresie. Nie powtarzano oceny treści pytań,
zewnętrznych zasad, tłumaczeń ani licencji nagrań.

Poniższa tabela opisuje zmiany i celowane regresje lokalne. **Nie uruchamiano
pełnego runnera.** Testy wykonywano w osobnych procesach, z jawnym źródłem
hosta; wyniki grup wymagają deduplikacji, a nie dodawania ich liczników.
Pierwsze niepowodzenia i poprawione powtórzenia zachowano oddzielnie.
Wyniki żywych prób i ich ograniczenia opisano osobno poniżej.

Zmiany są wdrożone w źródłach, ale **nie spakowane ani opublikowane**.
Nie zmieniają numeru wersji, podpisanej paczki ani schematów, ochrony
i limitów serwera. Wczytanie źródeł do pamięci klienta nie jest instalacją.

## Zatwierdzone 22 pozycje

Ścieżki testów w tabeli są względne do katalogu `test/`. Wskazano regresje
bezpośrednie, nie pełną listę powiązanych skryptów.

| Nr | Co zmieniono | Regresja i zachowana granica |
| --- | --- | --- |
| 1 | Tysiąc, Spades i Poker analizują lokalny widok zaakceptowanych zdarzeń przeliczony według miejsc graczy. Spades przenosi go również przez przyrostowy replay. | `participant_decision_events_test.rb`: znacząca historia przed zastępstwem, kolejna akcja, dalsza zamiana i zapis/odtworzenie. Historyczni autorzy, wartości i tekst historii nie są nadpisywani; adresaci dawnych akcji też są mapowani. |
| 2 | Wspólny wybór moderatora Taboo przekazuje `index: 0` jako argument nazwany formularza. Naprawia korektę karty i potwierdzenie powtórzenia tury. | `taboo_moderation_dialog_test.rb`: rzeczywiste handlery i produkcyjny formularz, wybór, anulowanie, Tak/Nie oraz zmiana tokenu tury podczas dialogu. |
| 3 | Replay Yahtzee kończy przyjmowanie zdarzeń zarówno po zwycięstwie, jak i końcowym remisie. | `yahtzee_finished_replay_test.rb`: legalna historia kończąca się remisem, późny rzut, zwycięstwo i przejście do następnej karty. Nie zmieniono punktacji; normalny interfejs już blokował ruch po końcu. |
| 4 | Walidacja aktywności nie myli rosnącego historycznego numeru bota z limitem ośmiu miejsc. Kontrole poprawności identyfikatora i właściwego stołu pozostają. | `activity_projection_context_test.rb`, `bot_name_activity_test.rb`, `table_activity_repository_test.rb`: dziesięć kolejnych nazwanych zastępstw, historia, wielu czytelników i historyczne uprawnienia. |
| 5 | Profil Krowy rozpoznaje dodanie słowa po stabilnym znaczniku pochodzenia, niezależnym od bieżącej rundy i czasu zdarzenia. Migracja rozpoznaje dawne znaczniki, nie kasując ich. | `krowa_profile_identity_test.rb`: dodanie → usunięcie → przelosowanie bez powrotu słowa, nowe świadome dodanie, dawne układy znaczników i nieudany zapis. Nieodwracalny stary hash nie pozwala odzyskać nieznanych dawnych bajtów zmienionych przed migracją. |
| 6 | Cache zamkniętych segmentów historii uczestników uwzględnia cały istotny prefiks oraz opcje i obsadę. Zmieniona treść wymusza rewalidację, bez gromadzenia dawnych wariantów. | `participant_history_cache_content_test.rb`: rzeczywisty Quiz po zamianie, korekta czasu, autora, wartości, opcji i obsady; pełne porównanie z nową instancją. Próba korekty to kontrolowany test kontraktu, nie dowód takiej późnej korekty w żywej sesji. |
| 7 | Transakcje prywatnych odpowiedzi współdzielą koordynator według rzeczywistego magazynu i ścieżki. Natywne instancje Program współdzielą klasowy magazyn; niezależne adaptery pozostają odizolowane. | `hidden_submissions_program_instances_test.rb`, `hidden_submissions_storage_test.rb`: dwa równoległe obiekty, brak zgubionego wpisu, oddzielne ścieżki/aplikacje i odzyskiwanie zapisu Windows. |
| 8 | Błąd odczytu członkostwa nie jest zamieniany na pustą listę osób. Nieznany stan nie uprawnia do zastępowania wszystkich graczy. | `live_sessions_membership_read_error_test.rb`: awaria dostawcy, brak fałszywego odejścia lub bota, powrót prawidłowego członkostwa. Zachowane wcześniejsze strażniki starego zamknięcia i tożsamości sesji. |
| 9 | Usunięto osierocony override odbiornika Signals wywołujący nieistniejącą metodę transportu. Pozostaje neutralny, dziedziczony kontrakt hosta. | Kontrola braku osieroconej ścieżki oraz celowane `invitation_notifications_test.rb`, `game_sync_test.rb` i `connection_recovery_test.rb`. Nie przywracano starego backendu dla historycznych testów. |
| 10 | Synchronizacja Dziennej Krowy odczytuje wszystkie uporządkowane strony po 500 rekordów przez istniejące API `offset`/`order`; nie obcina też lokalnych dni do ostatnich 500. | `krowa_daily_migration_test.rb`: dalsza strona, ponad tysiąc rekordów, częściowy zapis, ponowienie i błąd odczytu. Nie dodano transakcji rozproszonej ani nowej gwarancji równoczesnego pierwszego insertu na dwóch urządzeniach. |
| 11 | Makao ustala wykonawców bez enumeracji wszystkich paczek. Koordynator rozwija rzeczywiste akcje raz dla decyzji. | `makao_active_actors_test.rb`: zachowana kolejność wykonawców, deklaracje i łapanie poza turą, opcje i zegary. Porównanie kontrolne zachowuje 2868 uporządkowanych akcji, wybór paczki oraz dalszy stan RNG. |
| 12 | Powierzchnia i skróty Monopoly pomijają budowę ofert, których nie używają. Formularz ręcznej wymiany i pełne propozycje planera pozostają dostępne. | `monopoly_presentation_actions_test.rb`: brak enumeracji ofert podczas prezentacji, niezmieniona pełna lista dla bota i działający ręczny edytor. Nie zmieniono strategii negocjacji. |
| 13 | Spades współdzieli jedno rozliczenie końcowego liścia oraz niezmienne dane talii. Kosztowny fallback jest leniwy; usunięto nieużywane RNG deterministycznego rolloutu. | `spades_planner_efficiency_test.rb`: równe pełne wyniki analiz, różne obsady/drużyny/style, wybór strategii i dalszy RNG. Rzeczywiste losowanie ukrytych rąk pozostaje; zgodność semantyczna nie oznacza identycznych bajtów wewnętrznego Marshal. |
| 14 | Timer zapowiedzi odczytuje właściwy wspólny zegar bez budowania niepotrzebnego ActionContext i parsowania opcji. | `game_screen_timer_clock_test.rb`: właściwy czas i brak zbędnych odczytów. Zwykła akcja nadal otrzymuje pełny kontekst; nie scalano harmonogramów realtime i turowych. |
| 15 | Odczyt aktywności buduje projekcję jednego snapshotu i wykorzystuje ją dla kolejnych wpisów zamiast odbudowywać ledger dla każdego. | `activity_projection_context_test.rb`: 71 wpisów, historyczne uprawnienia i pojedyncza budowa ledgera. Pełna walidacja oraz odczyty zabezpieczające tożsamość i wyścigi pozostają. |
| 16 | Dźwięki akcji i tasowania korzystają z jednego odczytu historii danego zdarzenia. | `game_sounds_history_scan_test.rb`: pojedyncze wyszukanie, dokładna kolejność i wielość niezależnych sygnałów. Zachowane wyniki, deduplikacja i losowy wybór nagrania. |
| 17 | Obserwator klawiatury Audio Balla zbiera metadane tylko dla aktywnego pola z aktualnym słabym uchwytem. Fokus, rozmycie i attach/detach zarządzają aktywacją. | `audio_ball_keyboard_idle_test.rb` i natywne regresje wejścia: bezczynność bez dodatkowych odczytów, szybkie naciśnięcia/zwolnienia, modyfikatory, czat i okna modalne. Stare zamknięcie pola nie dezaktywuje nowego. |
| 18 | Mosty skrótów i potwierdzeń hosta są neutralne względem przestrzeni aplikacji, wersjonowane i ponownie używają istniejących modułów. Rejestr potwierdzeń ma natywny zarządzany zasób sprzątający. | `game_room_host_bridge_lifecycle_test.rb`: stary → nowy most, 20 przestrzeni, WeakRef/GC w izolowanym natywnym runtime, brak narastania wrapperów i spóźnione sprzątanie. Ten test nie zastępuje pomiaru wszystkich innych korzeni referencji w działającym kliencie. |
| 19 | Discovery, kolejki transportu i kontrolery repozytorium korzystają ze wspólnej granicy retencji. Nieaktywny kontroler jest atomowo wycofywany; jego stara referencja nie rozpocznie kolejnego ruchu. | `auxiliary_room_retention_test.rb`, `room_retention_boundaries_test.rb`: osobny limit 8 nieaktywnych historii i 100 niechronionych uchwytów discovery, pełna lista widocznych stołów, wyścigi, podwójne zamknięcie feedu i ponowne użycie. Aktywne/pending/recovered/I/O/locked/subscribed dane pozostają chronione i mogą przekraczać limity. |
| 20 | Usunięto potwierdzone martwe prywatne helpery modeli, osierocone PaddleFeedback i dawną walidację wejścia Ponga, write-only pola oraz puste potwierdzenia transportu i delegaty. SequenceSource i dawny TurnGate przeniesiono do `test/support/`. | `test_only_bot_support_test.rb`, `pong_current_input_contract_test.rb`, powiązane testy modeli, synchronizacji i transportu. Testy sprawdzają obecny PeerEngine zamiast nieużywanej klasy. Publiczny card_hand_surface, doping/echolokacja, wariant Hash skrótów i mapa surrender_words Krowy nie zostały objęte tym usuwaniem. |
| 21 | Pełny i przyrostowy replay Czwórek używają jednego prywatnego aplikatora, z osobnym przygotowaniem i kopiowaniem stanu. | `four_in_a_row_incremental_contract_test.rb`: legalne/nielegalne ruchy, wygrana, pełny remis i izolacja gałęzi. Oddzielne porównanie 44 śladów/1864 prefiksów zachowuje wszystkie pola Replay; `state: nil` nadal jest poprawne. |
| 22 | Wewnętrzny błąd oceny wiarygodności świata w Spades nie staje się po cichu wagą 1.0. Dociera do istniejącej kontrolowanej granicy planera i diagnostyki. | `spades_likelihood_failure_test.rb`: jawna awaria, pusty plan, `last_failure` i deduplikowane ostrzeżenie. Oczekiwany brak opcjonalnych danych nadal korzysta z dotychczasowych wartości domyślnych; nie udaje się błędu sieci. |

## Monopoly: osobna poprawka wieloetapowego formularza

Formularz wymiany najpierw zapisuje `trade_prepare`, potem zbiera i zwraca
`trade_offer`. Oczekujący interfejs zachowywał replay sprzed pierwszego
zapisu. Kontrola aktualności przed następnym zapisem odrzucała zatem ofertę
jako nieaktualną. Poprawka przekazuje nowe replay/revision do oczekującej
ramki. **Nie wyłącza StaleView**, nie pomija `action_for` ani nie zmienia
negocjacji bota.

`monopoly_staged_trade_screen_test.rb` przechodzi przez rzeczywisty
GameScreen i SessionRunner: propozycję czterech nieruchomości za jedną,
anulowanie na różnych etapach, ponowienie, odpowiedź człowieka/bota
i dalszą turę. Kontrola starej metody odczytanej z podpisanej paczki
odtwarza zatrzymanie na przygotowaniu; nie jest instalacją starej paczki.

Przejrzano analogiczne wieloetapowe wejścia. Państwa-miasta już prawidłowo
aktualizują replay po każdej ocenie inline. Nowy
`categories_review_screen_test.rb` sprawdza trzy oceny, wyczyszczenie,
poprawienie i zatwierdzenie w jednym formularzu: sześć kolejnych rewizji
rzeczywistego wykonawcy i zgodność dwóch repozytoriów. Kontrola negatywna
ze starym replay odtwarza StaleView; nie jest dowodem dawnej awarii tej gry.
UNO Wild, Makao joker, Tysiąc musik, Taboo i Krowa mają inne granice
zapisu: nową iterację odczytu albo lokalne wybory przed pojedynczą akcją.
Nie wprowadzano w nich zapobiegawczego omijania kontroli.

## Ograniczenia pomiarów i regresji

Zmniejszenia liczby operacji dowodzą usunięcia wskazanej zbędnej pracy,
nie przyczyny wszystkich opóźnień i nie gwarantowanego przyspieszenia
całej partii. Zachowano kolejność akcji i losowości; nie zmieniano wag,
budżetów myślenia ani reguł. Kontrolne ślady nie obejmują wszystkich
możliwych partii.

Pierwsze niepowodzenia obejmowały zarówno rzeczywiste reprodukcje przed
poprawkami, jak i błędy pomocników: niepełny fixture remisu, nieaktualny
fokus natywnej kontrolki, brak odczytu po zmianie gospodarza czy założenie
natychmiastowej retencji bez presji limitu. Poprawione powtórzenia nie
zastępują tych wyników. Nie osłabiano istotnych asercji, aby uzyskać sukces.

Nie usuwano zabezpieczeń niepewnego zapisu, prywatnych faz, historycznych
uprawnień, tożsamości sesji ani pełnej rewalidacji. Kolejność blokad
retencji pozostaje Store → Transport → Repository → TurnController,
bez sieci/UI i bez callbacków w przeciwnym kierunku spod tych blokad.

## Końcowa weryfikacja

165 różnych lokalnych skryptów ma poprawny ostatni wynik, bez bieżących
pominięć lub timeoutów. To wiele celowanych etapów, nie ponowienie pełnego
runnera. Wyniki początkowe i poprawione powtórzenia zachowano oddzielnie.

Ukończono 15 scenariuszy na rzeczywistych klientach: Monopoly, Tysiąc,
Spades, Poker, Makao, Taboo, Państwa-miasta, Quiz, Krowa, Cztery w rzędzie,
dwie próby Yahtzee, Audio Ball oraz Pong single i debel z botami.
321 zapisanych kontroli zakończyło się powodzeniem. Nie są to pełne mecze
wszystkich gier: pełne zakończenia rozegrano w Czwórkach i jednej karcie
Yahtzee. W Taboo uczestniczyły cztery konta, zwykle w innych próbach trzy;
wszystkie na jednym komputerze i łączu.

Monopoly sprawdzono po zwykłych rzutach i zakupach, bez sztucznego
nadawania nieruchomości: anulowanie i ponowienie formularza, oferta
czterech nieruchomości za jedną człowiekowi i botowi, odpowiedzi obu
oraz dalszy rzut. Partie z botami obejmowały znaczącą historię przed
zastępstwem, rzeczywistą decyzję planera i powrót człowieka. Taboo
przeszło oba poprawione dialogi; Państwa-miasta sześć kolejnych rewizji
oceniania. Krowa używała izolowanego profilu pamięciowego, bez trwałej
zmiany słownika użytkownika.

Yahtzee zakończyło naturalną pełną kartę wynikiem 20/19/23 po 82 akcjach;
nie uzyskano remisu i nie ponawiano partii, by go wymusić. Późny rzut po
końcowym remisie pozostaje dokładną kontrolowaną regresją lokalną.
Oddzielna próba retencji obejmowała 11 pustych prywatnych stołów przez
natywne API; nie zaliczano ich do rozegranych partii.

Trzy nieukończone pierwsze próby pomocników są zachowane, a nie wliczone
do 15 ukończonych: leniwie niewczytana klasa podczas pomiaru realtime,
za długa nazwa próbnego stołu i nieobjęty pomiarem osobny model planera.
Poprawiono pomocniki, nie osłabiono produkcyjnych zabezpieczeń.

Po wielu przeładowaniach w każdym kliencie jest jedna aktualna warstwa
mostu skrótów i potwierdzeń. Izolowany test potwierdza ich zwalnianie przez
GC, lecz **nie dowiedziono pełnego zwolnienia całego starego runtime
w długo działających klientach**. Ograniczona nieinwazyjna diagnostyka
nie wskazała jednoznacznego źródła pozostałych referencji. Nie zmieniano
hosta ani nie usuwano jego zasobów na podstawie tego niepełnego wyniku.

Własne stoły i sondy prób posprzątano. Cztery klienty pozostawiono na
ekranie głównym z 223 aktualnymi źródłami w pamięci, bez aktywnych
formularzy testowych. Nie instalowano paczki, nie zmieniano wydania,
schematów lub ochrony serwera ani nie publikowano zmian.

Należy rozróżnić rzeczywiste UI/API i przyjęte zdarzenia od izolowanych
sond hosta. Szczególnie sztuczny duży zbiór migracji, korekta dawnego
prefiksu, kontrolowany wyścig i późny rzut po remisie są lokalnymi
regresjami, nie automatycznie żywymi partiami. Stan modelu ani wywołanie
haku mowy nie oznacza odsłuchu; kilka klientów jednego komputera nie
zastępuje różnych komputerów i łączy.
