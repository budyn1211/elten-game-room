# Game Room 2.0.1 — build 229

## Polski

- Przepisano zasady wszystkich 23 gier po polsku i angielsku. Dodano pełniejsze wyjaśnienia, przykłady oraz opisy wariantów i ustawień dostępnych w Game Roomie.
- Skróty klawiszowe w grze są teraz listą pod strzałkami. W trakcie partii korzysta ona z tej samej aktualnej pomocy pola gry co F1. Enter lub Escape zamyka listę; same zasady pozostają jednym dokumentem z nagłówkami.
- Odbiór powiadomień o nowych stołach nie czeka już na zapis na dysku, co usuwa jedną z przyczyn chwilowego przycinania interfejsu. Sporadyczny zapis informacji o obsłużonym stole odbywa się w tle.
- Powiadomienie o nowym stole podaje właściciela, grę i typ powiadomienia, bez dwukrotnego powtarzania słów Nowy stół.
- Zmiana języka pytań lub kart w Quiz Party i Taboo pozostawia fokus na języku. Zestawy aktualizują się bez przestawiania kursora; przechodzisz do nich Tabem.
- Rękę można sortować przez Shift+C według koloru, Shift+H według rangi oraz Shift+M według kolejności otrzymania. Ponowne Shift+C lub Shift+H odwraca kierunek sortowania. Dotyczy to UNO, Makao, Rummy, Spades, Tysiąca, 99 i ręki wymienianej w Pokerze. Zachowano domyślny układ każdej gry, kartę pod kursorem i zaznaczone paczki.
- Pomoc F1 w Makao uwzględnia teraz Shift+Enter do dodawania karty do paczki i usuwania jej z paczki.
- Poprawiono mieszanie polskich i angielskich tekstów w zasadach i skrótach Taboo. Pomoc używa języka interfejsu, niezależnie od języka kart.
- Niezależne efekty dźwiękowe mogą być odtwarzane jednocześnie, również efekt waleta i progu wywołane tym samym ruchem w 99.
- Dodano dźwięki odłożenia punktów w Farkle, trafienia dokładnie w 33 lub 66 w 99 oraz zgłoszenia mariażu w Tysiącu.
- Zmieniono dźwięki wygranej i przegranej całej partii. Gracz lub drużyna słyszy teraz przegraną już przy trwałej eliminacji, bez ponownego odtwarzania na końcu tej samej partii. Dźwięki wyników pojedynczych rund pozostają bez zmian.
- Pole Stół prywatny jest teraz częścią formularza tworzenia stołu, obok ustawień gry, zamiast osobnego okna.
- Nowe gry są domyślnie zaznaczane w widgecie, a zapisane ręczne odznaczenia są zapamiętywane. W starszych ustawieniach jednorazowo włączane są także Rummy, Domino, Mexican Train, Scrabble, Taboo i Biblios.
- Dodano osobne dźwięki rozdawania, zagrywania i dobierania kostek ze stosu w Domino i Mexican Train.
- Możesz ograniczyć widget i powiadomienia o nowych stołach do swoich kontaktów. Oba filtry są domyślnie wyłączone. Zaproszenia tylko od kontaktów korzystają teraz z tej samej listy kontaktów, aktualizowanej w tle.
- Ujednolicono ustawienie czasu na ruch w UNO, Makao, Domino, Mexican Train, Rummy, Scrabble, 99 i Pokerze. Limit jest domyślnie wyłączony. Skutki przekroczenia czasu zależą od zasad gry; program nie wybiera i nie zagrywa za Ciebie karty.
- W 99 przekroczenie czasu na ruch kosztuje jeden żeton i przekazuje turę następnemu graczowi.
- W obu wariantach Pokera przekroczenie czasu oznacza pas. Wyjątkiem jest gracz all-in podczas wymiany: zachowuje karty i nadal bierze udział w rozstrzygnięciu. Poprawiono też rozliczanie pul bocznych, gdy gracze pasują podczas wymiany.
- Ctrl+R podaje krótsze ustawienia stołu, pomijając wyłączone zegary i opóźnienia. Nazwy zestawów kostek Domino są przetłumaczone również w formularzu tworzenia stołu.
- W sekcji skrótów w zasadach każdy skrót pola gry ma osobny wiersz. Nie ma tam już obsługi czatu ani skrótów globalnych.
- Ponowne przetasowanie wyczerpanej talii w trakcie rozdania ma teraz krótki komunikat i własny dźwięk w UNO, Makao, 99, Rummy i Pokerze dobieranym.
- Punktacja pod S jest odczytywana od najwyższego wyniku do najniższego, a wyeliminowani gracze lub drużyny na końcu. Ich rzeczywiste wyniki pozostają bez zmian.
- Dodano Statki autorstwa Dawida Piepera: dwa zestawy floty, ręczne rozstawianie, grę z komputerem, plansze obserwatora i końcową kontrolę flot. Zapisywanie tej gry na później nie jest jeszcze dostępne.
- Dodano Mankalę autorstwa Dawida Piepera, z odmianami Oware, Ayoayo i Kalah oraz trzema poziomami komputera. Obie nowe gry mają przystępne zasady po polsku i angielsku, pomoc klawiszową i dźwięki ruchów.
- Na początku Statków każdy gracz może wybrać losowe lub ręczne rozstawienie floty. Losowanie uwzględnia wybrany zestaw statków i zasadę odstępów między nimi.
- Statki mają nowe dźwięki startu rakiety, trafienia i chybienia. Kolejne zdarzenie czeka na zakończenie poprzedniego dźwięku, ale czat i odbieranie ruchów nadal działają. W pozostałych grach dźwięki wciąż mogą się nakładać.
- Po wybraniu gry przy tworzeniu stołu fokus znów trafia na początkową instrukcję. Tab przechodzi następnie do pola Stół prywatny i ustawień gry.
- Naprawiono pustą listę skrótów w zasadach otwieranych przez Ctrl+F1, między innymi w Scrabble. Przy otwieraniu zasad zachowywana jest teraz aktualna pomoc pola gry.
- Dodano Krowę od paulinux: zgadywanie polskich słów w zagadce dnia, grze solo, Wyścigu lub wspólnej Wieży Słów, z własną galerią i opcjonalnymi rankingami.

## English

- Rewritten the rules of all 23 games in Polish and English, with clearer explanations, examples and descriptions of the variants and settings available in Game Room.
- In-game keyboard shortcuts are now an arrow-key list. During a game, it uses the same current game-field help as F1. Enter or Escape closes the list; rules remain one document with headings.
- Receiving new-table notifications no longer waits for disk writes, removing one source of temporary interface stalls. The occasional record of a handled table is saved in the background.
- New-table notifications give the owner, game and notification type without repeating New table twice.
- Changing the question or card language in Quiz Party and Taboo keeps focus on the language. Sets update without moving the cursor; use Tab to reach them.
- Card hands support Shift+C to sort by suit or colour, Shift+H by rank, and Shift+M by receipt order. Pressing C or H with Shift again reverses that sorting direction. This covers UNO, Makao, Rummy, Spades, Tysiac, 99 and Poker's exchange hand, preserving each game's default order, the selected card and card packages.
- Makao's F1 help now includes Shift+Enter for adding a card to or removing it from a package.
- Fixed mixed Polish and English text in Taboo's rules and keyboard help. Help follows the interface language, independently of the card language.
- Independent sound effects can play together, including the jack effect and a threshold effect caused by the same move in 99.
- Added sounds for banking points in Farkle, reaching exactly 33 or 66 in 99, and declaring a marriage in Tysiac.
- Replaced the sounds for winning and losing a whole game. A player or team now hears the defeat sound when permanently eliminated, without hearing it again at the end of that game. Round-result sounds are unchanged.
- The Private table checkbox is now part of the table creation form, alongside the game settings, instead of a separate window.
- New games are selected in the widget by default, while saved manual deselections are remembered. Older settings also enable Rummy, Domino, Mexican Train, Scrabble, Taboo and Biblios once.
- Domino and Mexican Train now have distinct sounds for dealing tiles, playing a tile and drawing from the boneyard.
- You can limit the active-tables widget and new-table notifications to your contacts. Both filters are off by default. Invitations restricted to contacts now use the same background-updated contact list.
- Turn-time settings are now consistent across UNO, Makao, Domino, Mexican Train, Rummy, Scrabble, 99 and Poker. The limit is off by default. Timeouts follow each game's rules and never choose and play a card for you.
- In 99, exceeding the turn-time limit costs one token and passes the turn to the next player.
- In both Poker variants, exceeding the time limit folds your hand. During the draw, an all-in player instead keeps their cards and remains in the showdown. Side pots are also settled correctly when players fold during the draw.
- Ctrl+R gives shorter table settings, omitting disabled clocks and delays. Domino set names are also translated in the table creation form.
- Keyboard help in the rules lists each game-field shortcut separately, without chat controls or global shortcuts.
- Reshuffling an exhausted deck during a deal now has a short announcement and its own sound in UNO, Makao, 99, Rummy and draw Poker.
- Score announcements under S are ordered from highest to lowest, with eliminated players or teams last. Their actual scores are preserved.
- Added Battleship by Dawid Pieper: two fleets, manual placement, a computer opponent, spectator boards and a final fleet check. Saving this game for later is not yet available.
- Added Mancala by Dawid Pieper, with Oware, Ayoayo and Kalah variants and three computer strengths. Both new games include clear Polish and English rules, keyboard help and move sounds.
- At the start of Battleship, each player can choose random or manual fleet placement. Random placement follows the selected fleet and ship-spacing rules.
- Battleship has new rocket-launch, hit and miss sounds. The next event waits for the current sound to finish, while chat and receiving moves remain available. Other games keep overlapping sound effects.
- After selecting a game to create a table, focus starts on the opening instructions again. Tab then moves to Private table and the game settings.
- Fixed the empty in-game shortcuts list opened through Ctrl+F1, including in Scrabble. It now retains the current game-field help when opening the rules.
- Added Krowa by paulinux: guess Polish words in the daily puzzle, solo play, Race or cooperative Word Tower, with a personal gallery and optional leaderboards.
