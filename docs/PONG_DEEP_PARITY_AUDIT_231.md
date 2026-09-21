# Axel Pong — ponowny, szczegółowy przegląd zgodności

Stan źródeł: 20 września 2026. Wersja nadal 2.0.2/build 231. Ten raport
nie oznacza nowego wydania ani usunięcia wszystkich opisanych różnic.

Aktualizacja po audycie: F02–F08 poprawione w źródłach; F01 wyłączony
z prac przez użytkownika. Szczegóły, dowody i zakres zatwierdzonej ponownej
paczki: [PONG_PARITY_FIXES_231.md](PONG_PARITY_FIXES_231.md). Poniższe opisy
niezgodności dokumentują stan przed tymi naprawami.

## Co porównano i jak mocne są dowody

Wzorcem jest odzyskany **dźwiękowy tryb** Axel Pong 1.26.4.178. Osobno
sprawdzono dostępne fragmenty instalacji Store 1.26.3.170. To dwie wersje,
nie jeden identyczny program. Wcześniejsze porównanie bajtkodu potwierdza
identyczność całych modułów piłki, reguł Arcade i punktacji; pozostałych
modułów nie wolno automatycznie uznać za jednakowe.

Materiał pozostaje poza repozytorium, w katalogu roboczym:

- `outputs/axel-pong-recovery-20260920/recovered_modules` — rekonstrukcje
  ze sprawdzonym bajtkodem i plikami `*.checks.json`;
- `verified_excerpts` oraz `installed_store/verified_excerpts` — sprawdzone
  ciała funkcji, niekoniecznie kompletne otoczenie modułu;
- `port_check/net_gameplay_regions.py` — sprawdzone gałęzie komunikatów
  rozgrywki, oddzielone od oryginalnego logowania/usługi sieciowej;
- `outputs/axel-pong-analysis-20260920/disassembly` — kontrola instrukcji
  również tam, gdzie wynik dekompilatora jest niepełny.

Nie uruchamiano odzyskanego Pythona. Nie traktowano samych nazw funkcji,
komentarzy ani plików `pylingual_unverified` jako dowodu działania.
Nie przenoszono oryginalnego kodu, danych dostępowych ani usług do repo.
Grafika i lobby są poza zakresem na polecenie użytkownika. Zależności
interfejsu, które zmieniają przebieg meczu, nadal należą do audytu.

## Różnice stwierdzone w audycie, przed poprawkami F02–F08

### F01. Osobna pomoc zatrzymuje obsługę lokalnej gry — wysoki priorytet

Oryginalne `ap_input._modal_pump_frame` obsługuje sieć, piłkę, serwis,
efekty i głosy także w modalnym menu. U nas `Client#attach_view` dodaje
timer wyłącznie do formularza gry. `GameRoomUI::Form#show_game_room_help`
wchodzi w `dialog.wait`, bez przekazania tego timera. Natywny
`Form#wait/update` aktualizuje timery tego formularza, nie rodzica.

To różnica potwierdzona ścieżką kodu: podczas tego okna brakuje wywołań
lokalnego klienta Ponga. Z botem zatrzymuje się symulacja właściciela;
w meczu ludzi drugi klient może działać dalej. Długi brak obsługi może
uruchomić odzyskiwanie kanału. **Nie jest to zwykłe pole czatu** na tej samej
planszy i nie dowodzi przyczyny wszystkich wcześniejszych zgłoszeń.

Naprawa: czasowo przekazywać obsługę klienta czasu rzeczywistego do okna
modalnego, bez sterowania paletką i bez równoległego drugiego timera.
Objąć pomocą, zasadami i pozostałymi rzeczywiście modalnymi oknami.
Nie pompować ręcznie całego interfejsu, nie zmieniać timerów innych gier.

### F02. Właściciel-obserwator zmienia zasięg odbicia

Oryginał: ręczne odbicie ma tolerancję 4 jednostek po stronie serwera
i 4,5 po stronie gościa (`ShootBall`, `Distance`). U nas w zwykłym meczu
jest analogicznie, ale `PeerPlay#reset_rally` daje obu stronom rolę
gościa, jeżeli właściciel tylko obserwuje: `guest: [0, 1]`.

Próba dwóch klientów potwierdziła **4,5 / 4,5**, zamiast **4 / 4,5**.
Sposób założenia stołu zmienia zatem łatwość odbijania. Dotyczy także
dodatków do zasięgu przy automatycznym odbijaniu.

Naprawa: oddzielić rolę w fizyce od właściciela tabeli/kanału. Przy
obserwującym właścicielu wyznaczyć jednego grającego jako stronę serwera
fizyki, deterministycznie dla wszystkich. Nie zmieniać autorytetu zapisu
punktów na serwerze ELTEN-a. Ujednolicenie obu zasięgów byłoby już nową
regułą, a nie wiernym przeniesieniem.

### F03. Przeciwnik przy brzegu wydaje inny odgłos albo żaden

Oryginalna gałąź odbioru `P` odtwarza krok wewnątrz boiska, a dźwięk
brzegu dla pozycji 1/29. Kolejne próby ruchu na zewnątrz wysyłają także
pozycję graniczną. U nas odbiór pozycji wywołuje zwykłe `Engine#move_to`:
dojście do 29 daje krok, a następna pozycja 29 już nie daje niczego.

Odtworzone: **dojście → `step`; kolejna próba → brak efektu**.
Wzorzec: **`edge`, `edge`**. Lokalny odgłos własnej paletki jest osobną
ścieżką i nie usuwa tego problemu przeciwnika.

Naprawa: przesyłać licznik/zdarzenie próby ruchu przy brzegu, a nie
wnioskować o nim z okresowej niezmienionej pozycji. Samo odgrywanie brzegu
przy każdym pakiecie wywołałoby nieustanny dźwięk stojącej paletki.

### F04. Odgłos paletki przeciwnika nie zmienia panoramy w trakcie nagrania

`ap_sounds.UpdateSounds` w obu sprawdzonych wersjach odświeża panoramę
odgłosów paletki/brzegu przeciwnika względem bieżącej pozycji słuchacza.
Nasze `Audio#play_effect` ustawia ją tylko przy rozpoczęciu efektu;
`Audio#tick` później zmienia jedynie głośność.

Próba: przeciwnik na 20, gracz przesuwa się z 15 na 25. Odtwarzany krok
powinien przejść z prawej na lewą stronę. Pozostaje z panoramą **+0,4152**,
zamiast **−0,4152**. Piłka ma osobną bieżącą aktualizację i nie wykazuje
tego konkretnego braku. Słyszalność zależy od długości nagrania i momentu
ruchu; to nie stwierdzenie, że każdy krok brzmi źle.

Naprawa: aktualizować parametry już grających właściwych efektów, bez
ponownego odtwarzania. Nie stosować tego bezrefleksyjnie do wszystkich
dźwięków — np. nagranie wyniku ma pozostać na środku.

### F05. Tarcza przeciwnika ma połowę oryginalnego mnożnika

Oryginał: domyślne `Config_VolumeOpSteps=100` (sprawdzone w inicjalizacji),
tłumienie na dystansie 20 daje 0,2, a odbicie tarczą mnożnik 4,55:
**0,2 × 1 × 4,55 = 0,91**. U nas `OPPONENT_SHIELD_HIT_LEVEL=0.455`.

Nie mylić ze świadomie zachowanym lektorem 25% ani zatwierdzonymi
poziomami paletek 50%/20%. Poprzedni test utrwalał 0,455 jako oczekiwanie,
więc jego przejście nie dowodzi zgodności z oryginałem.

Naprawa: przywrócić 0,91 albo jawnie zatwierdzić to ściszenie jako odstępstwo.
W tym audycie głośności nie zmieniono.

### F06. Inne ograniczanie głośności kanałów tarczy

Oryginalne `SoundMgr._apply_panvol` najpierw liczy lewy/prawy kanał,
stosuje głośność główną, następnie ogranicza **każdy kanał** do 1.
U nas poziom własnej tarczy 2,0 jest wprost przekazywany do Sound ELTEN-a;
brakuje odwzorowania tej operacji stereo. Próba potwierdza wartość 2,0
na granicy API, nie faktyczny poziom na urządzeniu audio.

Naprawa wymaga przeliczenia obu kanałów po ustawieniach głośności,
z zachowaniem panoramy. Nie wystarczy wszędzie zamienić 2 na 1: przy
ściszeniu do połowy oryginał daje 1, a takie uproszczenie dawałoby 0,5.
Ostateczny wynik backendu BASS wymaga też sprawdzenia/odsłuchu.

### F07. Obie strzałki przytrzymane jednocześnie

Oryginalny `HandleInput` obsługuje osobne naciśnięcia lewej/prawej, a dla
dalszego przytrzymania pierwszeństwo daje lewej. `PongField#update`
odejmuje boolowskie stany, więc oba naraz dają zero — zatrzymanie.

Naprawa: rozdzielić impulsy klawiszy od kierunku przytrzymania. Samo
ustawienie priorytetu lewej nie odwzoruje pierwszego naciśnięcia obu.
To drobna różnica sterowania, nie przyczyna wolnego zwykłego ruchu.

### F08. Minimalna różnica końcówki ustawiania bota do serwisu

W `_move_bot_for_serve`, gdy do celu zostało najwyżej 0,05 jednostki,
oryginał ustawia dokładny cel i wraca bez dopisywania kroku dźwiękowego.
Nasze `Bot#move_toward` zawsze używa `Engine#move_to`, doliczając tę
resztę do akumulatora odgłosu kroków. Sama końcowa pozycja jest taka sama,
ale w skrajnym momencie może wcześniej uruchomić następny odgłos.

Niski priorytet; nie stwierdzono na tej podstawie gorszej strategii bota.
Naprawa: wiernie odwzorować osobną, cichą korektę ostatnich 0,05 jednostki.

## Braki funkcjonalne, a nie błędy wzoru piłki

1. **Ręczna pauza i wznowienie meczu.** Istnieją w oryginalnym menu
   rozgrywki i `_pause_toggle`; brak ich w naszej powierzchni. Zatrzymanie
   z powodu sieci i zakończenie partii przez Ctrl+Q nie są odpowiednikiem.
   Potrzebna jest wspólna, potwierdzana pauza obu graczy, bez losowania
   nowej wymiany. Samo zatrzymanie lokalnego timera byłoby błędem.
2. **Wybór strony przez obserwatora.** Oryginał ma wybór host/client
   (`_spectator_select_view` i odwrócenie stanu widza). U nas audio i wynik
   używają `@side || 0`, bez takiego wyboru. Wybór powinien pozostać lokalny
   i nie może zmieniać praw gracza ani kierunku zapisywanych zdarzeń.
3. **Automatyczne odbijanie osobno dla gracza.** Oryginał zapisuje
   `Config_AutoReturnEnabled` jako osobistą preferencję. U nas to jedna
   opcja stołu dla obu ludzi. To zmiana reguły używania ułatwienia, nie
   tylko inny układ okna. Przed zmianą trzeba ustalić, czy zachowujemy
   świadomie symetryczne zasady stołu, czy kopiujemy osobisty przełącznik.
4. **Osobne suwaki paletki własnej, przeciwnika i lektora.** Oryginał
   pozwala je niezależnie ustawiać w `GameSettingsMenu`. U nas są stałe
   proporcje i wspólne ustawienia Game Roomu. Domyślne 50%/20% i lektor
   25% są zgodne z ostatnią decyzją użytkownika, ale swoboda regulacji
   nie jest przeniesiona. To nie wymaga kopiowania oryginalnego menu.

## Poprawione teraz w ramach wcześniejszego polecenia dotyczącego myszy

- Dodano opt-in M, lokalne poziome ruchy i lewy przycisk, bez przebudowy
  ELTEN-a, globalnego hooka ani grafiki. Jest też ochrona czatu, pomocy,
  obcego okna i przycisku przytrzymanego podczas pauzy.
- Odtworzono kolejność z dźwiękowego trybu: ruch klawiaturą, odbicie,
  ruch myszą. Nie przeniesiono omyłkowo pierwszeństwa klawiatury z trybu
  graficznego. Lewy przycisk ma impuls naciśnięcia oraz osobno obronę
  przytrzymaniem tuż przed bramką, tak jak w oryginale.
- Poprawiono odgłos **własnej** próby ruchu myszą poza brzeg. Nie oznacza
  to naprawy osobnego F03 dotyczącego przeciwnika po sieci.
- Poprawiono boczny limit prędkości przed ruchem przy małej prędkości
  wzdłużnej. Dla `x=15`, bocznej 0,255 i wolnego lotu wzorzec daje
  następne `x=15,25`; wcześniejszy kod dawał 15,255. Przy szybszym locie
  nadal prawidłowo działa osobne skalowanie do 2,8.

Te poprawki są tylko w źródłach, **nie w podpisanej paczce 231**.
Na tym etapie audytu F01–F08 i cztery braki funkcjonalne pozostawały
otwarte. Późniejsze naprawy F02–F08 opisuje dokument wskazany na początku;
F01 i odrębne funkcje nie zostały przy tej okazji wdrożone.

## Przejście przez moduły — rzeczy sprawdzone i granice

| Obszar oryginału | Sprawdzony zakres / wniosek |
|---|---|
| `ap_ball` | Lot, kolejność kontaktu, przyspieszenie, tłumienie, odbicie, obrona ręczna/auto, zasięgi, bot-serwis; nowy limit boczny i F02/F08. |
| `ap_gamelogic` | Kolejność sieć–piłka–serwis–wejście–bot–auto–audio; sześć parametrów bota i faza pierwszego returnu; F07. |
| `ap_game_start` | Ruchy, tolerancje odbicia, start, rotacja, pauza, kolejka lektora i opcjonalna publiczność. Ręczna pauza nieprzeniesiona. |
| `ap_match` | 7/11/21, dwupunktowa przewaga, serwis co dwa punkty również przy remisie; odpowiedniki obecne. |
| `ap_arcade_rules` | Dwa niezależne losowania 7% po odbiciu, nie samym serwisie. Autorytet losowania po stronie gospodarza; obecny. |
| `ap_arcade_shield` | 10 sekund, odnowienie, zachowanie między punktami, proste odbicie bez zużycia; F05/F06 audio. |
| `ap_arcade_invisible` | Koniec niewidzialności po paletce/golu, nie po tarczy; kod nie dodaje osobnego odgłosu powrotu piłki. |
| `ap_input` i wejście z `ap_visual_mouse` | Próg dx/dy, opóźnienie i rytm powtórzeń, 90 ms, LMB, modale; tryb graficzny oddzielony; F01. |
| `ap_sounds` | Własne/oponenta paletki, wysokość tonu, pięć pasm bandy, aktualizacja parametrów podczas grania, głosy, tarcze i brakujące nagrania publiczności; F03–F06. |
| `ap_audio` | Panorama i tłumienie, kanały, nasycenie, zmiana tonu; nie zakładamy identycznego brzmienia różnych backendów. |
| `ap_audio_device`, `ap_audio_stream`, `ap_audio_stream_device`, `ap_pygame_shim` | Rola backendu, wyboru urządzenia i streamingu; nie przenoszone do ELTEN-a. Nie są dodatkowymi zasadami gry. Szczegółowej zgodności urządzeń nie potwierdza ten audyt. |
| `ap_menus`, `ap_settings`, `ap_config` | Sprawdzone istotne fragmenty i bajtkod menu pauzy oraz osobistych ustawień. Nie oparto wniosków na uszkodzonej dekompilacji całości. |
| `ap_spectator` | Wybór perspektywy, odbiór obrazu i rola widza; brak lokalnego wyboru strony u nas. |
| `ap_netgame`, `ap_netstrings`, `ap_network` | Gałęzie ruchu/odbicia/punktu/Arcade, precyzja tysięcznych, kierunki i autorytet. Usługi, konta i transport oryginału pominięte zgodnie z zakresem. |
| `ap_perf`, harmonogram pętli | Oryginalny krok 16 ms, ograniczenie nadrabiania modalnego; nie zmieniano zatwierdzonej poprawki rytmu ELTEN-a. |
| `ap_ui`, `ap_lang`, `ap_chat` | Treści i interfejs mowy/historii zastępuje ELTEN. Nie kopiujemy całego interfejsu. Komunikaty pola gry i PL/EN sprawdzono celowanymi testami. |
| `ap_visual`, `ap_visual_menu`, `ap_vision` | Obraz i jego menu poza zakresem; wyjątkiem sprawdzenie, by nie pomylić trybów sterowania. |
| `ap_lobby*`, `ap_title`, `ap_update`, `ap_feedback`, `ap_telemetry`, `ap_platform` | Lobby/konta, ekran tytułowy, aktualizator, zgłoszenia, telemetria i platforma — wyłączone z portowania. Nie oznaczamy ich jako braków rozgrywki. |
| `axel_pong` — inicjalizacja | Sprawdzone istotne stałe i ustawienia domyślne w bajtkodzie; nie wykonywano programu głównego. |

Nie znaleziono kolejnego odmiennego zestawu parametrów strategii bota:
sześć tabel reakcji, kroku, błędu, offsetu, zasięgu, ruchów przed serwisem
i ograniczenia pierwszego odbicia odpowiada sprawdzonym funkcjom wzorca.
Nie oznacza to identycznych losowych meczów ani dowodu braku dalszych błędów.

## Rzeczy, których celowo nie uznano za nowy błąd

- Dźwięki punktu dopiero po trwałym potwierdzeniu LiveSessions, deduplikacja
  i odtwarzanie po odświeżeniu widoku: świadome granice integracji.
- Losowanie pierwszego serwującego wspólnym identyfikatorem zamiast
  niezależnymi zegarami komputerów; w grze z botem zaczyna człowiek.
- Komunikat serwisu po ok. 5 s i gotowość po 5,7 s: osobne terminy już są
  w kodzie; nie dopisano nieistniejącego błędu „700 ms spóźnionej zapowiedzi”.
- Ściszony lektor 25%: świadoma wcześniejsza decyzja, nie przeoczenie audytu.
- Publiczność bez dźwięków: brak nagrań w obu dostępnych dystrybucjach
  i u użytkownika. Sam kod funkcji nie dostarcza nagrań.
- Echolokacja: udostępnienie niepodłączonego we wzorcu kodu było osobno
  zatwierdzone. Nie nazywamy jej skopiowaną opcją oryginalnego menu.
- Składnia skrótów, własny czat, tworzenie stołu, konto i połączenia są
  eltenowe. Nie trzeba kopiować oryginalnego lobby dla wierności gry.

## Weryfikacja i ograniczenia

21/21 celowanych skryptów Ponga/Communications przeszło, w tym test
binarnych źródeł z rzeczywistym słownikiem ELTEN-a (PL/EN/fallback).
Nowe próby obejmują ruch/click/hold, kolejność wejścia, próby poza brzeg,
powrót po utracie fokusu, oba klienty, obserwującego właściciela, bota
lokalnego/zdalnego i blokadę serwisu po pauzie. Nie uruchamiano pełnego
runnera, starej paczki jako nowego kodu ani odzyskanego Pythona.

`diagnostics/pong-deep-parity-231/probe.rb` poza repo odtwarza F02–F06.
To raport **znanych rozbieżności**, nie test potwierdzający oczekiwaną
zgodność. Wyniki celowanych skryptów nie zamykają tych pozycji; stare
testy czasem sprawdzały naszą założoną wartość, nie wzorzec.

Nie wykonywano nowego żywego meczu, fizycznego sterowania myszą ani
odsłuchu na urządzeniu. Nie ma podstaw do deklaracji „100% zgodności”.
Nie budowano, nie podpisywano, nie instalowano ani nie publikowano paczki;
nie zmieniano serwera/profili i nie wysyłano na GitHub. Changelog bez zmian.
