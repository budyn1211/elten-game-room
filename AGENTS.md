# Instrukcje dla agentów pracujących nad ELTEN Game Room

## Pong: audyt po podpisaniu 236 — 22 września 2026

Na osobne polecenie przejrzano Communications/Ponga i lokalną obsługę
zapisu przez LiveSessions. Dwa NOWE odtworzone problemy, bez wdrażania:
(1) przy jednostronnej ciszy w deblu podczas 10 s cooldownu reconnectu
gospodarz jest paused, ale rozsyła ready=true; pozostali aktywni gracze
nie wstrzymują się; po powrocie brakującego gracza zgodnie wznawiają;
(2) obserwator dołączający w środku wymiany ma snapshot turn=2 i silnik
turn=0, więc odkłada kolejne odbicia bez szansy na brakujących poprzedników.
Po dalszych 128 odbiciach sonda wykazała PeerActionBufferFull/reconnect
obserwatora, bez żądań reconnectu graczy. Snapshoty nadal docierają.

Ponownie odtworzono WCZEŚNIEJ ZNANE pominięcie krótkiego naciśnięcia tuż
przy bramce (puszczone -> gol, przytrzymane -> odbicie). To Engine,
nie dowód błędu relay ani nowa regresja 236; ewentualna zmiana wymaga
osobnej decyzji ze względu na wierność oryginałowi. OwnerChanged,
historyczne PeerStatusTimeout i dźwięki band nadal osobnymi tropami.

10/10 celowanych skryptów poprawnych, osobna sonda trzech znalezisk.
Wyłącznie OFFLINE, bez nowego pomiaru Internetu i audytu zdalnego serwera.
Kontrole zapisu, duplikatów/nieuprawnionych wyników oraz rewanżu poprawne.
Nie naprawiano tych znalezisk, nie zmieniono produkcji/paczki po podpisie,
nie instalowano, nie ruszano klientów/profili/serwera/GitHuba.
Raport i wyniki: diagnostics/pong-communications-audit-236/{README.md,RESULT.json}
oraz probe.rb (ścieżki od katalogu nadrzędnego repo).
Aktualna podpisana 236 pozostaje bd291662… z usuniętą tylko początkową pauzą.

## Pong: usunięte tylko początkowe 3 s, ponownie podpisana 236 — 22 września 2026

Na polecenie usunięto dodatkowe 3 s po gotowości graczy przed pierwszym
serwem meczu bez botów. Nadal wymagane połączenie/gotowość, zachowane
zapowiedzi i odstęp 120 ms, nagrania i wszystkie terminy po bramce,
w tym 2,7 s przed serwem. Jedyna zmiana logiki: prepare_first_serve
w client.rb. Bez zmian fizyki, transportu lub autoryzacji. Dodano trzeci
punkt changelogu PL/EN do tego samego 2.0.2.5/build 236; poprawiono jeden
akapit zasad opisujący dawne odliczanie.

12/12 celowanych skryptów, sześć kontroli składni i diff check poprawne.
Nowa regresja najpierw odrzuciła stary licznik; dwa stare testy wymagały
usuwanego odliczania i dostały nowe oczekiwania. To próby OFFLINE;
bez żywej partii/odsłuchu i pełnego runnera. Podpis papierek, komplet
335 plików, zgodność ze źródłami/manifestami oraz binarne wczytanie
PL/EN/fallback i nowe terminy pierwszego serwu sprawdzone.

Paczka artifacts/game-room/testing/ELTEN-Game-Room-build-236-signed.eltsetup:
23 199 808 B; SHA-256:
bd291662f4bde72adb3e3c421488b55e0e60985afa9b791b1dd2a8ed366cf9a2
Poprzednią 678fd5f4… zachowano jako build-236-before-startup-delay-removal.
Raporty: diagnostics/release-236-startup/{SOURCE,PACKAGE}.json
(ścieżki od katalogu nadrzędnego repo). Bez instalacji, restartów, GitHuba
i zmian serwera/profili. Po ukończeniu użytkownik zlecił osobny audyt
Communications/Ponga; nie jest to zgoda na nowe poprawki w tej paczce.

## Pong: podpisana 2.0.2.5/build 236 — 22 września 2026

Na „zbuduj”, następnie zmianę numeru i wersji, przygotowano podpisaną
2.0.2.5/build 236/API 3.0.3. Zawiera ujednolicenie ludzi/botów opisane
poniżej oraz wcześniejszą poprawkę pauzy z 235. Nowy changelog PL/EN
ma dwa krótkie punkty: wspólna komunikacja w meczach z botami oraz
dźwięk bramki bez oczekiwania na trwały zapis wyniku. Wszyscy uczestnicy
meczów z botami powinni mieć zgodną aktualizację.

Osobna wstępna poprawka goal_confirmed dla botów jest USUNIĘTA.
Pozostał wspólny mechanizm point/preview, taki jak między ludźmi:
dźwięk dopiero po uzgodnieniu punktu, niezależnie od zakończenia zapisu
LiveSessions; wynik zatwierdza trwały replay. To nie dodatkowa pauza.

Paczka: ../artifacts/game-room/testing/ELTEN-Game-Room-build-236-signed.eltsetup
23 199 674 B; SHA-256:
678fd5f41f45e88ca97bb38e7692c1d7b0abb8c3dcc10d3a3be6fd5fb73621d3
Podpis papierek i komplet 335 plików wykonawczych/licencji potwierdzone:
324 rekordy (193 Ruby, 130 audio, 1 MO), 11 plików luzem, 13 wpisów
instalatora, zgodność bajtów ze źródłami. Manifesty i runtime zgodne.
Binarne wczytanie gotowej paczki: PL/EN/fallback, debel i wspólna
obsługa człowiek–bot z gospodarzem-obserwatorem, aktualny changelog,
formularze/kodowanie. Celowany test changelogu, 4 kontrole składni,
idempotencja kompilacji katalogu i diff check poprawne; wcześniejszych
39 testów wdrożenia nie powtarzano. Nie było pełnego runnera ani nowej
żywej partii/odsłuchu. Poprzednia podpisana paczka 235 zachowana.

Raporty: ../diagnostics/release-236/{SOURCE,PACKAGE}.json.
Bez instalacji, restartów, zmian serwera/profili, GitHuba lub publikacji.
OwnerChanged/PeerStatusTimeout nadal osobnymi niewyjaśnionymi tropami.
Poniższe „tylko źródła/bez paczki” opisuje etap sprzed tego wydania.


## Pong: ujednolicone akcje ludzi i botów, tylko źródła — 22 września 2026

Na „Wprowadź to ujednolicenie zatem” wszystkie mecze Ponga korzystają
z PeerPlay/PeerEngine. Człowiek rozstrzyga swoje serwy, odbicia i chybienia;
gospodarz prowadzi wyłącznie własne miejsce oraz boty. Obecność bota nie
przełącza już ludzi na symulację u gospodarza. Ważne akcje rozsyła ich
uprawniony autor bezpośrednio przez relay Communications; bot działa pod
tożsamością gospodarza, bez osobnego konta. Zachowane sprawdzanie miejsca,
kolejności, nadawcy, meczu i generacji. Pozycje nadal mają odrębny kanał
stanu; nie twierdzić, że każdy pakiet omija gospodarza.

Gospodarz nadal uzgadnia punkt z ludźmi i zapisuje go przez LiveSessions.
Wspólny podgląd dźwięku bramki nie czeka na trwały zapis; wynik punktowy
nie jest zatwierdzany wcześniej. Usunięto starą osobną ścieżkę centralnych
ruchów i wstępny osobny goal_confirmed. Lokalny właściciel kontra boty
nie czeka na Communications, a pierwsze połączenie nie resetuje lotu.
Nowe protokoły mixed-peer-1 rozdzielają tę zmianę od starych klientów
z botami: przed żywą próbą wszyscy muszą mieć zgodne nowe źródła/paczkę.

Produkcja w tej zmianie: client.rb, peer_play.rb, peer_engine.rb. Bez zmian
Engine/Bot, fizyki, tolerancji obrony, nagrań/głośności, źródeł ELTEN-a,
Channel/EventChannel lub LiveSessions. Zachowano pauzę 2,7 s bez bariery
syntezy z 235. Test parytetu wykrył i pozwolił poprawić kolejność efektów
Arcade względem śledzenia piłki przez bota. Dźwięki kroków zdalnego bota
pochodzą z jego rzeczywistych zdarzeń, nie z drobnych bezgłośnych zmian
pozycji. Przy kolejnych grach nie centralizować akcji ludzi tylko dlatego,
że obecny jest bot; walidować uprawnienia delegowanej postaci i jej turę.

39/39 celowanych skryptów, 15 kontroli składni i diff check poprawne.
Offline: sześć obsad po 16 wymian z wszystkimi parami serwisowymi, dziewięć
konfiguracji relay po osiem wymian, opóźnienia/utrata pozycji, właściciel
grający/obserwator, ponowny mecz/reconnect, zgoda na bramkę i opóźniony
trwały zapis. Dokładny parytet lokalnych botów Classic/Arcade na sześciu
poziomach; osobno człowiek dostał odbicie przed sztucznie opóźnionym
gospodarzem. Nie są to żywe pomiary Internetu ani próba odsłuchowa.
OwnerChanged/PeerStatusTimeout pozostają osobnymi niewyjaśnionymi tropami.
Bez pełnego runnera, nowych żywych klientów, instalacji, restartów, kont,
serwera/profili lub GitHuba. Wersja/changelog i podpisana 235 bez zmian;
paczka 235 NIE zawiera obecnego ujednolicenia. Dokumentacja:
docs/PONG_UNIFIED_PEERS.md; raport poza repo:
../diagnostics/pong-unified-peers/RESULT.json.


## Pong: usunięte czekanie na syntezę; podpisana 235 — 22 września 2026

Na „to popraw to i podpisz nową paczkę” usunięto z debla barierę końcowego
znacznika syntezy. Zapowiedź serwującego/odbierającego jest zwykłym tekstem,
nie przedłuża terminu: po wyniku obowiązuje 2,7 s jak w singlu. Pierwsze
przygotowanie połączenia, dźwięki bramki/wyniku i synchronizacja stanu
pozostają. Drugi serw tej samej pary bez powtórki zapowiedzi. Zmienione
produkcyjne zachowanie tylko client.rb i peer_play.rb; bez zmian fizyki,
tolerancji obrony, transportu Communications, LiveSessions lub NVDA.

Test z brakującym potwierdzeniem najpierw odtworzył blokadę starego kodu,
potem przeszedł bez podawania indeksu. 13/13 celowanych skryptów źródeł,
7 składni, idempotencja katalogu i diff check poprawne. Próby OFFLINE:
czterech klientów, właściciel-obserwator, boty, oba serwy, wcześniejszy
preview, spóźniony gracz, reconnect i niezapamiętywanie naciśnięć z pauzy.
Bez nowej żywej partii lub odsłuchu. OwnerChanged/PeerStatusTimeout
pozostają osobnymi niewyjaśnionymi zdarzeniami, nie obiecywać ich naprawy.

Podpisana 2.0.2.4/build 235/API 3.0.3, changelog PL/EN jeden nowy wpis
o deblu. Plik artifacts/game-room/testing/ELTEN-Game-Room-build-235-signed.eltsetup
(w repo ścieżka od katalogu nadrzędnego). 23 200 540 B; SHA-256:
7d008093b7e51ad084c54793e35fcca922696733e109aa4c373d0a4dcdf53878
Potwierdzono podpis papierek, komplet 335 plików wykonawczych/licencji,
324 rekordy (193 Ruby, 130 audio, 1 MO), 11 luzem, 13 wpisów instalatora.
Binarne testy gotowej paczki: debel PL/EN/fallback i formularze/kodowanie.
Raporty diagnostics/release-235/{SOURCE,PACKAGE}.json poza repo; dokumentacja
repo docs/PONG_SERVE_PAUSE_235.md. Poprzednia paczka 234 zachowana.
Wszyscy gracze powinni zaktualizować: stary klient może nadal wstrzymywać
mecz oczekiwaniem na syntezę. Bez instalacji, restartów, GitHuba, publikacji,
zmian serwera lub profili. Repo zawiera niezatwierdzone zmiany tej poprawki.


## Ctrl+F4 i podpisana 2.0.2.3/build 234 — 22 września 2026

Na polecenie użytkownika poprawiono Ctrl+F4 i dodano rozdzielony odczyt
HTTP oraz dostępnego Communications UDP RTT do serwera pośredniczącego.
Odtworzono pozostawanie starego mostu QuickActions po aktualizacji bez
restartu: jego utrwalona lista klawiszy nie zawierała Ctrl+F4. Jednorazowa
migracja do dynamicznej obsługi kontrolki rozwiązuje tę regresję. Nie
potwierdzano stanu zgłoszonego żywego klienta; to odtworzona przyczyna,
nie dowód na wyjaśnienie wszystkich możliwych przypadków.

HTTP pozostaje jednym żądaniem w tle. Communications czyta ostatni natywny
pomiar UDP przez wspólny Channel, wyłącznie przy aktywnej sesji i świeżym
fast_path. Brak pomiaru UDP, np. przy TCP fallback, to niedostępny wynik,
nie zero ani pomiar TCP. Nie jest to pełne opóźnienie między graczami.
Bez nowych sond, zmian fizyki, tolerancji obrony, audio lub źródeł ELTEN-a.
Opis: docs/PING_HOTKEY_234.md.

Paczka obejmuje także wcześniejsze poprawki relay, immediate dispatch,
odbioru, zaproszeń i statusu bramki, sprawdzone uprzednio na czterech
żywych kopiach. Nie przeprowadzano nowej żywej partii podczas wydania.
12/12 celowanych skryptów źródeł, 12 kontroli składni, idempotencja
tłumaczeń i diff check poprawne. Podpis papierek oraz komplet zawartości
porównany ze źródłami; binarny test realnego słownika PL/EN/fallback
z gotowej paczki przeszedł. 335 plików wykonawczych/licencji, 324 rekordy
(193 Ruby, 130 audio, 1 MO), 11 plików luzem i 13 wpisów instalatora.

Paczka: ../artifacts/game-room/testing/ELTEN-Game-Room-build-234-signed.eltsetup
23 200 746 B; SHA-256:
b2c67df46f8975fa5efca212cba7bc405dff67e0e62b18ff5bce6423c0afc2e7
Wersja 2.0.2.3/build 234/API 3.0.3; trzy nowe punkty changelogu PL/EN.
Raporty: ../diagnostics/release-234/{SOURCE,PACKAGE}.json. Poprzednie paczki 233 zachowane.
Bez pełnego runnera, instalacji, restartów, GitHuba, publikacji, zmian
serwera lub profili. Wszyscy gracze powinni używać zgodnej nowej paczki.


## Cztery żywe kopie: debel sprawdzony — 22 września 2026

Na polecenie użytkownika odnowiono połączenia MCP i zainstalowano obecną
podpisaną 2.0.2.2/build 233 immediate-dispatch w test-3 (papiertestowy1)
oraz test-4 (papiertestowy2). Main papierek i test papiertestowy już miały
tę bazę. Auto-return wyłączono trwale w pierwszych dwóch, w nowych było
wyłączone; inne preferencje zachowano. Bez restartów.

Te same trzy najnowsze pliki kandydata (Channel, EventChannel, PeerPlay)
wczytano tymczasowo we wszystkich czterech procesach. 18/18 celowanych
skryptów przeszło. Jeden prywatny stół 1208945905, trzy próby: Classic 7,
ten sam pokój po zmianie na 21 i inny układ drużyn, następnie Arcade.
40 punktów, wyniki 7:5 / 12:6 / 5:5 zgodne u wszystkich. 42 serwy,
185 odbić, 6 odbić tarczą; wszystkie osiem par serwisowych sprawdzone.
410 niezawodnych wiadomości -> 1230 natywnych dostaw, żadnej zgubionej.
Siedem starych wiadomości celowo zatrzymanej kolejki prawidłowo odrzucono
przy nowej generacji; w tym trzy odbicia. Pozostałe przyjęte po jednym razie.

Czwarty klient wszedł celowo po 26 s; retry i start samoczynne. Jedno
odbicie opóźnione w workerze o 300 ms przyjęły trzy kopie po 326–373 ms.
Kontrolowana 6-sekundowa blokada lokalnego odbioru dała automatyczne
odzyskanie i zgodny wynik, bez Entera/wychodzenia z okna. 15/16 zaproszeń
rozpatrzono dwukrotnie; wszystkie przyjęto po jednym razie, bez błędu.
Normalna pełna droga akcji: mediana 47 ms, p95 71 ms, max 84 ms;
natywny odbiór mediana 13 ms. LiveSessions PO preview 281–736 ms,
nie ping. Cztery kopie JEDNEGO komputera, nie cztery niezależne łącza.
Nie odtworzono historycznego rzadkiego błędu ani nie wyjaśniono 485 ms.

Stół zamknięty, wszystkie kopie Scene_Main, zasoby 0 i cache sesji puste;
klienci/kanały zamknięte, fabryka/rozszerzenie/kandydat usunięte.
Wyłączenie auto-return pozostaje. Zainstalowana paczka nadal NIE zawiera
trzech nowszych poprawek testowanych tylko w pamięci. Bez zmian kodu
produkcji, fizyki, audio, wersji/changelogu, schematów, nowego buildu,
podpisu i GitHuba. Raport: ../diagnostics/pong-live-four-clients-233/README.md.
W raporcie także ograniczenia i poprawione błędy pomocników testowych.

## Communications: poprawki odbioru i zaproszeń wdrożone — 22 września 2026

Na „to poprawiaj i testuj dalej” poprawiono powtórne przyjęcie zaproszenia
(callback/kolejka podczas accept), dodano bounded native receive(timeout: 0)
we wspólnym Channel i wspólną walidację/deduplikację EventChannel. Odczyt
dotyczy już odebranych wiadomości w pamięci, bez RPC/wait/pompowania UI.
PeerPlay wysyła nowy status bramki bez czekania do 40 ms na okresowy pakiet;
zgoda wszystkich graczy i trwały zapis LiveSessions pozostają. Tylko trzy
pliki produkcyjne: channel.rb, event_channel.rb, peer_play.rb. Bez zmian
fizyki, zasad, tolerancji obrony, audio lub globalnej pętli ELTEN-a.
Opis: docs/PONG_RECEIVE_INVITATION_233.md.

30/30 celowanych skryptów, 8 kontroli składni i diff check poprawne;
rzeczywisty native Session/EventQueue: 18 000 wiadomości bez wzrostu
kolejki. 32 symulowane wymiany, także czterech klientów/debel. Zachowano
czerwone reprodukcje oraz wcześniejsze błędne założenie testu o zachowaniu
prefiksu kolejki po reconnect — istniejący kod poprawnie czyści CAŁĄ kolejkę.

Dwie żywe kopie z odrębnymi tymczasowymi klasami kandydata: 11 punktów,
13 serwów i 87 odbić, wszystkie 100 przyjął drugi silnik, wszystkie wyniki
zgodne. Ten sam prywatny stół, zmiana 7 -> 21 i ponowny start bez błędu.
To samo zaproszenie faktycznie dostarczone dwa razy, przyjęte tylko raz.
Mediana pełnej drogi akcji 51–53 ms; 120/124 odebrano przed callbackiem.
Nie sterowano/rejestrowano fokusu; NIE kontrolowane A/B lub czterech ludzi.
Jedno kontrolowane opóźnienie 300 ms: przyjęcie po 366 ms bez odzyskiwania.
Dwa reconnect gościa nastąpiły dopiero PO kontrolowanym wyjściu hosta.
LiveSessions potwierdzenie PO preview nadal 281–963 ms; nie jest pingiem.
Wcześniejsza przerwa 485 ms i rzadki błąd czterech ludzi nadal niewyjaśnione.

Raporty: ../diagnostics/pong-receive-invitation-233/{README.md,SOURCE.json,RESULT.json}.
Stół 754140108 zamknięty, obie kopie Scene_Main, zasoby 0; tymczasowe
klasy/fabryka/rozszerzenie usunięte. Bez instalacji, restartów, profili,
schematów, GitHuba, buildu i podpisu. Wersja 2.0.2.2/build 233/API 3.0.3
i changelog bez zmian. Dotychczasowa paczka NIE zawiera tych poprawek.


## Communications: automatyczna żywa próba i sprzątanie — 22 września 2026

Na „gotowe”, po zgodzie na sterowanie obiema kopiami, wykonano trzy próby
na jednym prywatnym stole papierek/papiertestowy: Single Classic, 26 punktów,
29 serwów i 188 odbić. Wszystkie 217 wysłanych serwów/odbić przyjął drugi
silnik; wszystkie wyniki zgodne. Wejście przez normalny Client/GameScreen,
bez przypisywania piłki lub wyników. Jedna akcja opóźniona w tle o 300 ms
została przyjęta po 394 ms, bez odzyskiwania. To NIE czterech ludzi/debel.
Raport: ../diagnostics/pong-live-automated-233/{README.md,RESULT.json}.

Potwierdzono ponowne przyjęcie TEGO SAMEGO zaproszenia Communications:
pierwsze poprawne, drugie status accepted -> SessionClosed. Przyczyną jest
podwójne dostarczenie callback/kolejka podczas operacji accept. Wyjaśnia
wpis po session_ready, nie dowodzi przyczyny wcześniejszego utykania.
Natywny odbiór trzeciej próby 7–30 ms; callback -> gra mediana 12,6 ms
na pierwszym planie i 53 ms w tle. Cała akcja odpowiednio mediana 34/100 ms.
Pętla ELTEN-a usypia po callbackach 10/50 ms. Osobno goal_preview oraz
trwały wynik LiveSessions: 113–511 ms host, 261–633 ms gość PO preview;
nie jest to ping ani odsłuch początku bramki. Pojedyncza przerwa klatki
668 ms nie ma izolowanej przyczyny (MCP działa na UI); stare 485 ms nadal
nieuznane za naprawione. Ponowienia meczu 2 przed wejściem gościa i po
kontrolowanym wyjściu hosta są artefaktami organizacji próby, nie usterką.

Stół testowy zamknięty; obie kopie Scene_Main, kanały zamknięte, zasoby 0,
sondy, rozszerzenie i nadpisanie fabryki usunięte. Bez zmian produkcyjnego
kodu, fizyki, audio, profili, instalacji/restartów, schematów, buildu,
changelogu i GitHuba. Wersja 2.0.2.2/build 233/API 3.0.3 bez zmian.
Nie wdrażać propozycji napraw tylko na podstawie tej zgody na diagnostykę.

## Communications: wyniki ponownej żywej próby — 22 września 2026

Odczyt obu kopii po instalacji przez użytkownika: pięć punktów 0–4,
generation 0 bez odnotowanego odzyskiwania. Raport poza repo:
../diagnostics/pong-live-immediate-dispatch-233/RESULT.json.
Kolejka 0–1 ms w 26/27 aktywnych okien pomiaru, raz 6 ms; wcześniej
5–33 ms. Relay UDP RTT 6–17 ms, raz 47 ms. Lokalna obsługa odbioru
12–59 ms. Brak powtórki 485 ms NIE potwierdza naprawy tego zacięcia.
Trwały zapis punktu host 100–304 ms, gość 341–548 ms; NIE ping ani
pomiar opóźnienia bramki w audio. Zostały osobne wpisy PeerUnavailable
z udanym ponowieniem po sekundzie oraz SessionClosed po session_ready.
Bez korelacji z fokusem; dwie kopie jednego komputera, nie pełny debel.
Tylko odczyt MCP i zapis raportu; bez testów, kodu, instalacji, buildu,
restartów, zmian serwera/profili lub GitHuba. Nie zmieniać fizyki na
podstawie tych pomiarów; kolejny etap wymaga rozdzielenia lokalnej
obsługi zdarzeń, uzgodnienia punktu i potwierdzania trwałego zapisu.

## Communications: podpisana diagnostyczna 233, bez nowych kontroli — 22 września 2026

Na wyraźne polecenie zbudowano i podpisano aktualne źródła bez kolejnych
testów i kontroli. Builder zakończył się powodzeniem; nie wykonywano
niezależnej weryfikacji podpisu, sumy kontrolnej ani testów binarnych.
Paczka: ../artifacts/game-room/testing/
ELTEN-Game-Room-build-233-pong-immediate-dispatch-signed.eltsetup.
Wersja 2.0.2.2/build 233/API 3.0.3 i changelog pozostają. Zawiera poprawkę
docs/PONG_IMMEDIATE_DISPATCH_233.md; fizyka, audio i LiveSessions bez zmian.
Poprzednia pong-diagnostics 4754e6a1… zachowana. Raport wydania:
../diagnostics/pong-immediate-dispatch-233/BUILD.json. Wcześniejsze testy
źródeł 23/23 nie były ponawiane. Użytkownik sam instaluje w obu kopiach
i gra dla kolejnych pomiarów. Bez instalacji, restartów, meczu, GitHuba,
publikacji i zmian serwera/profili; nie ogłaszać naprawy przerwy 485 ms.

## Communications: wysyłka bez następnej klatki — 22 września 2026

Po próbie obu kopii użytkownik polecił poprawić wyłącznie Communications
w Game Roomie. Opis docs/PONG_IMMEDIATE_DISPATCH_233.md. EventChannel
rozpoczyna wolne zadanie już w send_event, ale RPC nadal idzie w tle.
Rozliczaj poprzedni wynik przed kolejnym zadaniem: nie gub Delivery ani
FIFO. Nie rozpoczynaj zaplanowanego starego RPC po zamknięciu, zmianie
sesji/generacji lub rozpoczęciu odzyskiwania; trwających zapisów nie zabijaj.
Nie omijaj obowiązkowych odbiorców ani nie zwiększaj liczby pracowników.

23/23 celowanych skryptów i pięć składni poprawne. Pierwszy wynik 22/23
dotyczył momentu kontrolowanej utraty członka już po nowej szybkiej wysyłce;
poprawiono granicę scenariusza, zachowując asercje pełnej dostawy/rejoin.
Raport ../diagnostics/pong-immediate-dispatch-233/SOURCE.json. Symulacja
śledzonej akcji 56→48 ms, kolejka 8→0; nie wynik żywej sieci. Przerwa
odbiorcy 485 ms z próby ../diagnostics/pong-live-two-clients-233/ pozostaje
osobna i nie jest uznana za naprawioną. W tym kroku bez zmian odbioru,
ELTEN-a, fizyki, audio, zasad lub LiveSessions; bez pełnego runnera,
nowej paczki, instalacji, restartów, GitHuba, kont/serwera/profili.
2.0.2.2/build 233/API 3.0.3 i changelog zachowane. Podpisana diagnostyczna
233 o hashu 4754e6a1… NIE zawiera tej najnowszej poprawki.

## Pong: diagnostyczna 233 podpisana, przed żywym testem — 22 września 2026

Gotowy instalator: ../artifacts/game-room/testing/ELTEN-Game-Room-build-233-pong-diagnostics-signed.eltsetup.
Wersja 2.0.2.2/build 233/API 3.0.3; 23 198 374 B, SHA-256
4754e6a1987b28f1879d99b977ef8bef546b69b46e7a679a7e857012728705dd.
Zmiany relay i pomiary są już w tej paczce; wcześniejsza 5e37899b…
zachowana pod starą nazwą oraz jako before-relay-diagnostics. Nie mieszać
klientów starego dialektu z nowym. Użytkownik sam wczytuje do obu kopii.
8/8 celowanych skryptów, 6 składni, preflight 335 plików i diff check
przeszły PRZED podpisaniem. Builder podpisujący zakończył się poprawnie;
po podpisaniu wyłącznie rozmiar/hash, bez niezależnej kontroli binarnej
lub sygnatury. Raporty ../diagnostics/pong-relay-release-233/{SOURCE,BUILD}.json.
Changelog, nagrania i fizyka niezmienione. Bez instalacji, restartów,
publikacji, GitHuba, żywego meczu, pełnego runnera i zmian serwera/profili.
Pomiar idle 12,69 ms nie dowodzi opóźnienia dostawy w meczu ani naprawy debla.

## Pong: paczka diagnostyczna zatwierdzona — 22 września 2026

Użytkownik polecił dać paczkę; sam wczyta ją do dwóch uruchomionych kopii.
Podpisać istniejące poprawki docs/PONG_RELAY_DELIVERY_233.md jako 2.0.2.2,
build 233/API 3.0.3. Nazwa pliku ma odróżniać wariant pong-diagnostics,
a poprzednia podpisana 5e37899b… pozostaje zachowana. Bez zmiany wersji,
changelogu, fizyki i nagrań; celowane kontrole przed podpisem, bez pełnego
runnera i powtarzania kontroli po podpisie. Bez instalacji, restartów,
żywego meczu, zmian kont/serwera, GitHuba lub publikacji. To zgoda,
nie potwierdzenie ukończenia. Obie kopie wymagają zgodnego nowego dialektu.
Idle relay RTT zmierzony oddzielnie: średnio 12,69 ms; nie uznawać tego
za pomiar dostawy do przeciwnika ani test poprawności czteroosobowego debla.

## Pong: dostarczanie akcji relay, bez paczki — 22 września 2026

Lokalnie wdrożono docs/PONG_RELAY_DELIVERY_233.md: bezpośrednie rozsyłanie
akcji ludzkiego Ponga przez relay, stała lista wymaganych kont niezależna
od chwilowych członków sesji, pełne sprawdzanie Delivery, kolejność między
nadawcami i ograniczone odzyskiwanie utrwalonej rozbieżności. Tryb kanału
jest opt-in; boty zachowują model gospodarza. Nowe dialekty pong-peer-2
i pong-doubles-peer-2 zapobiegają mieszaniu ze starym sposobem rozsyłania.
W przyszłych grach peer-routing wymaga autoryzacji faktycznego nadawcy
w regułach; obecność w kanale nie uprawnia do sterowania cudzym miejscem.
Nie wyliczać wymaganych odbiorców z przypadkowo niepełnej listy online.

38/38 celowanych skryptów, 17 kontroli składni i diff check poprawne;
raport ../diagnostics/pong-relay-delivery-233/SOURCE.json. Pierwsze 37/38
wynikało ze starego źródła hosta w teście zapowiedzi: powtórzono go z
ELTEN_HOST_SOURCE=../work/elten-3.0.1-app-dev bez zmiany testu i asercji.
W symulacji inni goście odbierają akcję po 48 zamiast 104 ms. Nie jest to
pomiar rzeczywistej sieci. Nie było żywej partii ani odsłuchu; MCP wygasłe.
Diagnostyka co 10 s osobno podaje cached relay UDP RTT, kolejkę, RPC i czas
obsługi. Ctrl+F4 mierzy HTTP, a durable_confirmation_ms zatwierdzenie przez
LiveSessions; NIE utożsamiać tych wartości z pingiem relay lub utratą UDP.

Brak nowej paczki, podpisu, pełnego runnera, instalacji, GitHuba, zmian
serwera/profili/restartów. Nagrania, fizyka, wersja i changelog bez zmian.
Podpisana 233 5e37899b… nadal opisuje poprzedni stan i nie zawiera tego kodu.
Kolejny żywy test wymaga nowych zgodnych klientów; nadal nie potwierdzono
wszystkich przyczyn zgłoszonego braku obrony. Zachowano wcześniejsze edycje.

## Oryginalne teksty Cat i paczka 233 gotowe — 21 września 2026

Zakończono poniższy zakres. Pięć celowanych skryptów źródeł, cztery kontrole
składni, idempotencja kompilatorów i diff check przeszły. Oryginalne zasady
PL/EN i dziesięć tłumaczeń autora potwierdzone, także w realnym Dictionary;
Farkle zachowuje wcześniejsze komunikaty. Poprawki bota, D i UI pozostają.
Builder podpisał ponownie 2.0.2.2/build 233/API 3.0.3, changelog bez zmian.
Paczka ma 23 196 030 B, SHA-256 5e37899b548c5d108dd1cd78be83485986ff74f493feecef0782b3e46ebb9ca8.
Raporty ../diagnostics/cat-author-texts-release-233/{SOURCE,BUILD}.json.
NIE wykonywano kontroli gotowej paczki po podpisie, zgodnie z poleceniem
użytkownika; nie twierdzić, że nowy instalator przeszedł testy binarne lub
niezależną weryfikację podpisu. Poprzednia 26a76290… zachowana. Bez pełnego
runnera, instalacji, GitHuba, publikacji, serwera/profili i zmian nagrań.

## Teksty Cat, head, tail — przywrócić autora i podpisać 233, 21 września 2026

Najnowsze polecenie zastępuje zgodę na redakcję tekstów PR #12: zachować
WSZYSTKIE teksty autora i jego tłumaczenia, w tym cały dokument zasad
PL/EN i krótkie komunikaty. Nie poprawiać przy okazji literówek, Head/Tail
ani „bankuje”. Poprawki bota, D, integracji i pięć zmian po 233 pozostają.
Oryginały 7930486 są w work/pr12-review-7930486 poza repo. Katalog autora
jest zachowany, a locale/catalog-contexts.json kompiluje go z kontekstem
cat_head_tail, żeby Roll/Bank nie nadpisywały innych gier. Nowe D i limit
mają osobny katalog dodatków. Zasady i dokument pokrycia wskazują oryginalne
sekcje. Wersja 2.0.2.2/build 233/API 3.0.3, changelog PL/EN BEZ ZMIAN.
Przebudować i podpisać, bez testów po podpisie zgodnie z poleceniem.
Poprzednia paczka 26a76290… powstała przed zatrzymaniem pracy przez użytkownika;
zachować ją jako before-author-texts-signed. Bez instalacji, publikacji,
GitHuba, serwera/profili i ponownego kodowania nagrań.

## Ponowna paczka 233 — zgoda i zakres, 21 września 2026

Użytkownik polecił zbudować i podpisać paczkę z nową grą Cat, head, tail
oraz pięcioma poprawkami z POST_233_IMPLEMENTATION.md. Najnowsza korekta:
ZACHOWAĆ wersję 2.0.2.2, build 233/API 3.0.3. Nie tworzyć buildu 234.
Changelog PL/EN zachowuje dotychczasowe cztery punkty, dopisuje sześć nowych
w tym samym wpisie. Poprzednią podpisaną 233 c5e885f7… zachować osobno.
Użytkownik wyraźnie polecił NIE powtarzać celowanych kontroli po podpisaniu;
wykorzystać wcześniejsze wyniki wdrożeń. Przed pakowaniem skontrolować
jedynie nową redakcję changelogu i skompilować tłumaczenia. Bez pełnego
runnera, instalacji, GitHuba, publikacji lub zmian kont/serwera/profili.
Nie przypisywać pięciu nagraniom PR-a niepotwierdzonej licencji; kwestia
pozostaje do potwierdzenia przed publiczną dystrybucją. Nie kodować ponownie.
Ten wpis odnotowuje zakres przygotowania, nie wynik podpisania.

## Cat, head, tail — wdrożone lokalnie, 21 września 2026

Zakończono integrację zawartości PR #12 td-programs (7930486), bez zmian
punktowania. Opis: docs/PR12_CAT_HEAD_TAIL_IMPLEMENTATION.md. Zasady PL/EN,
polski limit, zabezpieczony remis ostatniego bota oraz wspólne D gotowe.
D podaje gracza i wynik, przy ósemce także +8/-8; jest tylko odczytem.
Nie mylić bezpiecznego remisu z remisem wymagającym zapisu punktów tury.
13 celowanych skryptów, 11 kontroli składni, idempotencja kompilatorów
i diff check poprawne. Sprawdzono lokalny Dictionary, binarne źródła,
UI/pomoc, zapis/odtworzenie i lokalny import drugiego klienta. Pięć nagrań
z PR-a zdekodowano bez odsłuchu; nie zmieniano ich bajtów. Pochodzenie
i licencje nadal wymagają informacji autora przed publicznym wydaniem.
Bez pełnego runnera, żywego API/partii, paczki, podpisu, changelogu, GitHuba,
instalacji i zmian kont/serwera. Raport ../diagnostics/pr12-implementation/SOURCE.json.
Poprzednie wpisy tylko-przegląd/zgoda opisują zakończone etapy.

## Cat, head, tail — zgoda na wdrożenie, 21 września 2026

Najnowsze polecenie zatwierdza PR #12 td-programs (7930486) z poprawkami
z docs/PR12_CAT_HEAD_TAIL_REVIEW.md: zasady PL/EN, końcówka bota,
tłumaczenie limitu i odczyt ostatniego rzutu pod D. Zachować punktowanie,
autorstwo oraz wcześniejsze lokalne poprawki. Informacje o nagraniach
uzupełnić bez przypisywania niepotwierdzonej licencji; nie kodować Opusa
ponownie. Tylko źródła i testy celowane; bez pełnego runnera, nowego buildu,
podpisu, changelogu, GitHuba, instalacji i zmian żywego serwera/profili.
To zgoda na wdrożenie, nie potwierdzenie ukończenia. Poniższy zakaz
wdrażania bez nowej zgody został zastąpiony tym poleceniem.

## PR #12 Cat, head, tail — wyłącznie przegląd, 21 września 2026

Po wdrożeniu pięciu poprawek sprawdzono 7930486 z PR #12 td-programs.
Raport docs/PR12_CAT_HEAD_TAIL_REVIEW.md. Potwierdzone: mylące/niepełne
zasady, oddawanie przez bota szansy zwycięstwa przy zabezpieczonym remisie
ostatniego gracza i brak polskiego podsumowania limitu punktów. D oraz
pochodzenie nowych dźwięków do uzgodnienia. Siedem celowanych skryptów,
dodatkowe próby słownika i zapisu/odtworzenia nowej gry, bez pełnego runnera.
PR niepołączony, kod autora nietknięty; nie wdrażać uwag bez nowej zgody.
Brak nowej paczki, GitHuba, instalacji, żywego API, kont/serwera i odsłuchu.

## Pięć poprawek po 233 — ukończone źródła, 21 września 2026

Opis aktualnego wdrożenia: docs/POST_233_IMPLEMENTATION.md. Wspólny ping
Ctrl+F4 jest pomiarem HTTP do ELTEN-a na żądanie w tle, nie pingiem do gracza.
Oczekująca lista osób nie może korzystać ze składu przerwanej partii.
Wyjątek dla historii podczas pisania dotyczy tylko Ctrl+przecinek/kropka
i odpowiedników z Shiftem; nie odbierać natywnych skrótów edycji.
Makra: 30 miejsc Ctrl/Alt/Shift+1–0; ustawienia wybierają wpis, nie tworzą
stołu. Zachować dawne dziesięć przypisań i niezależność od Anuluj rodzica.
Shift+góra/dół w przydziale drużyn zamienia sąsiadów bez zawijania, kursor
podąża za osobą. Miejsca drużyn pozostają, kolejność tur nie zmienia się.
17 celowanych skryptów i 18 kontroli składni poprawne, PL/EN/fallback,
kontrolki hosta i lokalny broker, bez żywego API/partii lub nowego pakowania.
Wersja/changelog bez zmian; podpisana 233 nie zawiera tego wdrożenia.
Bez pełnego runnera, instalacji, publikacji, GitHuba lub zmian serwera.
Następny zakres to przegląd najnowszego PR-a z grą, bez jego łączenia.

## Move-double: zgoda na ponowną 233 — 21 września 2026

Użytkownik polecił przebudować i podpisać paczkę z dodatkowym -3 dB.
Zachować 2.0.2.2/build 233/API 3.0.3 i changelog dokładnie bez zmian.
Poprzednia ea4c4a35… jest zachowana jako before-move-double-gain-signed.
Wyniki nowego wydania: ../diagnostics/pong-move-double-gain-release-233/.
Tylko celowane kontrole oraz gotowa paczka; bez pełnego runnera, instalacji,
publikacji, GitHuba, zmian kont/serwera i restartów. To zgoda, nie wynik.

## Move-double: niewydane ściszenie o 3 dB — 21 września 2026

Użytkownik zatwierdził dodatkowe -3 dB wyłącznie dla `pong_move_double`.
Miks audio stosuje 10^(-3/20) dla nagrania i wszystkich jego głosów,
nie zmieniając bazowych 50%/20%, suwaków, panoramy ani wysokości.
Nie ściszać innych kroków/odbić i nie przekodowywać nagrania. Pięć
celowanych skryptów przeszło, w tym lokalny feedback i osobne głosy debla.
Bez nowej paczki, wersji lub changelogu; podpisana 233 nie ma tej zmiany.

## Bieżące poprawki i zgoda na 2.0.2.2/build 233 — 21 września 2026

Zgoda na wydanie po celowanych testach; API pozostaje 3.0.3. Opis:
docs/PONG_FEEDBACK_AND_NAMES_233.md. Nie zmieniać zasad i fizyki debla.
Pierwsza osoba w każdej drużynie ma osobne nagranie `pong_move_double`,
bez dodatkowego obniżania kroków; krzywa wysokości zależna od pozycji zostaje.
Serwisy i odbicia tej osoby są teraz o CZTERY półtony niższe. Zastępuje to
wcześniejsze ustalenie o krokach i odbiciach -3. Dźwięk `buzzer` jest tylko
dla karty brzęczyka UNO, powiedzenie UNO/Makao pozostaje na `buzzer2`.
Nazwy UNO i polski Remik zmieniają prezentację, nie ID kart/gier/zapisów.
Bez pełnego runnera, instalacji, GitHuba, publikacji lub zmian żywych kont.

## Debel PR #11 i ponowna paczka 232 — zatwierdzone, 21 września 2026

Włączono lokalnie PR #11 budyn1211 (a526401) z uzgodnionymi poprawkami;
zachowano jego commity i bieżące Opus/runtime-only packaging. Obserwator
wybiera indywidualną perspektywę cyframi 1–4. W deblu pierwsza osoba
w każdej drużynie ma kroki i odbicia o 3 półtony niższe, niezależnie od
słuchacza; druga standardowe. Osobne głosy paletek przygotowuje się przy
uruchamianiu, nie podczas klatki. Przerwa po zapowiedzi pary serwisowej
wynosi 2,7 s jak w Single. Zasady rotacji i rozgrywki PR zachowane.
Opis: docs/PONG_DOUBLES_IMPLEMENTATION_232.md. Użytkownik polecił następnie
przebudować i podpisać 2.0.2.1/build 232, API 3.0.3. W bieżącym changelogu
PL/EN dodano jeden punkt o deblu, bez nowego numeru buildu. Ten wpis nie
potwierdza ukończenia pakowania. Poprzednią 45299ff5… zachować jako
before-doubles-signed.eltsetup; wyniki ../diagnostics/pong-doubles-release-232/.
Tylko celowane testy i kontrola gotowej paczki; bez pełnego runnera,
instalacji, publikacji, GitHuba, zmian serwera/profili i restartów ELTEN-a.

## Wszystkie nagrania: Opus 144 VBR i ponowna paczka 232 — 21 września 2026

Najnowsze polecenie obejmuje wszystkie 123 nagrania, nie tylko muzykę Krowy
i Ponga. Domyślny format dla każdego nowego efektu, głosu, pętli i muzyki:
Ogg Opus `.opus`, 144 kb/s VBR, 48 kHz, ramki 20 ms, libopus audio,
complexity 10. Zachowuj mono/stereo, metadane i poziomy; nie normalizuj,
nie przycinaj i nie przekodowuj wielokrotnie plików już zgodnych.
Używaj `tools/encode_audio.rb` oraz oryginału poza paczką. Samo przemianowanie
pliku nie jest konwersją. Pakowanie odrzuca inne formaty i fałszywy nagłówek
Opus, ale nie koduje ponownie; identyfikatory dźwięków pozostają bez rozszerzeń.
`tools/generate-pong-echo.rb` również produkuje Opus z deterministycznego PCM.
Szczegóły procedury: `docs/BUILDING.md`. Licencje i autorstwo zachowaj.

120 WAV/Vorbis przekodowano; trzy podkłady Krowy 144 VBR pozostają identyczne.
Kopie 123 wejściowych plików: ../artifacts/game-room/source-audio/before-all-opus-232/.
Raporty obecnego etapu: ../diagnostics/all-audio-opus-144-232/.
Użytkownik następnie polecił spakować wszystko do tego samego buildu dla
testów dźwięków: 2.0.2.1/build 232/API 3.0.3, bez zmiany changelogu.
Poprzednią e4740b5e… zachować jako before-all-opus-signed.eltsetup.
Ten wpis rejestruje zakres i zgodę, nie potwierdza zakończenia pakowania.
Tylko celowane kontrole, bez pełnego runnera, instalacji, publikacji,
GitHuba, zmian serwera/profili i restartów. Raporty wcześniejszych etapów
zachowaj; poprzednie ograniczenie „tylko muzyka” zostało zastąpione.

## Muzyka Krowy: 144 kb/s VBR w źródłach — 21 września 2026

Najnowsza korekta użytkownika zastępuje docelowe 128 kb/s przez 144 kb/s
VBR. Trzy podkłady przekodowano ponownie z zachowanych oryginałów, nie
z wersji 128: stereo 48 kHz, libopus audio, complexity 10, ramki 20 ms.
Łącznie 8 624 675 B. Pozostałych 120 nagrań nie zmieniano. Metadane
Wieży słów zachowane. Oryginały nadal w ../artifacts/game-room/source-audio/
krowa-original-232; kopie 128 i nowe raporty w ../diagnostics/music-opus-144-232/.
Pełne dekodowanie i zapętlenie przez BASS/bassopus bez urządzenia audio
poprawne; długości niezmienione, różnica głośności najwyżej 0,1 LU.
Nie jest to odsłuch ani gwarancja identycznej jakości stratnego kodowania.
Nie przebudowano paczki: podpisana 232 e4740b5e… nadal zawiera 128 kb/s.
Wersja/build/changelog bez zmian, bez instalacji, GitHuba, serwera lub
restartu ELTEN-a. Dyskusja o kompresji pozostałych WAV-ów nie stanowi
jeszcze polecenia ich podmiany. Starsze raporty wydania zachować.

## Odchudzona paczka 232 — zatwierdzone, 21 września 2026

Najnowsze polecenie: testowo przekodować trzy podkłady Krowy do Opusa
128 kb/s VBR stereo, zachowując oryginały poza repo/paczką. Z instalatora
wyłączyć uzgodnione materiały deweloperskie, nie usuwać ich ze źródeł.
Następnie przebudować i podpisać tę samą 2.0.2.1/build 232, API 3.0.3,
z niezmienionym changelogiem. Poprzednią 232 7c29e1ca… zachować jako
before-runtime-only-signed.eltsetup. Wyniki: ../diagnostics/runtime-release-232/.
Nie zmieniać słowników ani innych nagrań; bez deduplikacji dźwięków Ponga.
Tylko celowane kontrole i binarne wczytanie gotowej paczki. Bez instalacji,
GitHuba, publikacji, zmian serwera/profili oraz restartu ELTEN-a.
Ten wpis odnotowuje zgodę, nie ukończenie podpisywania.

## Pakować tylko zawartość potrzebną graczowi

Nigdy nie przekazuj całego repozytorium do rekursywnego pakowania ELTEN-a.
Najpierw przygotuj oddzielny katalog przez `tools/release_files.rb`.
Wspólna lista dopuszcza kod produkcyjny, dane gier, nagrania, gotowe MO,
manifesty oraz licencje i informacje o źródłach. Testy, narzędzia, docs,
AGENTS/README/CONTRIBUTING/CHANGELOG.md, źródłowe katalogi tłumaczeń,
raporty importu i materiały redakcyjne pozostają w repo, nie w instalatorze.
Zasady i changelog aplikacji są w przygotowanym kodzie/tłumaczeniach.
Nowy nietypowy zasób wykonawczy dodawaj jawnie do reguł pakowania wraz
z celowanym testem; nie naprawiaj brakującego pliku kopiowaniem całego repo.
Przed wydaniem sprawdzaj dokładny zbiór plików, zależności, wymagane dźwięki,
zgodność bajtów ze snapshotem, podpis i binarne wczytanie gier/treści/PL/EN.
Testy uruchamiaj z katalogu źródeł przeciw gotowej paczce. Brak testów
w paczce jest oczekiwany; brak produkcyjnego pliku nigdy nie może być
maskowany wczytaniem jego odpowiednika z dysku. Zachowaj ochronę krótkiej
ścieżki stagingu na Windows i nie wydawaj archiwum z samym manifestem.

## Ponowna paczka 232 zatwierdzona — 21 września 2026

Najnowsze polecenie: przebudować i podpisać poprawki historii jako
2.0.2.1, ZACHOWUJĄC build 232 oraz dotychczasowe sześć punktów changelogu
PL/EN, bez dopisywania zmian. Jedynie nagłówek bieżącego wpisu dostaje
poprawny numer wersji. Nie tworzyć buildu 233. Poprzednią podpisaną 232
41e12923… zachować jako before-history-focus-signed.eltsetup.
Nowe raporty: ../diagnostics/history-focus-release-232/{SOURCE,PACKAGE}.json.
Ten wpis odnotowuje zgodę, nie zakończenie pakowania. Tylko celowane
kontrole i wczytanie binarne. Bez pełnego runnera, instalacji, publikacji,
GitHuba, serwera/profili i restartów. Wcześniejsze „jeszcze bez paczki”
odnoszą się do poprzedniego etapu.

## Historia po 232; następna wersja 2.0.2.1 — 21 września 2026

Usunięto pusty wiersz między wpisami historii. Tab czyta tylko bieżący
wpis z nagłówkiem, bez ruszania kursora/zaznaczenia. Wyłącznie podklasa
historii ogranicza odczyt z focus; ręczne Read all, Braille, ciche
odświeżanie oraz zwykłe pola/F1 pozostają natywne. Przy dalszych zmianach
sprawdzać faktyczny EditBox#focus, nie tylko pozycję kursora w atrapie:
host wywołuje read_text(0), a jego callbacki mogą przestawić pozycję.
Opis i regresje: docs/HISTORY_FOCUS_FIX_AFTER_232.md.

Użytkownik poprawił numer przyszłej paczki na 2.0.2.1. Tę wersję zastosować
przy następnym pakowaniu (manifesty/runtime/changelog). Nie zmieniano
podpisanej 232 ani jej historycznego changelogu; nowej paczki nie budowano.
Weryfikacja wyłącznie celowana, bez pełnego runnera, instalacji, publikacji,
GitHuba, zmian serwera/profili lub restartów. Raporty:
../diagnostics/history-focus-232/{BEFORE,SOURCE}.json.

## Pong, historia i F1 — wdrożone; wydanie 232 zatwierdzone, 21 września 2026

Użytkownik zatwierdził wdrożenie całego docs/PONG_AND_HISTORY_PLAN_231.md
i podpisanie nowej wersji 2.0.1.1. Źródła mają build 232, API nadal 3.0.3.
Wdrożono listę Classic/Arcade, nazwę Brzmienie band, kolejkę pełnych nagrań
i odczyt wyniku ponad 21, perspektywy obserwatora 1/2 oraz wspólną historię
i F1 jako tekst tylko do odczytu. Skróty historii: Ctrl+przecinek/kropka,
Ctrl+Shift+przecinek/kropka i Ctrl+Home/End. Zwykłe strzałki obsługuje
natywne pole tekstowe; czat zachowuje edycję. Indeksy znaków i wpisów
historii są oddzielne. Szczegóły: docs/PONG_AND_HISTORY_IMPLEMENTATION_232.md.
Do wydania wchodzi również wcześniejsza poprawka rewanżu.

Konfiguracja testu connection_recovery_test została uaktualniona zgodnie
z diagnozą: spójny zegar symulacji i właściwa atrapa gry, bez zmiany
asercji ani produkcyjnego quizu. NIE opisywać napraw testów w changelogu.
Changelog PL/EN zawiera sześć punktów dla graczy. Weryfikacja wydania:
../diagnostics/pong-history-release-232/{SOURCE,PACKAGE}.json.
Ten wpis nie potwierdza jeszcze zbudowania paczki. Tylko celowane testy
i kontrola binarna, bez pełnego runnera, instalacji, publikacji, GitHuba,
restartów ELTEN-a, zmian serwera/profili i żywego meczu. Podpisaną 231
a23ae0a5… zachować bez zmian. Poniższe wpisy opisują wcześniejsze etapy.

## Nowa lista Ponga, historii i F1 — tylko plan, 21 września 2026

Użytkownik zbiera poprawki przed osobnym poleceniem wdrożenia. Pełny plan:
docs/PONG_AND_HISTORY_PLAN_231.md. Obejmuje listę Classic/Arcade zamiast
checkboxa, nazwę Shift+E „Brzmienie band”, nieucinane liczby i zwycięstwo,
odczyt wyniku ponad 21, wybór perspektywy obserwatora oraz historię i F1
jako pola tekstowe tylko do odczytu. Perspektywa zgodnie z doprecyzowaniem:
1 — pierwszy gracz, 2 — drugi, tylko dla obserwatora w polu gry Ponga;
bez listy w Ctrl+P, z krótkim potwierdzeniem nazwy. Nadal wyłącznie plan.
Skróty historii ustalone zamiast propozycji z Altem: Ctrl+przecinek/kropka
przechodzi po wpisach kategorii, Ctrl+Shift+przecinek/kropka zmienia kategorię
(przecinek wstecz, kropka naprzód), Ctrl+Home/End wybiera pierwszy/ostatni
wpis wybranej kategorii. Nadal bez implementacji,
testów, zmiany wersji/changelogu, paczki, serwera lub GitHuba. Wcześniejsza
poprawka rewanżu w źródłach pozostaje; nie wdrażano jeszcze korekty testu quizu.

## Diagnoza starego testu odzyskiwania quizu — 21 września 2026

Niezaliczony connection_recovery_test wynika z nieaktualnej konfiguracji:
test skokowo przesuwa Time.now i ActionContext, ale nie elapsed używany przez
GameRoomSessionClock. Ponadto jego końcowa atrapa Object.new nie implementuje
moderator_action? z Base. W osobnym wariancie diagnostycznym spójny zegar
i atrapa dziedzicząca Base dają 13/13 przypadków bez zmiany asercji/produkcji.
question_server_clock_test oraz quiz_party_test przechodzą bez zmian.
Szczegóły: ../diagnostics/pong-rematch-231/QUIZ_TEST_DIAGNOSIS.{md,json}.
Nie poprawiono jeszcze testu w repo, tylko ustalono przyczynę na polecenie
użytkownika. Nie traktować tej asercji jako potwierdzonego błędu gry ani
nie zmieniać produkcyjnego zegara lub terminów, żeby ją maskować.

## Pong: naprawiony rewanż w źródłach — 21 września 2026

Po diagnozie na żywo odtworzono lokalnie błąd meczu 7→21 w tym samym pokoju
przed zmianą produkcyjnego kodu. Wspólny GameScreen zamyka teraz poprzedniego
klienta i wykonuje build/bind/start przy potwierdzonej nowej sesji. Nie robi
tego przy zwykłym odświeżeniu, bramce, powtórzonym ID lub nieudanym odczycie.
Nie zmieniono protokołu Communications ani LiveSessions. Gry bez klienta
nie dostają dodatkowych zasobów/żądań. Dalsze gry zręcznościowe mają używać
tego cyklu życia; close musi odłączyć timery, callbacki i zasoby starej sesji.
Opis i granice: docs/PONG_REMATCH_FIX_231.md. Nowe regresje:
test/axel_pong_rematch_test.rb oraz test/game_client_lifecycle_test.rb.
14/15 celowanych skryptów i 6 kontroli składni; pozostały test odzyskiwania
Quiz Party zawodzi identycznie na kodzie sprzed poprawki. Nie zamaskowano go.
Raporty poza repo: ../diagnostics/pong-rematch-231/{BEFORE_FIX,SOURCE,BASELINE}.json.
Bez nowej paczki, podpisu, instalacji, GitHuba, serwera lub żywej partii.
Wersja/changelog bez zmian. Podpisana 231 a23ae0a5… nadal nie ma tej naprawy.
Poprzednie polecenia pakowania/pusha zostały wykonane przed tym zadaniem.

## Pong: ponowna paczka 231 zatwierdzona — 21 września 2026

Najnowsze polecenie: przebudować i podpisać tę samą 2.0.2/build 231,
API 3.0.3, z poprawkami docs/PONG_CONNECTION_RECOVERY_231.md.
Changelog PL/EN dokładnie bez zmian. Poprzednią podpisaną 30d12a13…
zachować jako before-connection-recovery-signed.eltsetup. Nowy snapshot
i raporty: ../diagnostics/pong-connection-recovery-release-231/
SOURCE.json i PACKAGE.json. Ten wpis jest zgodą, nie potwierdzeniem
ukończenia. Tylko testy celowane i binarne, bez pełnego runnera, nowej
żywej partii, instalacji, publikacji, GitHuba, restartów i zmian serwera/profili.
Poniższy opis „źródła, bez paczki” dotyczy wcześniejszego etapu.

## Pong: ponawianie Communications i bramki — źródła, 21 września 2026

Na najnowsze polecenie naprawiono zestawianie kanału, brak odpowiedzi przed
pierwszą sesją, blokowanie reconnect przez zajętą operację, kontrolę Delivery
oraz zatrzymanie klienta podczas zapisu/odczytu LiveSessions. Bramkę słychać
po uzgodnieniu przez graczy; wynik i zwycięstwo nadal wymagają trwałego replaya.
Zachowano deduplikację i gotowość obu stron przed kolejnym serwisem.
Szczegóły, celowane regresje i ograniczenia: docs/PONG_CONNECTION_RECOVERY_231.md.
To zmiany źródeł po wydanej 231, NIE nowa podpisana paczka. Wersja/changelog
bez zmian. Bez instalacji, GitHuba, serwera, restartu lub testów żywych kont.
Nie uruchamiać pełnego runnera. Dawna zgoda na wydanie/push lobby została
już wykonana i nie jest poleceniem publikacji tych nowych poprawek.

## Lobby: obecne i przyszłe nowe gry; wydanie i GitHub — 21 września 2026

Użytkownik polecił zaznaczyć w komunikatach lobby również obecne nowsze
gry pominięte w starych ustawieniach oraz automatycznie każdą przyszłą.
Wdrożono osobny katalog `lobby_known_games` i zapis wyboru z formularza.
Zatwierdzona migracja obejmuje dziesięć gier od wersji 2.0; późniejsze
ręczne wyłączenia pozostają zapamiętane. Widget i subskrypcje powiadomień
pozostają niezależne, bez zapisów podczas odczytu. Szczegóły i kontrola:
docs/LOBBY_GAME_DEFAULTS_231.md.

Po poprawce PRZEBUDOWAĆ I PODPISAĆ tę samą 2.0.2/build 231, API 3.0.3,
a następnie WYSŁAĆ WSZYSTKIE ZMIANY REPOZYTORIUM NA GITHUB. To zastępuje
wcześniejsze wstrzymanie wysyłki. Bez instalacji i publikacji w ELTEN-ie,
zmian serwera lub profili. Tylko testy celowane i binarne, nie pełny runner.
Poprzednią a221d435… zachować jako before-lobby-defaults-signed.eltsetup.
Changelog PL/EN: dziesięć punktów (dotychczasowe dziewięć plus lobby).
Nowy snapshot/wyniki: ../diagnostics/lobby-game-defaults-231/. Ten wpis
odnotowuje zakres i zgodę; zakończenie potwierdzają dopiero raporty.

## Ponowne wydanie 231 z listą skrótów Widget — zgoda, 21 września 2026

Użytkownik polecił po ukończeniu poprawek przebudować i podpisać paczkę,
a następnie uruchomić drugą kopię ELTEN-a dotychczasowym skryptem.
Pozostają 2.0.2/build 231 i API 3.0.3. Aktualny changelog PL/EN ma dziewięć
punktów i opisuje bezpośrednią listę przypisań w Ustawienia → Widget,
natychmiastowy zapis oraz niezależność od Anuluj głównych ustawień.
Zachować poprzednią 79757ec0… jako before-inline-presets-signed.eltsetup.
Nowy snapshot i wyniki: ../diagnostics/widget-inline-release-231/
SOURCE.json oraz PACKAGE.json. Nie nadpisywać poprzednich raportów.
Ten wpis odnotowuje zgodę, nie potwierdza ukończenia. Tylko testy celowane
i kontrola gotowej paczki, bez pełnego runnera, instalacji, publikacji,
GitHuba, zmian serwera lub ręcznych zmian profili. Uruchomienie drugiej
kopii nie jest instalacją nowej paczki ani próbą żywego meczu.

## Skróty stołów bezpośrednio w Widget — 21 września 2026

Ostatnia lista pod Tabem w kategorii Widget to Ctrl+1–Ctrl+0, stan i Enter.
Enter otwiera wybór gry i wspólny formularz jej opcji/prywatności; bez
osobnego okna listy oraz pytania o nazwę. Zatwierdzenie zapisuje skrót
lokalnie od razu. Anuluj w głównych ustawieniach nie cofa przypisań;
anulowanie gry/opcji nie zmienia skrótu. Główny Zapisz nie może nadpisać
świeżych przypisań starą kopią. Inne ustawienia nadal są zatwierdzane
głównym Zapisz. Lista zachowuje fokus i wybraną pozycję; wyczyszczenie
z lokalnego menu zapisuje się od razu. Changelog PL/EN ma aktualną ścieżkę
i dziewięć punktów względem publicznej 230, bez historii testowych napraw
Ponga. Nie przebudowano paczki po tej korekcie; 79757ec0… pozostaje starsza.
Bez instalacji, publikacji, GitHuba, zmian serwera/profili i pełnego runnera.

## Widget, gry i zgoda na ponowne wydanie 231 — 21 września 2026

Wdrożono Ctrl+N i dziesięć presetów Ctrl+1–Ctrl+0 tylko na widgecie,
ustawiane w Ustawienia → Widget → Szybkie tworzenie stołów. Wspólna
ścieżka tworzenia, lokalny zapis, zatwierdzenie całego formularza,
ochrona istniejącego stołu i prywatności; bez automatycznego startu gry.
Chińczyk: 1–4, D z autorem rzutu, Shift+V według wspólnego toru.
Yahtzee: krótkie D, Jedynki–Szóstki zamiast „górnej części”, Nędza.
Makao: dobieranie mimo legalnej karty domyślnie w trzech profilach,
przełączane we własnym; tylko jedno dobranie, potem pas.
Mexican Train nie powtarza tego samego obowiązku domknięcia.
Krowa Losowe słowo: ręczny przycisk przelosowania, bez wyniku/galerii;
Wyścig zachowuje istniejący ręczny przycisk, bez automatu.
Opis: docs/WIDGET_AND_GAMES_FEEDBACK_231.md.

Najnowsze polecenie zastępuje wcześniejsze „bez paczki”: przebudować
i podpisać tę samą 2.0.2/build 231, API 3.0.3. Changelog PL/EN uzupełnić
o wszystkie niewydane zmiany, Pong na początku. W zasadach i changelogu
wspólna informacja: nie jest autorskim projektem papierka; Dragon-Pong,
ulepszenia Axela i balteama, port za ich zgodą (potwierdzone przez użytkownika).
Zachować wcześniejszą podpisaną 231 e39728b9… jako before-widget-games-feedback.
Wyniki SOURCE.json/PACKAGE.json w ../diagnostics/widget-games-feedback-231.
Ten wpis opisuje zakres i zgodę, nie potwierdza ukończenia podpisywania.
Tylko testy celowane/binarne; bez instalacji, publikacji, GitHuba,
serwera i żywych profili. Nie rozszerzać poprawek Ponga poza wcześniejszy
zatwierdzony zakres. Historyczne wpisy poniżej odnoszą się do swoich etapów.

## Pong: uzgodnienia z dostarczonych źródeł wdrożone — 20 września 2026

Bieżące polecenie: wdrożyć R01–R07, R11, R12, R18, R25 i R28 raportu
../outputs/pong-source-audit-20260920/POROWNANIE_AXEL_PONG.md. Nie mylić tych
oznaczeń z dawnymi F01–F08. Zakres/postęp: docs/PONG_SOURCE_FIXES_231.md.
Automatyczne odbijanie i trzy głośności są osobiste/lokalne, wspólny panel
w ustawieniach Game Roomu oraz przy stole Ponga (menu i Ctrl+P). Mysz stale
włączona tylko w aktywnym polu Ponga, bez M; zachować ochronę fokusu.
Lektor bazowo 50% zamiast 25%; proporcje paletek nadal 50%/20%.
Celowane testy lokalne, także dwie role/obserwator, boty, binarne źródła,
rzeczywiste PL/EN/fallback i dotknięte UI; nie uruchamiać pełnego runnera.
Showdown, ręczna pauza, globalna naprawa modalnej pomocy, transport/punkty,
perspektywa widza i inne niezatwierdzone różnice pozostają poza zakresem.
NIE budować/podpisywać, instalować, publikować, wysyłać na GitHub, zmieniać
serwera ani profili. Numery, changelog i ostatnia podpisana 231 bez zmian.
Ten wpis zastępuje wcześniejsze wstrzymanie implementacji i zgody na pakowanie.

Wdrożenie ukończone w źródłach. Wyniki w
../diagnostics/pong-source-fixes-231/SOURCE.json: 39/39 celowanych skryptów,
33/33 kontrole składni, idempotencja kompilatorów i diff check poprawne.
Sprawdzono także binarne źródła z rzeczywistym słownikiem ELTEN-a i szybki
panel bez sieciowych preferencji. Bez fizycznej myszy, odsłuchu i żywej gry.
Nie budowano ani nie podpisywano paczki; poprzednia 231 e39728b9… NIE ma
tych zmian. Automatyczny powrót piłki domyślnie wyłączony, trzy lokalne
głośności 0–200% domyślnie 100%, mysz zawsze aktywna tylko w polu Ponga.

## Pong: F02–F08 poprawione; zgoda na ponowną 231 — 20 września 2026

Użytkownik wyłączył punkt 1 z bieżących poprawek. F01 (timer w osobnej
pomocy) zostawiono bez zmian. Pozostałe potwierdzone różnice F02–F08
naprawione: role zasięgu, odgłos brzegu przeciwnika, ciągła panorama,
oryginalny mnożnik tarczy i stereo, dwa kierunki naraz, cicha korekta bota.
Raport: docs/PONG_PARITY_FIXES_231.md. Wcześniejszy audyt opisuje stan
przed naprawami, nie bieżącą listę siedmiu otwartych błędów. Ręczna pauza,
perspektywa widza i osobiste ustawienia nadal nie są nowymi funkcjami.

Regresja odtworzyła wszystkie siedem problemów przed zmianami; po nich
22/22 celowane skrypty i 12 kontroli składni poprawne, również binarne
źródła/PL/EN. Weryfikacja wydania rozszerza te kontrole; końcowe wyniki
w ../diagnostics/pong-parity-fixes-231/{SOURCE,PACKAGE}.json. Bez pełnego
runnera, wykonywania oryginalnego Pythona, żywej gry i odsłuchu urządzenia.

Najnowsze polecenie pozwala przebudować i podpisać tę samą 2.0.2/build 231,
z niezmienionym changelogiem PL/EN i API 3.0.3. Poprzednią 82f84e12…
zachować jako before-deep-parity-fixes-signed.eltsetup. Ten wpis nie jest
jeszcze potwierdzeniem ukończenia pakowania. Bez instalacji, publikacji,
GitHuba, zmian serwera/profili; nie wyłączać ochrony tabel.

## Pong: pogłębiony audyt i mysz — źródła, bez nowej paczki

20 września 2026: po żądaniu dokładniejszej zgodności powstał raport
`docs/PONG_DEEP_PARITY_AUDIT_231.md`. Nie uznawać poprzednich testów za
dowód pełnej zgodności. Nadal otwarte F01–F08: timery w modalnej pomocy,
zasięg przy właścicielu-obserwatorze, brzeg przeciwnika, panorama podczas
odtwarzania, mnożnik tarczy, nasycenie stereo, oba klawisze kierunku,
drobna cicha korekta pozycji bota. Ponadto brak ręcznej pauzy, wyboru
perspektywy widza i osobistych ustawień obecnych we wzorcu. Raport
rozdziela błędy, braki i wcześniej uzgodnione odstępstwa; nie wdrażać
nieuzgodnionych nowych reguł przy okazji diagnozy.

W ramach wcześniejszego polecenia dodania myszy wdrożono lokalne opt-in M,
ruch, lewy przycisk i oryginalną obronę przytrzymaniem. Kolejność w trybie
audio to klawiatura, odbicie, mysz; priorytet klawiatury dotyczy jedynie
oryginalnego trybu graficznego. Poprawiono też mały boczny limit piłki.
Tylko natywny adapter bez hooków/globalnej pętli, tylko aktywne pole Ponga.
21/21 celowanych skryptów źródeł/binarnych przeszło; bez pełnego runnera,
żywych kont, fizycznej myszy i odsłuchu. Próba diagnostyczna F02–F06
zapisuje rozbieżności, nie dowodzi ich naprawy.

Nie budowano, nie podpisywano, nie instalowano i nie publikowano paczki.
Wersja/changelog bez zmian; podpisana 231 z SHA 82f84e12… nie zawiera
tych najnowszych zmian. Nie zmieniano serwera ani profili i GitHuba.

## Pong: tempo i proporcje paletek — 20 września 2026

Użytkownik zgłosił wolniejszy ruch i polecił poprawić, po czym ponownie
podpisać tę samą 2.0.2/build 231 z niezmienionym changelogiem/API 3.0.3.
Po porównaniu wybrał wprost oryginalne proporcje paletek: własna 0,50,
przeciwnika 0,20. To zastępuje starsze zalecenie obu paletek 0,25.
Lektor i wszystkie inne efekty pozostają bez zmian. Szczegóły:
docs/PONG_TIMING_FIX_231.md. Nie zmieniać profili ani nagrań.

ELTEN nie wywołuje formularza dokładnie co 16 ms. Zachować resztę czasu
w planowaniu fizyki, do czterech kroków na wywołanie; dłuższego zatrzymania
nie nadrabiać po wznowieniu. Regresje muszą przechodzić przez FormTimer
z różnymi rytmami, nie tylko idealne 16 ms. Zachować pojedyncze zdarzenie
odbicia i zabezpieczenie klawiszy podczas pauzy; bez ręcznej pętli UI.

Wyniki źródeł i gotowej paczki: ../diagnostics/pong-timing-231/
{SOURCE,PACKAGE}.json. Ten wpis odnotowuje zakres, nie ukończenie podpisu.
Poprzednią 231 a853859a… zachować jako before-timing-fix-signed.eltsetup.
Tylko celowane testy i kontrola binarna, bez pełnego runnera, instalacji,
publikacji, GitHuba, zmian serwera/profili i nowych prób na żywych kontach.
Nie utożsamiać parametrów dźwięku z odsłuchem urządzenia.

## Wierniejsze odwzorowanie Ponga i ponowne wydanie 231 — 20 września 2026

Użytkownik polecił poprawiać wykryte różnice względem oryginału, z wyjątkiem
UI i usług zastępowanych przez ELTEN. Aktualny zakres i granice:
docs/PONG_ORIGINAL_PARITY_231.md. Ten wpis zastępuje historyczne założenia
poniżej o braku silnika gościa i zatrzymaniu po 0,6 s bez pozycji.
Dwaj ludzie mają lokalny lot i własne kontakty, niezawodne zdarzenia
Communications oraz zastępowalne pozycje. Punkty nadal przechodzą przez
GameRepository/LiveSessions z akceptacją obu uczestników. Zachować ochronę
nadawcy/roli/generacji/kolejności i ograniczone bufory; nie usuwać zdarzeń
przez ciche obcięcie listy. W grze z botem silnik pozostaje u właściciela.

Echolokacja Shift+E to zatwierdzone udostępnienie nieaktywnego kodu wzorca,
nie istniejąca opcja menu oryginału. Ctrl+W tylko dla ludzi: jeden zegar
właściciela, 10 s, odstęp 15 s, anulowanie przy serwisie/utracie kanału;
uwzględniać wyścig serwisu z timeoutem. Publiczność pozostaje nieaktywna,
bez reklamowania skrótu, bo brakuje nagrań. Zachować cichszy balans 25%.

Najnowsze polecenie pozwala po kontroli przebudować i podpisać tę samą
2.0.2/231, bez zmian changelogu i API 3.0.3. Wyniki:
../diagnostics/pong-original-comparison-231/{SOURCE,PACKAGE}.json.
Sam wpis nie potwierdza ukończenia paczki. Zachować starą 231 o SHA
7281d98a… jako build-231-before-original-parity-signed.eltsetup.
Tylko celowane testy oraz gotowej paczki, nie pełny runner. Bez instalacji,
publikacji, GitHuba, zmian serwera/profili, wykonywania odzyskanego Pythona
i nowych prób na żywych kontach. Nie utożsamiać symulacji ani poprzedniego
testu Communications z ręcznym sprawdzeniem tego nowego modelu.

## Ponowne podpisanie 2.0.2/231 — zatwierdzone, 20 września 2026

Użytkownik polecił przebudować paczkę z poprawkami Ponga, pozostawiając
changelog dokładnie bez zmian. Wersja 2.0.2/build 231 i API 3.0.3 bez zmian.
Poprzednią 231 c77acf05… zachowano jako build-231-before-pong-feedback-signed.
Wyniki w ../diagnostics/pong-feedback-231/{SOURCE,PACKAGE}.json. Ten wpis
jest zgodą na pakowanie, nie potwierdzeniem zakończenia. Przed oddaniem
sprawdzić podpis papierek, wszystkie pliki i binarne wczytanie nowych regresji,
niezmienione changelogi PL/EN i starsze nagrania. Bez pełnego runnera,
instalacji, publikacji, GitHuba i zmian serwera. Wpis „jeszcze bez paczki”
poniżej opisuje stan sprzed tego polecenia.

## Pong — poprawki źródeł po 231, 20 września 2026

Naprawiono `nil.server` po punkcie odebranym przed nowym obrazem i przenoszenie
naciśnięć Up/Spacji z pauzy do serwisu. Gość nie posiada silnika: wznowienie
wymaga obrazu właściwej wymiany. Zachować świeże naciśnięcia podczas gry,
ale nie kolejkować klawiszy z pauzy ani serwować powtórzeniem przytrzymania.
Przytrzymanie w trakcie aktywnej gry nadal odbija przy bramce, jak w oryginale;
użytkownik potwierdził to ręcznie. Nie usuwać tej odrębnej zasady.

Audio punktu pochodzi z zaakceptowanego zdarzenia LiveSessions i nie może
być ucinane przez zwykły detach/reset widoku. Kolejka lektora działa także
na ekranie zakończonego meczu, bez sleep/pump i bez wpływu na sieć/fizykę.
Obie paletki mają cichszy poziom 0,25 i ton rosnący do środka, opadający
ku drugiemu brzegowi. Kroki bota sumują małe przesunięcia do progu dźwięku.
Opis i ograniczenia: docs/PONG_FEEDBACK_FIXES_231.md; cztery nowe regresje
`axel_pong_{rally_sync,serve_input,audio_feedback,point_audio}_test` wchodzą
również do binarnego testu Ponga.

Jeszcze bez nowej paczki; podpisana 2.0.2/231 c77acf05… pozostaje bez zmian
i nie zawiera tych poprawek. Bez zmiany wersji/changelogu, instalacji,
publikacji, GitHuba i serwera. Nowe testy lokalne nie zastępują odsłuchu
ani poprzedniej próby rzeczywistego kanału. Wyniki końcowe w
../diagnostics/pong-feedback-231/SOURCE.json, nie w raporcie starej paczki.
Weryfikacja końcowa: 25 celowanych skryptów, 11 kontroli składni i binarne
wczytanie źródeł, zgodność manifestów/nagrań, idempotencja kompilacji oraz
diff check. Pełny runner nie był uruchamiany.

## Testowe wydanie 2.0.2/build 231 — zatwierdzone, 20 września 2026

Najnowsze polecenie użytkownika pozwala zbudować i podpisać testową paczkę
z ukończoną adaptacją Ponga. Wersja 2.0.2/build 231, API nadal 3.0.3.
Changelog PL/EN ma trzy nowe punkty pod jednym nagłówkiem; stare zachować.
Build 230 o SHA 02801479338fde099f3e80efc69c25d56925f20f9e352ab27ebc84c162e7ad44
pozostawić bez zmian. Nie instalować, nie publikować, nie wysyłać na GitHub
ani nie zmieniać serwera/profili. Zgoda na testową paczkę nie potwierdza praw
do publicznego rozpowszechniania oryginalnych nagrań.

Celowane testy, nie pełny runner. Po podpisie sprawdzić binarne wczytanie,
rzeczywisty słownik PL/EN/fallback, podpis papierek, manifest/runtime oraz
zgodność wszystkich plików ze zweryfikowanym snapshotem. Wyniki końcowe:
../diagnostics/release-2-0-2/SOURCE.json i PACKAGE.json. Sam wpis nie jest
potwierdzeniem ukończenia paczki. Wcześniejszy zakaz pakowania Ponga poniżej
opisuje etap przed tym nowym poleceniem.

## Axel Pong i Communications — niewydane, 20 września 2026

Dodano adaptację Classic/Arcade, silnik o kroku 16 ms, sześć poziomów,
boty, dźwięk pozycyjny i instrukcję PL/EN. Stan trwały i punkty nadal idą
przez GameRepository/LiveSessions. `lib/realtime` przenosi tylko zastępowalne
obrazy i sterowanie; nie przywraca starego transportu turowego. Każda
kolejna gra musi walidować swój payload, zdefiniować bezpieczny moment
zatwierdzenia wyniku i własne zachowanie po utracie kanału. Nie wysyłać
wyniku z powierzchni ani bezpośrednio z timera, z pominięciem replaya.

Wymagane: uwierzytelniony nadawca natywny, identyfikator partii i generacji,
rosnące numery, pełne obrazy, ograniczony bufor i rozmiar pakietu. Brak
pakietów ma zatrzymać grę i prowadzić do ponowienia; nie odtwarzać minionych
sekund fizyki w przyspieszeniu. Własność zasobów musi uwzględniać zamknięcie
podczas tworzenia endpointu/sesji oraz zamknięcie przez sam transport.
Początkowe zestawianie kanału musi dać czas na natywne ponowienie zaproszenia,
a nie używać krótszego limitu milczącego już zestawionego strumienia.

Nie dodawać ręcznego pump/loop_update, globalnych monkeypatchy ani HTTP
w klatce. Używać wspólnego formularza i jego cyklu attach/detach, zegara
monotonicznego, skończonych prac sieciowych w tle. `supports_bot_move_delay?`
domyślnie zachowuje dotychczasowe gry; ciągły bot Ponga wyłącza tę opcję.
Pong nie obsługuje zapisu niedokończonego meczu.

Użytkownik dopuścił próbę między kontem głównym i testowym, przez tymczasowy
prywatny kanał, bez instalacji i zmiany istniejących stołów. Raport kodu
i granice sprawdzenia: docs/AXEL_PONG_PORT.md. Celowane wyniki są poza repo
w ../diagnostics/axel-pong-port/. Test kanału nie jest ręcznym meczem ani
testem publikacji punktów na serwerze. Nie wyciągać z niego gwarancji
usunięcia wszystkich historycznych problemów synchronizacji.

Nie budować, podpisywać, instalować ani publikować bez nowego polecenia.
Build 230, changelog, GitHub i ochrona tabel pozostają bez zmian. Przed
publiczną dystrybucją ustalić prawa do użytych oryginalnych nagrań.
Nie dodawać do repo odzyskanego Pythona, telemetrii ani danych dostępowych.

## Tysiąc dla dwóch osób; wydanie 2.0.1.1 — 19 września 2026

Zatwierdzono i wdrożono wariant dwóch osób: dwa zakryte musiki po 2/3 karty,
wybór jednego przez rozgrywającego, odłożenie tej samej liczby kart bez oddawania
przeciwnikowi, opcjonalne punkty z obu rezerw dla zwycięzcy ostatniej lewy.
Domyślne: trzy osoby; po wybraniu dwóch osób musik 3 i checkbox włączony.
Obie osoby potrzebują nowej wersji. Planer nie może czytać cudzych odłożeń
ani rzeczywistego niewybranego musiku. Zachowano dotychczasowe ziarno RNG
i trzyosobowe zdarzenia; liczba lew wynika z rozmiaru rąk. Nowe fazy objęto
zapisem/wznowieniem. Beczka ogłaszana raz przy wejściu, oznaczenie pod S
znika po opuszczeniu; Shift+S bez zmiany. docs/TYSIAC_TWO_PLAYER.md.

Najnowsze polecenie upoważnia do zbudowania i podpisania 2.0.1.1/build 230
z wcześniejszymi niewydanymi poprawkami. Starsze zakazy pakowania nie są
aktualną blokadą. Zachować podpisaną 229, historyczne changelogi i API 3.0.3.
Nowy changelog PL/EN ma dziewięć punktów. Bez instalacji, publikacji, GitHuba
i zmian serwera. Przed pakowaniem celowane testy, po nim binarne wczytanie
gotowej paczki, podpis autora i zgodność wszystkich plików ze snapshotem.
Wyniki: ../diagnostics/release-2-0-1-1/{SOURCE,PACKAGE}.json; obecność tego
wpisu nie zastępuje końcowego wyniku weryfikacji.

## Czas serwera, historia i krótsze F1 — niewydane, 19 września 2026

Na polecenie „napraw farkle” usunięto nadmiarowe „dokończcie obieg”, gdy
limit osiąga ostatni gracz. Stan `final_round` i `finish_turn` bez zmian;
ogłoszenie powstaje tylko wtedy, gdy następny gracz nie jest pierwszym
w kolejności miejsc. Nie dodawać dodatkowych tur ani zmieniać punktacji.
Nowa regresja odtworzyła błąd przed naprawą; po niej trzy celowane skrypty
Farkle/dźwięków i składnia poprawne. Szczegóły i granice testów:
docs/FARKLE_FINAL_CIRCUIT_MESSAGES.md. Nie budowano nowej paczki.

Na polecenie użytkownika przejrzano zegary całego dodatku. Wspólny
GameRoomClock synchronizuje czas w istniejącym zadaniu sieciowym/tle;
odczyt nie robi HTTP, upływ mierzy monotonicznie. Zaproszenia/ogłoszenia
liczą ważność od koperty serwera, także dla starych nadawców. Historia
LiveSessions używa kolejności stosu, korekty dat nie powtarzają ruchów.
GameRoomSessionClock zachowuje epokę, pauzę i czas zapisanej partii; używany
także przez odczyty limitów, Quiz i dzienną Krowę. Liczniki UI/botów/retry
pozostają monotoniczne. Nie wracać do Time.now dla wspólnych terminów ani
sortowania zdarzeń. Nowe testy muszą obejmować różne zegary obu klientów.

Dodatkowo wspólne opisy F1/skrótów w zasadach mają formę „Ctrl+R, Odczytaj
wariant i ustawienia stołu.”, bez „Naciśnij …, aby:”. Klawisze bez zmian.
Szczegóły: docs/SERVER_CLOCK_AUDIT_229.md. 58/59 celowanych uruchomień;
niezaliczony stary test rules_shortcut_reference wskazuje zastany zbiorczy
wpis Tab/Shift+Tab w Krowie. Nie przerabiano go ani nie osłabiano asercji.
Bez pełnego runnera i żywej gry. ELTEN ma osobne lokalne porównanie ważności
w głównej liście powiadomień i natywnej kolejce zaproszeń; tego kodu nie
zmieniano. Nie twierdzić, że dodatek naprawia również tę granicę hosta.
Wersja/changelog, instalacja, serwer, GitHub i podpisana paczka 229 f3935830…
bez zmian. Paczka NIE zawiera tych ani wcześniejszych lokalnych poprawek UI.

## Komunikaty i listy — niewydane, 19 września 2026

Skrócono warunkowe opcje Krowy i dopasowano zasady/sterowanie PL/EN.
Statki odczytują raz pytanie o rozstawienie, potwierdzają przyjętą własną
losową flotę i rozpoznają pierwszą turę po fazie rozstawiania. Monopoly:
grupy w Shift+D, „grupa 2 z 3”, numer budowanego domu, czynsz pod V/Enter
(także Shift+V). Zachowano ekonomię, transport i prywatność flot.
Zgłoszenia własnego czatu użytkownik nie potrafi potwierdzić; nie zmieniać
tego mechanizmu na podstawie samego wcześniejszego przypuszczenia.
Opis i granice testów: docs/UI_FEEDBACK_229.md. Zachowano wcześniejszą
poprawkę nil-state opóźnienia bota. Tylko testy celowane, także binarne
PL/EN/fallback; bez pełnego runnera i żywej gry. Nie przebudowano ani nie
podpisano paczki, nie zmieniano changelogu, instalacji, serwera lub GitHuba.
Nie traktować historycznych zgód na wydanie poniżej jako nowego polecenia.

## Krowa i ponowne wydanie 229 — 18 września 2026

Najnowsze polecenie zezwala po zakończeniu weryfikacji zbudować i podpisać
tę samą 2.0.1/build 229 z Krową (PR #10, paoscripts, autor opisany na prośbę
użytkownika jako paulinux) i wcześniejszymi lokalnymi poprawkami audytu.
Zastępuje wcześniejsze wstrzymanie wydania, nie upoważnia do instalacji,
publikacji, GitHuba ani scalenia/zamknięcia PR-u. Changelog: zachować
28 wcześniejszych wpisów PL/EN i dodać TYLKO jeden opis Krowy z autorstwem.
Nie uruchamiać pełnego runnera; używać kontroli celowanych i gotowej paczki.

Zakres i dowody: docs/KROWA_IMPLEMENTATION.md oraz
../diagnostics/krowa-implementation/{SOURCE,SERVER,PACKAGE}.json.
Przyjęto poprawki 1–11 przeglądu. Baza rzeczowników, jej duplikaty,
kolejność i algorytm losowania pozostają identyczne z PR-em na wyraźne
polecenie użytkownika. Także osiem plików Audio/krowa-* bez edycji.
Nie usuwać duplikatów jako rzekomej optymalizacji.

Wyścig i Wieża mają prywatny lokalny sekret w pełnym zapisie. Wznowienie
musi go zweryfikować i zapisać pod nowym ID sesji PRZED publikacją archiwum
i startu. Brak sekretu nie może zostać uznany za udane wznowienie. Ujawnienie
po poddaniu w Wyścigu jest adresowaną wiadomością, nie wspólnym zdarzeniem.
Sprawdzać nadawcę, odbiorcę, fazę, rundę i zobowiązanie; nie odtwarzać starego
krowa_surrender_word jako ujawnienia. Kontroler nadal zna własny sekret.
Dzień Warszawy pochodzi z prawdziwego czasu serwera, nie epoki partii.
Usuniętych własnych słów nie odtwarzać przy ponownym czytaniu starej historii.

Cztery nowe tabele Krowy już dodano po potwierdzeniu konta papierek.
Zastane tabele i protected/powiadomienia zachowano. Nie powtarzać migracji;
testy publikacji/rankingów korzystają z atrap, nie żywych rekordów konta.
Nie osłabiać zamierzonej bramki dostępu do tabel. Metody klienta, rankingi,
ograniczenia ról i formularzy pozostają opcjonalnymi hookami Base, domyślnie
neutralnymi dla pozostałych gier. Nie utożsamiać testów z żywą rozgrywką.

## Poprawki po audycie klas — źródła, bez nowego wydania

Użytkownik zatwierdził potwierdzone błędy z listy 1–12, z wyjątkiem
punktu 2/F11 (zamierzona kontrola dostępu do tabel), bez optymalizacji
O01–O04. Wdrożenia i granice sprawdzenia opisuje docs/AUDIT_FIXES_229.md;
wyniki celowanych prób: ../diagnostics/audit-fixes-229/RESULTS.json.
Końcowo 59/59 uruchomień i 25 kontroli składni poprawnych, bez zmian
poza jawnym zakresem. Zachowano 579 wcześniejszych plików identycznie,
w tym dane, tłumaczenia, dźwięki, manifesty i changelog.
Starsze narzędzia merge-quiz-pool i refine-quiz-decisions-semantic-safety
nie są podłączone do obecnej ścieżki gry/danych/wydania; nie uruchamiać ich
na danych bez wcześniejszego usunięcia problemów F13/F14 z audytu.

Przy zmianach zegara sprawdzać nie tylko wolniejszy klient, ale też
pozostały czas po zapisie/wznowieniu oraz metadane serwera otrzymane
przed lub po odpowiedzi na zapis. Nie traktować lokalnego Time.now jako
potwierdzonego czasu serwera. Zachować ścisłe odrzucanie starych tur.
Ponowienie odpowiedzi na zaproszenie to nie ponowne zaproszenie: zachować
tożsamość decyzji, granicę czasu, izolację kont i brak podwójnej historii.
Wynik partii ma pozostać w historii, ale automatycznie odczytywać się raz.

Zmiany są niewydane. Nie budować/podpisywać na podstawie starszych wpisów.
2.0.1/229, changelog i podpisana paczka 9d2d6fdd… pozostają bez zmian.
Nie wykonano instalacji, publikacji, operacji GitHub, serwera ani profili.
Tylko testy celowane; nie przedstawiać symulacji jako prób żywych klientów.

## Ściszenie Statków: ponowne pakowanie 229 bez zmian changelogu

Użytkownik polecił przebudować i podpisać tę samą 2.0.1/build 229 ze
ściszeniem sześciu efektów Statków do 20% bazowego poziomu. Zachować
changelog PL/EN dokładnie bez zmian: dotychczasowe 28 punktów, bez nowego
wpisu o ściszeniu. Nie zmieniać nagrań, pauz, pozostałych dźwięków ani
preferencji użytkownika. Raport: docs/BATTLESHIP_SOUND_BALANCE.md.
Wyniki bieżącego pakowania: ../diagnostics/battleship-volume-229/SOURCE.json
i PACKAGE.json. Zachować poprzednią paczkę d49e824b… osobno; nie uznawać
samego tego wpisu za potwierdzenie wydania. Testy celowane, bez pełnego
runnera, instalacji, publikacji, GitHuba, serwera i zmian profili.

## Ctrl+F1: pusta lista skrótów — poprawka i ponowny build 229

Zgłoszenie Scrabble odtworzono przez pełną ścieżkę wyjścia z oczekiwania:
`wait_for_action` czyścił opisy w `ensure`, zanim otwierało się okno zasad.
Zachowywać jednorazowy snapshot aktualnej pomocy pól gry przed sprzątaniem;
nie usuwać cleanup ani nie przywracać stałych list nieaktualnych skrótów.
Nowy test `rules_help_lifecycle_test.rb` musi przechodzić przez Ctrl+F1/menu,
zakończenie oczekiwania i dopiero wyświetlenie listy. Samo przypięcie opisów
i bezpośrednie otwarcie okna nie odtwarza tego błędu. Sprawdzać też źródła
binarne i gotową paczkę, PL/EN, obserwatora oraz zachowanie kursora/czatu.
Raport: docs/RULES_HELP_LIFECYCLE_229.md. Użytkownik polecił przebudowanie
i podpisanie tej samej 2.0.1/229, zachowanie 27 punktów i jeden nowy PL/EN.
Wynik sprawdzać w ../diagnostics/rules-shortcuts-229/SOURCE.json i PACKAGE.json.
Zachować poprzednią podpisaną paczkę e1c7b20d…; bez instalacji, publikacji,
GitHuba, serwera, profili i pełnego runnera.

## Statki: audio i ustawianie floty; ponowny build 229 — 18 września 2026

Użytkownik zatwierdził sześć dźwięków Statków (dwa trafienia, trzy starty
rakiety, jedno pudło), odczekanie końca dźwięku przed kolejnym zdarzeniem
oraz wybór Losowo/Ręcznie po rozpoczęciu partii. Kolejka prezentacji jest
lokalna i włączona TYLKO w Statkach; inne gry nadal nakładają dźwięki.
Nie blokować czatu ani odbioru sieci, nie używać sleep, nie odpytywać serwera
z powodu samego zakończenia dźwięku. Tryb i ręczny szkic przeżywają odświeżenie;
losowa flota nadal jest prywatna, a powtórzenie wysłania zachowuje commitment.
Szczegóły: docs/BATTLESHIP_AUDIO_AND_SETUP_229.md.

Dodatkowa poprawka wspólnego formularza: po wybraniu gry zaczynać na
instrukcji „Wybierz opcje gry…”, nie na polu prywatności. Tab dopiero potem
przechodzi na Stół prywatny. Nie przestawiać pól ani zmieniać ustawień.
Zaktualizowano testy 25 formularzy oraz binarnego kodowania.

Najnowsze polecenie zatwierdza przebudowanie i podpisanie tej samej wersji
2.0.1/build 229. Zachować wcześniejsze 24 punkty changelogu, dodać trzy PL/EN.
Wynik końcowy sprawdzić w ../diagnostics/battleship-audio-setup-229/SOURCE.json
i PACKAGE.json — sam wpis nie potwierdza ukończenia pakowania. Zachować
poprzednią podpisaną 229 (aae9df52…). Testy celowane, bez pełnego runnera,
instalacji, publikacji, GitHuba, serwera i zmian profili.

## Statki/Mankala wdrożone; przebudowa 229 zatwierdzona, 18 września 2026

Najnowsze polecenie użytkownika znosi wcześniejsze wstrzymanie pakowania:
włączyć PR #8/#9 z uzgodnionymi poprawkami, uzupełnić changelog, przebudować
i podpisać tę samą 2.0.1/build 229. Bez instalacji, publikacji, GitHuba,
scalania PR-ów, zmian serwera/profili i pełnego runnera. Zachować wszystkie
wcześniejsze niewydane zmiany; teraz również mają wejść do paczki.
Gry włączono z zachowaniem autorstwa Dawida Piepera i przyjętych reguł Ayoayo.
Zakres i ograniczenia: docs/BATTLESHIP_MANCALA_229.md. Instrukcje obu gier
są przystępnymi opisami PL/EN z przykładami; polskie i angielskie źródła
służą redakcji, nie nadpisywaniu uzgodnionych odmian. Zachować ten standard.
Statki nie obsługują zapisu/wznowienia, dopóki nie będzie bezpiecznej obsługi
prywatnych flot obu graczy. Mankala korzysta ze wspólnego zapisu.
Walidacja i gotowa paczka są dokumentowane w katalogu roboczym
diagnostics/new-board-games-229/SOURCE.json oraz PACKAGE.json. Nie deklarować
zakończenia podpisywania na podstawie samego tego wpisu; sprawdzić wynik.


## PR #8/#9 — zatwierdzone zasady Ayoayo, 18 września 2026

Użytkownik zaakceptował poprawki przeglądu Statków i Mankali, po czym
zatwierdził zachowanie odmiany Ayoayo z PR #9 Pajpera. NIE zmieniać bicia
na wersję pozostawiającą własny kamień: PR zabiera kamienie przeciwnika
oraz własny kamień kończący ruch. Zachować też przyznawanie pozostałych
kamieni ostatniemu wykonującemu ruch przy zakończeniu z braku legalnego
ruchu. To przyjęty wariant, nie bezsporne błędy M1/M2 wcześniejszego audytu.
Doprecyzować te reguły w instrukcji PL/EN i testach, bez mieszania opisów
Mancala World i Johna Pratta. Raport skorygowano w
../diagnostics/pr-8-9-review-20260918/REVIEW.md.

Ten wpis dokumentuje decyzję, NIE wykonanie pozostałych poprawek ani
integrację PR-ów. Bez budowania, podpisywania, publikacji i zmian serwera;
wcześniejsze wstrzymanie wydania pozostaje aktualne.

## Tasowanie, kolejność wyników i changelog — niewydane, 18 września 2026

Na polecenie użytkownika dodano komunikat „Przetasowano talię.” i zasób
card-shuffle przy faktycznym recyklingu talii UNO, Makao, 99, Rummy oraz
Pokera dobieranego. Nie zmieniać RNG ani zasad dobierania: wspólny
GameRoomCardDeckHistory obserwuje istniejący licznik tylko po przyjęciu
zdarzenia. Historia i audio korzystają ze standardowej ochrony przed
powtórzeniem. Nowe rozdanie ani pusta talia bez kart do recyklingu nie są
takim zdarzeniem. Dźwięk CC BY 4.0; autor i źródło w THIRD_PARTY_NOTICES.

Odczyt punktacji pod S ma malejący wynik liczbowy i trwałe eliminacje na
końcu. Używać wspólnego score_announcement_order również w nowych grach;
nie sortować miejsc, nie zerować wyników, nie uznawać samego zera za
eliminację. Remisy zachowują kolejność miejsc; drużyny pozostają razem.
Nie zmieniać S służącego do liczenia pionków lub tylko własnych żetonów.
Monopoly sortuje majątek, a Poker sortuje cudze żetony pod Shift+S.

Uzupełniono istniejący changelog 2.0.1/229 w PL/EN: zachowano 14 punktów,
dopisano osiem zaległych, również o filtrach, zegarach, Ctrl+R i pomocy.
Wydanie nadal WSTRZYMANE: bez budowania, podpisywania, instalacji,
GitHuba, serwera i zmian profili. Szczegóły oraz wyniki bieżącej weryfikacji:
docs/CARD_RESHUFFLE_AND_SCORE_ORDER_229.md i
../diagnostics/card-reshuffle-scores-229/RESULTS.json.

## Wydanie wstrzymane; nowe limity czasu — 18 września 2026

Użytkownik wyraźnie zatrzymał budowanie i podpisywanie. W źródłach są
niewydane filtry kontaktów, wspólny thinking time i poprawki pomocy/Ctrl+R.
Najnowsze uzgodnienie: 99 po czasie traci jeden żeton, Poker automatycznie
pasuje. W wymianie Pokera dobieranego gracz all-in zachowuje karty bez
wymiany i nadal bierze udział w showdown — nie wolno go spasować.
Weryfikacja zakończona: 52/52 skrypty wspólne i 8/8 dodatkowych uruchomień
zegarów, składnia 59 Ruby, idempotencja zasad i binarne wczytanie. Jeden
osobny stary test wymian Monopoly nie przechodzi identycznie na HEAD
sprzed zmian; nie liczyć go jako zaliczonego. Szczegóły i granice kontroli:
docs/CONTACT_FILTERS_AND_TIMERS_229.md. Bez pełnego runnera i żywych
klientów. Numery 2.0.1/229, istniejąca podpisana paczka, GitHub, serwer
i profile bez zmian.
Starsze zgody na pakowanie poniżej nie upoważniają do nowego wydania.

## Ponowne pakowanie 2.0.1/229 — 18 września 2026

Najnowsze polecenie zatwierdza przebudowanie i podpisanie tej samej wersji
2.0.1/build 229 z formularzem prywatności, domyślnymi grami widgetu oraz
nowymi dźwiękami kostek w Domino i Mexican Train. Te trzy punkty dopisano
do istniejących 11 w tym samym changelogu PL/EN. Starsze statusy niewydania
poniżej opisują etap przed tym poleceniem. Zakres i testy:
docs/DOMINO_SOUNDS_229.md. Wynik podpisania i gotowego artefaktu sprawdzać
w ../diagnostics/release-2-0-1-refresh/PACKAGE.json, nie w historycznych
wynikach pierwszej 229. Poprzednią 229 z SHA 0ac85551… zachować osobno.
Tylko testy celowane, bez instalacji, publikacji, GitHuba i zmian serwera.

## Domyślne gry widgetu — poprawione, niewydane, 18 września 2026

Użytkownik zatwierdził jednorazowe włączenie sześciu gier z 2.0 w starych
ustawieniach oraz domyślne zaznaczanie każdej przyszłej nowej gry.
GameRoomPreferences normalizuje widget_games razem z widget_known_games;
nowe ID rejestru są domyślnie wybrane, zapisane ręczne odznaczenia zostają.
LEGACY_WIDGET_GAME_IDS jest zamkniętą listą 17 gier sprzed 2.0, wyłącznie
do migracji danych bez widget_known_games — nie dopisywać do niej nowych
gier. Samo zarejestrowanie kolejnej gry ma wystarczyć. Ustawienia zapisują
znane ID razem z wyborami; odczyt pozostaje bez zapisów na dysku. Nie
zmieniać tym mechanizmem lobby ani subskrypcji powiadomień. Opis:
docs/WIDGET_NEW_GAME_DEFAULTS.md; test widget_game_defaults_test obejmuje
aktualizacje, zapis/odznaczenia, niezależne profile i formularz ustawień.
13/13 testów celowanych, składnia trzech Ruby i diff check poprawne.
Bez pełnego runnera i żywych klientów. Bez nowej paczki: podpisana
2.0.1/229 z SHA 0ac85551… nie zawiera tej zmiany ani formularza prywatności.
Wersja, changelog i PL.mo niezmienione; nie instalowano, publikowano,
wysyłano na GitHub, zmieniano serwera ani żywych profili użytkownika.

## Prywatność tworzonego stołu — poprawione, niewydane, 18 września 2026

Na polecenie użytkownika przeniesiono „Stół prywatny” do wspólnego
formularza opcji, przed ustawieniami gry. `show_create_table` korzysta
z `configure_game_options(..., creating_table: true)`; wynik zawiera
osobno `game_options` i `private_table`. Zwykła edycja zachowuje dawny
wynik i nie pokazuje prywatności. Nie wkładać tego pola do definicji
opcji poszczególnych gier, JSON zasad ani zapamiętanego profilu.
Osobne `choose_table_privacy` usunięto. Domyślnie publiczny; wybór
przeżywa zmianę języka i walidację. Szczegóły:
`docs/PRIVATE_TABLE_CREATION_FORM.md`. 10/10 celowanych skryptów i składnia
trzech Ruby poprawne; nowe testy private_table_creation oraz
private_table_creation_encoding obejmują 23 gry i binarne ładowanie.
Nie przebudowano paczki: podpisana 2.0.1/229 z SHA 0ac85551… NIE zawiera
tej poprawki. Wersja, changelog i PL.mo niezmienione. Bez instalacji,
publikacji, GitHuba, serwera, pełnego runnera i żywych klientów.

## Przygotowanie wydania 2.0.1/build 229 — 18 września 2026

Najnowsze polecenie użytkownika zatwierdza zbudowanie podpisanej paczki
z wersją 2.0.1. Build 229 obejmuje 12 poprawek POST_228 oraz nowe zasady
23 gier. Nowy changelog PL/EN zawiera 11 punktów pod jednym nagłówkiem;
historyczne wpisy pozostają niezmienione. API nadal 3.0.3. Podpisana
228 ma pozostać nietknięta. Bez pełnego runnera, instalacji, publikacji,
GitHuba i zmian serwera. Zakres: `docs/RELEASE_2_0_1.md`.
Końcowe wyniki sprawdzać w katalogu roboczym poza repozytorium:
`../diagnostics/release-2-0-1/SOURCE.json` i `PACKAGE.json`. Sam ten wpis
nie jest potwierdzeniem ukończenia pakowania. Wcześniejsze zakazy budowania
dotyczą etapu sprzed najnowszego polecenia, nie wydania 2.0.1.

## Redakcja zasad wszystkich gier — ukończona w źródłach, 18 września 2026

Poprzednie 12 punktów wdrożono i zweryfikowano (POST_228_IMPLEMENTATION).
Następnie przepisano zasady 23 gier w PL/EN: 360 par akapitów, z przykładami,
wyjaśnieniem pojęć i wariantów według kodu. Źródła zewnętrzne porównano,
nie kopiowano ani nie zmieniano reguł silników. Lista skrótów pod strzałkami
w aktywnej grze korzysta ze wspólnych definicji F1 pola gry; biblioteka
zachowuje pełną instrukcję obsługi. Zasady to jeden dokument z nagłówkami,
obok skróty, przy stole także aktualne ustawienia. Raport i źródła:
`docs/RULES_REWRITE_REVIEW.md`, status: `docs/RULES_REWRITE_PROGRESS.md`.
15/15 końcowych skryptów celowanych, 63 Ruby ze sprawdzoną składnią,
207 symulowanych okien z binarnymi źródłami i rzeczywistym słownikiem hosta,
PL/EN/fallback. Bez pełnego runnera i żywych klientów. 2.0/228 i changelog
bez zmian; NIE budowano, podpisywano, instalowano, publikowano ani zmieniano
serwera/GitHuba. Podpisana 228 nie zawiera obu nowych etapów.

Przy kolejnych zmianach zasad edytować pary PL/EN w `docs/rulebooks/*.json`,
następnie uruchomić `tools/compile-rulebooks.rb`. Nie edytować wyłącznie
wygenerowanego `rule_sections`. Wspólne akapity mają tłumaczenia w
`locale/rules-shared-pl.json`. Nowa opcja wymaga wyjaśnienia i wpisu
w `docs/RULEBOOK_OPTION_COVERAGE.json`; indeks nie zastępuje sprawdzenia
znaczenia w kodzie. Zachować lokalne warianty i informować o różnicach
wobec źródeł. Nowe skróty przypinać do rzeczywistych kontrolek, bez drugiej
kopii aktualnej pomocy. Sprawdzać testy rulebook_authoring, rulebook_examples,
rules_live_help, rules_native_windows oraz dotychczasowe rules/encoding.
Przy przyszłym pakowaniu ponownie sprawdzić binarne wczytanie GOTOWEJ
paczki; obecne testy źródeł nie są dowodem jej zbudowania.

## Wdrożenie poprawek po 228 — 18 września 2026

Użytkownik polecił wdrożyć do kodu `docs/POST_228_FIXES_PLAN.md` (12 punktów).
Potwierdził Shift+C/Shift+H/Shift+M dla sortowania, z zachowaniem UNO/Rummy
i istniejącego Shift+C Biblios. Starszy status „tylko plan” poniżej opisuje
etap zbierania wymagań. Testy celowane, bez pełnego runnera; nie budować,
nie podpisywać, nie instalować ani nie publikować na podstawie tego polecenia.
Nie zmieniać serwera, numeru wersji i changelogu. Postęp i wyniki:
`docs/POST_228_IMPLEMENTATION.md`. Nie oznaczać niewykonanych prób jako
zaliczonych; podpisana paczka 228 nie zawiera tych nowych zmian.

## Kolejne poprawki po 228 — tylko plan, 18 września 2026

Bieżący zbiór nowych ustaleń: `docs/POST_228_FIXES_PLAN.md`.
Punkt 1 po doprecyzowaniu: sprawdzić potrzebę lokalnego zapisu odbiorów
powiadomień o nowych stołach; usunąć zbędny zapis albo przenieść potrzebny
do tła. Zmierzyć wpływ na opóźnienia komunikatu i blokowanie UI, zachować
filtry i obsługę dołączenia. Osobno ocenić seen/resolved i mechanizmy hosta:
restart ani dołączenie nie tworzy nowego powiadomienia, a sprzątanie listy
nie dowodzi konieczności zapisu każdego odbioru. Osobne pomiary etapów
odbioru. Próba syntetyczna wykazała blokującą ścieżkę, nie dowiodła
przyczyny rzeczywistego dwusekundowego incydentu. Użytkownik na razie
polecił tylko zapisać poprawkę i będzie dodawał kolejne. Bez implementacji,
nowego wydania, instalacji, publikacji i zmian serwera; czekać na polecenie.
Wydana 2.0/build 228 pozostaje aktualna i niezmieniona.
Punkt 2 tego samego planu: krótkie powiadomienie w kolejności właściciel,
gra, typ, np. „Papierek, Yahtzee, typ, nowy stół”, bez podwójnego „Nowy stół”.
Host łączy obecny tytuł z treścią zawierającą ten sam prefiks — potwierdzone
w kodzie. Sprawdzić odczyt i listę, etykietę typu, PL/EN i kodowanie;
nie zmieniać innych powiadomień ani działania dołączenia. Nadal tylko plan.
Punkt 3: wspólny wybór języka (zgłoszenie Quiz/Taboo) bez przeskoku fokusu
na zestaw. Strzałki nadal przeglądają języki; zestawy aktualizowane bez
zmiany fokusu, przejście ręcznie Tabem. Zachować inne opcje i ich walidację,
obsłużyć także Ctrl+X. Kod obecnie wymusza SET_OPTION_KEY po zmianie języka,
a test game_option_form_test tego oczekuje — oba do późniejszej zmiany.
Szczegóły i przyszłe testy w planie, bez wdrażania na obecnym etapie.
Punkt 4: uzupełnić F1 Makao o Shift+Enter (dodaj/usuń kartę z paczki),
bez drugiego handlera i niepoprawnego opisu dla wymiany w Pokerze.
Punkt 5: wspólne sortowanie własnej ręki; klawisze dopiero proponowane:
Shift+C kolor, Shift+H ranga z przełączaniem kierunku, Shift+M kolejność
otrzymania. Nie nadpisywać UNO/Rummy Shift+D ani Biblios Shift+C.
Zachować fizyczne ID, kursor i kolejność paczek/układów; bez zmian sieci
i reguł. PacketCardSurface nie obsługuje jeszcze sort_cards. Tylko plan;
nie traktować proponowanych klawiszy jako uzgodnionych.
Punkt 6: mieszane PL/EN w obu sekcjach pomocy Taboo. Bieżący PL.mo zawiera
tłumaczenia wszystkich 12 tekstów rule_sections; izolowany odczyt źródła
ich nie gubi. Sprawdzić rzeczywistą paczkę, wybór katalogu/kluczy i wspólne
akapity pomocy, bez zgadywania przyczyny. Docelowo oba dokumenty w języku
interfejsu niezależnie od języka kart. Szczegóły w planie; bez implementacji.
Punkt 7: zachować nakładanie niezależnych dźwięków. Wspólny mechanizm już
przekazuje wiele efektów, lecz ninety_nine_cue wybiera jeden specjalny
przez if/elsif. Potwierdzono brak reverse waleta przy 25 → 35 i 60 → 70:
draw2 zastępuje efekt karty. Zbierać skutki niezależnie, sprawdzić podobne
przypadki innych gier, bez pauz/uciszania, z zachowaniem głośności i ochrony
przed powtórzeniem tego samego zdarzenia. Nadal tylko plan, bez zmian kodu.
Punkt 8: dźwięk farkle_bank.ogg po zaakceptowanym odłożeniu punktów (bank),
nie zapis partii. Plik źródłowy ma faktycznie nazwę Dokumenty/freesound/
farkle)bank.ogg; przy wdrożeniu skopiować jako Audio/farkle_bank.ogg.
Zachować równoczesny dźwięk wyniku i ustawienia głośności. Tylko plan;
nie kopiowano pliku, nie zmieniano kodu ani paczki.
Punkt 9: ninety3366.ogg z Dokumenty/freesound przy trafieniu dokładnie
w 33/66 w grze 99. Powiązać z istniejącą regułą wzrostu do progu, nie
przeskoczeniem, spadkiem ani pozostawieniem sumy. Zachować nakładanie
efektów i głośności; plik potwierdzony, szczegóły w planie. Bez wdrażania.
Punkt 10: zastąpić wspólny dźwięk wygranej całej partii win2 plikiem
Dokumenty/freesound/win_party.ogg. Nie dodawać go obok starego, zachować
wygrane/przegrane rund win1/lose1, drużyny i ustawienia głośności.
Plik potwierdzony, szczegóły w planie; bez kopiowania i wdrażania.
Punkt 11: analogicznie zastąpić wspólny dźwięk przegranej całej partii
lose3 plikiem Dokumenty/freesound/lose_party.ogg, bez dwóch efektów
przegranej. Zachować lose1 dla rund, wynik drużyny, głośność i nakładanie
z ruchem. Doprecyzowanie: lose_party już przy trwałej eliminacji gracza
lub drużyny z partii, bez ponowienia na końcu tej samej partii ani przy
odświeżeniu. Nie mylić z odpadnięciem tylko z rundy (UNO No Mercy),
pasowaniem czy rozłączeniem; przy końcu partii respektować ostatecznych
zwycięzców/remis. Samo zastąpienie pliku w result_cue nie wystarczy,
bo dziś wymaga finished?. Plik potwierdzony, szczegóły w planie; bez
kopiowania i wdrażania.
Punkt 12: 1000_mariage.ogg z Dokumenty/freesound przy skutecznym mariażu
w Tysiącu, własnym/cudzym i bota, słyszalny u uczestników i obserwatorów.
Powiązać z zaakceptowanym play w trybie marriage, nie zwykłym królem/damą
ani odrzuconą próbą. Zachować równoczesne efekty, głośność i deduplikację.
Plik potwierdzony, szczegóły w planie; bez kopiowania i wdrażania.

## Build 228 — kodowanie ustawień, 17 września 2026

Użytkownik polecił zbudować i podpisać 2.0/build 228, kopiując cały changelog
227 i dopisując tylko poprawkę kodowania w PL/EN. Następnie, po pozytywnej
weryfikacji gotowej paczki, wysłać źródła na GitHub. Bez instalacji
i publikacji na ELTEN-ie; poprzednią paczkę 227 pozostawić bez zmian.
Naprawa wspólnych OptionDefinition/OptionChoice normalizuje etykiety
do UTF-8. Brak tłumaczenia angielskiej etykiety z myślnikiem pozostawiał
ASCII-8BIT; rosyjski opis stanu CheckBox wywoływał wyjątek. Nie zmieniać
reguł Reversi, wartości opcji ani globalnych kontrolek/gettext hosta.
Źródłowe testy regresji objęły 23 gry, 72 formularze i 276 stanów pól;
dodatkowo sprawdzono rzeczywisty kod CheckBox. Dotychczasowa paczka 227
odtwarza błąd. Nową sprawdzić również przez
`test/game_option_encoding_test.rb PACZKA`, kontrolę podpisu i zgodności
źródeł. Tylko testy celowane, bez pełnego runnera. Raport przygotowania
i wynik końcowy poza repo: `../diagnostics/option-encoding-228/`.
Poniższe wpisy 227 opisują poprzednie etapy, nie bieżący numer wydania.

## Komunikaty dodania/usunięcia nazwanych botów — 17 września 2026

Po ręcznym zgłoszeniu stwierdzono, że poprzednia paczka z imionami nadal
zapisywała bezimienne zdarzenie „dodano komputer”. Poprawiono wspólną
historię i odczyt: „Dodano Maślana.” / „Usunięto Maślana.”, bez słowa
„komputer” i dodatkowego wskazania dodającego w komunikacie stołu.
Globalne lobby zachowuje właściciela/rodzaj gry. Zdarzenie przechowuje
stabilne ID bota w istniejącym polu message; nie odtwarzać imienia
z bieżącego numeru miejsca, zwłaszcza po usunięciu innego bota.
Bez nowych kolumn, dodatkowych żądań i ujawniania prywatnych stołów.
Nie tworzyć migracji starych historii. Użytkownik polecił ponownie
przebudować i podpisać 2.0/build 227 z tym samym changelogiem. Wyniki
celowanych testów i kontrola artefaktu: ../diagnostics/bot-name-activity-227/.
Nie instalować i nie publikować. Starsze opisy dotyczą poprzednich paczek.

## Imiona botów i zgoda na przebudowanie 227 — 17 września 2026

Użytkownik przekazał listy 24 PL i 26 EN oraz polecił po tej zmianie
przebudować i podpisać ponownie 2.0/build 227. To zastępuje wcześniejsze
wstrzymanie pakowania. Changelog zachować, z punktami Biblios i imion botów
w PL/EN. Imię wybierane przy dodaniu, według interfejsu dodającego; bez
powtórzeń przy stole i ponownego losowania przy odświeżaniu. Wszyscy
widzą to samo imię, także po zapisaniu i wznowieniu nowej partii.
Użytkownik potwierdził brak starych zapisów: nie dorabiać ich migracji.
Stałych kodów imion w lib/bot_names.rb nie przestawiać ani nie używać
ponownie dla innych imion. Nowe pokoje używają discovery protocol 5,
aby starszy klient nie uznał nazwanego bota za człowieka. Bez zmian tabel
serwera. Testy celowane; punkt wznowienia: docs/POST_227_IMPLEMENTATION.md,
wyniki poza repo w ../diagnostics/bot-names-227/. Nie instalować ani
publikować; GitHub i rzeczywiste klienty bez zmian.

## Scrabble, Mexican Train i Biblios wdrożone; paczka wstrzymana — 17 września 2026

Na polecenie użytkownika wdrożono POST_227_GAME_CHANGES_PLAN w źródłach:
Scrabble Enter/lista/Enter, Backspace pod kursorem, cyfry tylko czytają,
bez H/V/N i skrótów układających litery; Mexican Train pokazuje wszystkie
pociągi, wyjaśnia odmowę, Z/Shift+Z tylko wskazuje legalne kostki.
Biblios z PR #7 dawidpieper zintegrowano lokalnie, bez scalania na GitHubie.
Naprawiono obsługę zdarzeń, duże płatności, prywatność i heurystyki bota,
dodano PL oraz dźwięki. Użytkownik wyraźnie polecił zachować talię i wariant
PR: 87 kart, w tym 45 kategorii/18 złota/24 kościelne. Nie zastępować ich
składem pudełkowej edycji. Rejestr ma 23 gry.

25/25 celowanych skryptów, składnia 37 Ruby, diff check i binarne wczytanie
bieżących źródeł z API tasowania hosta poprawne. Bez pełnego runnera
i ręcznych partii rzeczywistych klientów. Numery 2.0/227 bez zmian;
changelog PL/EN ma jeden dodatkowy punkt Biblios, pozostałe zachowane.
Raport: `docs/POST_227_VERIFICATION.md`; punkt wznowienia:
`docs/POST_227_IMPLEMENTATION.md`. Logi poza repo:
`../diagnostics/post-227-plan/`.

**Najnowsze polecenie wstrzymuje pakowanie i podpisywanie:** użytkownik
zapowiedział jeszcze jedną poprawkę. Czekać na nią i nowe polecenie
budowania. Nie instalować, nie publikować, nie zmieniać serwera.
Dotychczasowa paczka 227 c8dd0b8c… niezmieniona i nie zawiera tych zmian
ani wcześniejszych niewydanych poprawek Rummy. Starsze wpisy „tylko plan”
poniżej są historyczne; źródła wdrożone, wydanie nadal wstrzymane.

## Kolejny plan Scrabble, Mexican Train i Biblios — 17 września 2026

Użytkownik zaakceptował uproszczenie Scrabble (Enter/lista/Enter, Backspace
pod kursorem, 1–7 odczyt, bez formularza słowa, menu i H/V/N) oraz Mexican
Train: lista wszystkich pociągów, także zamkniętych, wyjaśnienia odmowy,
pierwszeństwo obowiązku dubletu. Z/Shift+Z tylko wskazuje legalne kostki,
bez automatycznego ruchu. Nowy PR dawidpieper #7 dodaje Biblios, bota,
zasady i testy; tłumaczenia PL do uzupełnienia. Head eee45867b29b9926026499159301cc3e4e038d88.
Pełny zakres: `docs/POST_227_GAME_CHANGES_PLAN.md`. To tylko plan;
PR otwarty, niescalony, bez pełnego audytu/testów. Nie wdrażać, nie budować,
nie podpisywać ani publikować bez kolejnego polecenia. Zachować wszystkie
wcześniejsze niewydane poprawki oraz istniejącą paczkę 2.0/227 bez zmian.

## Naprawy audytu interfejsu i przełącznik stron Domino — 17 września 2026

Użytkownik doprecyzował G/D jako zapamiętany wybór strony, a następnie
polecił „i popraw od razu resztę”. Osiem punktów poprzedniego audytu
obsłużono w źródłach. Domino: G lewo/D prawo bez ruchu; Enter przy obu
końcach używa preferencji bez pytania, przy jednym gra legalnie bez zmiany
preferencji. Domyślnie prawo. Stan lokalny zachowany po odświeżeniu,
podglądzie, odtworzeniu kontrolki i między rozdaniami. Z bez zmiany.
Mexican Train nadal ma wybór pociągu. Oba podglądy używają ID kostek/
pociągów; nowa runda zamyka stary podgląd. C/V nie blokuje wybór celu:
zostaje bezpiecznie anulowany. Nie czytać ukrytej ręki; Escape z wyboru
czyta samą kostkę. Scrabble: Backspace wraca na pole usuniętej płytki,
pusty szkic prosi o co najmniej jedną płytkę, a nie dwie nowe litery.
Zasady, boty i zdarzenia bez zmian. PL/EN, pomoc i projekt uaktualnione.
16/16 celowanych skryptów przeszło, w tym 15 nowych scenariuszy oraz
binarne ładowanie bieżących źródeł pod symulowanym API hosta. Bez pełnego
runnera, żywych klientów, serwera, wersji/changelogu i pakowania. Raport:
`docs/NEW_GAMES_INTERACTION_AUDIT_227.md`; wyniki poza repo w
`diagnostics/new-games-interaction-fixes-227/`. Paczka 2.0/227 o SHA
c8dd0b8c… nadal nie zawiera tych zmian ani wcześniejszych poprawek Rummy.
Nie budować/podpisywać/instalować/publikować bez nowego polecenia.

## Rummy i audyt interfejsu nowych gier — 17 września 2026

Nowsze niż paczka c8dd0b8c…: poprawiono źródła Rummy, D jako odczyt bez
listy, Shift+D bez dodatkowego Entera przy jednej legalnej możliwości,
widoczność tylko wierzchniej karty w single discard. Naprawiono również
menu, utrzymywanie wyborów po odświeżeniu, kursor i odczyty oraz publiczne
komunikaty; polskie tłumaczenia i zasady uaktualnione. Nie zmieniać stosu
potrzebnego do recyklingu tylko po to, żeby ukryć starsze odrzuty.
23 nowe scenariusze Rummy i łącznie 19 celowanych skryptów przechodzą.

Na dodatkowe polecenie „poszukaj” zbadano Domino, Mexican Train, Scrabble
i Taboo. Osiem nowych problemów UI/komunikatów odtworzono w diagnostyce;
NIE wdrażano ich napraw bez polecenia. Osobno użytkownik polecił skrócić
Mexican Train: C ma nagłówek „Pociągi”, bez stacji, a wiersze i wybory
celów np. „papierek, 9, otwarty”, bez słowa „koniec”. Wdrożono PL/EN,
bez zmian stacji w regułach i szczegółach; dublety i otwartość zachowane.
Taboo bez nowego potwierdzonego
błędu w zbadanych scenariuszach. Szczegóły, przyczyny, propozycje i zakres:
`docs/NEW_GAMES_INTERACTION_AUDIT_227.md`. Nie ogłaszać gwarancji bezbłędności.
Bez pełnego runnera, żywych klientów, wersji, changelogu, serwera, nowej
paczki, instalacji i publikacji. Podpisana 2.0/227 z c8dd0b8c… NIE zawiera
tych najnowszych poprawek Rummy ani opisów Mexican Train. Nie przebudowywać
bez nowego polecenia.

## Tasowanie i powrót na widget — źródła po 227, 17 września 2026

Naprawiono wywołania `Array#shuffle(random: ...)` w rozdaniu i wymianie
liter Scrabble oraz dobieraniu nowej talii Taboo. Wspólny
`GameRoomRandom.shuffle(values, random: rng)` działa bez nadpisanego przez
ELTEN-a Array#shuffle i zachowuje dotychczasową kolejność oraz stan RNG.
Test z zerową liczbą argumentów hosta odtwarzał błąd także z ostatniej
podpisanej paczki. Obowiązkowa reguła zgodności tasowania jest niżej.

Na kolejne zgłoszenie porównano widget ze źródłem sprzed zmian (HEAD,
build 226). Przywrócono kolejność przy wejściu: zadanie ELTEN-a pobiera
listę, dopiero potem natywny fokus ją odczytuje. Strzałki nie pobierają;
co 5 sekund tylko na aktywnym widgecie nadal działa cicha operacja w tle.
Wynik rozpoczęty przed ponownym wejściem nie nadpisuje nowszej listy.
Żądania są szeregowane; błąd wejścia nie odczytuje starego stołu.
Użytkownik następnie polecił przebudować i podpisać ponownie 2.0/build 227,
bez zmiany changelogu. Wynik kontroli gotowego artefaktu, jego SHA i rozmiar:
`../diagnostics/shuffle-widget-entry-227/PACKAGE.json`. Poprzednia paczka
z SHA f5097d11… nie zawiera tych poprawek i jest zachowywana osobno.
Nie instalować ani nie publikować bez nowego polecenia.

## Powiadomienia i widget po 227 — 17 września 2026

Naprawiono odrzucanie prawdziwych tokenów LiveSessions przez filtr UUID
powiadomień o nowych stołach. Zamiast pustego tekstu niedostępne ogłoszenie
ma wyciszoną treść zastępczą. Widget rozróżnia wczytywanie, brak wyników
i błąd; ogłasza pierwszy wynik na aktywnej pustej liście, zachowując ciszę
odświeżenia okresowego i bieżący kursor. Regresje najpierw odtworzyły błędy.
Szczegóły: `docs/NOTIFICATIONS_WIDGET_227_FIXES.md`. Użytkownik polecił
podpisać ponownie ten sam build 227, bez zmiany changelogu. Wyniki paczki
i testów: `../diagnostics/table-notice-widget-227/`. Jedna osobno zatwierdzona
próba powiadomienia na obu kontach została sprzątnięta; schemat, preferencje,
inne powiadomienia i zainstalowany program niezmienione. Nie instalować
ani nie publikować bez nowego polecenia.

## Poprawki po ręcznym teście 227 — 17 września 2026

W źródłach naprawiono brak odczytywania publicznych ruchów pięciu nowych
gier oraz wyjątek UTF-8/ASCII-8BIT w Mexican Train i wspólnych nazwach
kostek. Dodatkowy przegląd, zakres i ograniczenia: `docs/NEW_GAMES_227_FIXES.md`.
24 skrypty celowane, składnia 12 Ruby i diff check przeszły. Nie użyto
pełnego runnera ani rzeczywistych klientów. Moduł publicznych ogłoszeń jest
opt-in; nie włączać go dla historii zawierających prywatne dane gracza.
Wersja nadal 2.0/227. Następnie użytkownik polecił przebudować i podpisać
ten sam build z tym samym changelogiem oraz sprawdzić schemat serwera
i ustawić protected false. Wynik gotowej paczki i kontroli serwera:
`../diagnostics/new-games-227-postrelease/`. Bez instalacji i publikacji.

## Źródła 2.0/build 227 — trzy plany wdrożone, 17 września 2026

Scrabble (PL SJP/EN Wordnik, bez botów), Taboo (500 kart PL i 500 EN,
bez botów, zewnętrzna rozmowa) i siedem punktów NEXT_FIXES_PLAN wdrożono.
Zachowano Rummy, Domino, Mexican Train i poprzednie poprawki wspólne.
Farkle kończy bieżący obieg po limicie, stare zapisy mają starą regułę;
boty oceniają lidera i pozostałe tury bez zwiększania budżetu wyszukiwania.
Ctrl+X edytuje następną partię, Ctrl+Q trwale przerywa konkretną bieżącą,
bez zamknięcia stołu. Nowe pokoje mają discovery protocol 4 i wymagają 2.0.
Master-obserwator rozpoznawany niezależnie od pierwszego grającego miejsca;
Taboo nadal sprawdza rzeczywistego autora decyzji moderatora.

Changelog EN/PL: `docs/CHANGELOG_2_0.md`, 14 punktów pod jednym nagłówkiem.
Kontrola: `docs/RELEASE_2_0_VERIFICATION.md`, punkt wznowienia:
`docs/RELEASE_2_0_PROGRESS.md`. 48 celowanych skryptów, składnia 98 Ruby,
git diff --check i binarne wczytanie źródeł poprawne. Bez pełnego runnera
i ręcznych partii na rzeczywistych klientach. Wyniki gotowej podpisanej
paczki są zapisywane poza repo w `diagnostics/release-2-0/` obok projektu.
Nie instalowano ani nie publikowano. Starsze akapity „tylko plan” oraz
„wydanie wstrzymane” poniżej są historią wcześniejszych ustaleń.

## Wdrożenie trzech planów i wydanie 2.0 — 17 września 2026

Użytkownik polecił wdrożyć docs/SCRABBLE_DESIGN.md, docs/TABOO_DESIGN.md
i docs/NEXT_FIXES_PLAN.md, następnie zbudować i podpisać wersję 2.0
z changelogiem PL/EN. Starsze ograniczenia planowania/wstrzymania wydania
nie blokują tego polecenia. Zachować wcześniejsze lokalne wdrożenia.
Bez instalacji ani publikacji. Bieżąca kontrola: docs/RELEASE_2_0_PROGRESS.md.
Testy celowane, bez pełnego runnera. Nie deklarować niewykonanych etapów.

## Trzeci plan poprawek — zbieranie wymagań, 17 września 2026

Użytkownik zapowiedział kolejny plan po Scrabble i Taboo. Punkt wznowienia:
`docs/NEXT_FIXES_PLAN.md`. Nowe punkty: D odczytuje kości; Yahtzee V/Shift+V
otwiera własną/cudzą kartę punktacji; gry alfabetycznie według lokalizowanych
nazw; nazwa „99”, z zachowaniem ID `ninety_nine` i zapisów.
D już działa w Farkle. Użytkownik potwierdził dodanie odczytu w Yahtzee
i Chińczyku, zachowanie w Farkle i pozostawienie Monopoly bez zmian
(D oznacza tam niekupione nieruchomości).
Użytkownik zatwierdził PR #6 dawidpieper jako punkt 5 planu wraz
z dostosowaniem botów i tłumaczeniami. Dokończenie bieżącego obiegu
po osiągnięciu limitu, najwyższy wynik/remis, nie dodatkowa tura każdego.
Bot ma oceniać lidera i pozostałe tury; sam limit nie oznacza wygranej.
Poprawić strategię, pomocnicze oceny i pamięć wyników bez istotnego
zwiększania kosztu. Uzupełnić tłumaczenia PL i zgodne zasady EN.
Szczegóły, commit, przyszłe testy i zgodność zapisów w planie.
Wyłącznie akceptacja planu: PR niescalony, kod/boty/tłumaczenia nadal
niezmienione, bez testów gry. Czekać na osobne polecenie wdrożenia.
Punkty 6–7 w planie: Ctrl+X edytuje aktualne ustawienia dla następnej
partii, tylko master i poza aktywną grą. W polach tekstu nadal wycinanie.
Ctrl+Shift+X/zmiana gry poza zakresem. Ctrl+Q przerywa obecną partię
przez mastera, bez zamknięcia stołu, wyrzucania ludzi czy fikcyjnego wyniku.
Trwała, wspólna granica dla ID partii blokuje późniejsze ruchy, timeouty
i wyniki botów; wszyscy wracają do oczekiwania. Potem można zmienić
opcje i ręcznie zacząć od nowa w tej samej LiveSession. Krótkie pytanie
potwierdzające Ctrl+Q jest propozycją zabezpieczenia. Nie utożsamiać
tego z odwracalnym zamrożeniem Ctrl+S. Zachować czat, role i boty;
sam status stołu nie wystarczy. Szczegóły i przyszłe testy w planie.
Nadal tylko dokumentacja, bez zmian kodu, testów gry i wydania.
Nie zgadywać dalszego zakresu ani nie przywracać starych pomysłów.
Nie mylić go z już wdrożonym planem widgetu/powiadomień/Reversi/botów.
Tylko planowanie, bez kodu funkcji, serwera, testów gry i wydania.

## Taboo — plan gotowy do wdrożenia, 17 września 2026

Patrz `docs/TABOO_DESIGN.md`. Wyłącznie gra głosowa przez zewnętrzną
rozmowę/konferencję lub na żywo ze słuchawkami. Użytkownik potwierdził
4/6/8 ludzi i dwie równe drużyny, talie PL/EN docelowo po 500 sprawdzonych
kart oraz zatwierdzanie rozliczenia każdej tury przez mastera z korektami.
Wymaga wzorowania kart na istniejących zestawach. Adaptacje dopiero po
kontroli pochodzenia, licencji i każdej karty; zachować autorów i źródła.
Dotychczas odczytano tylko próbki tabooo/Taboo-Data, nie pełne audyty.
Nie zaimportowano ani nie przygotowano jeszcze docelowych zestawów.
Użytkownik zatwierdził następnie cały plan jako gotowy do wdrożenia.
Obejmuje to dźwięki: buzzer2 na brzęczyk, shuffle na start tury, replay na odgadnięcie, skip na
pominięcie, ding na koniec czasu, win2/lose3 na wynik całej partii według
drużyny. Bez sygnału każdej nowej karty i tykania zegara. Plan gotowy, ale
gra, talie i ich testy jeszcze niewykonane. Nie obiecywać rozpoznawania
mowy czy integracji konferencji.
Karta Taboo nie jest ręką karcianki: bez automatycznego Z i jej kursora.
Oznaczenie planu jako gotowego nie jest poleceniem implementacji.
Teraz użytkownik chce przygotować trzeci plan kolejnych poprawek.
Ten krok wyłącznie dokumentacyjny, bez testów gry, serwera, kodu funkcji,
zmiany wersji 1.1.10/226, paczki i publikacji. Scrabble nadal osobnym planem.

## Scrabble — zaakceptowany plan, bez wdrażania, 17 września 2026

Patrz `docs/SCRABBLE_DESIGN.md`. Użytkownik zaakceptował projekt po
usunięciu botów i wyborze PL/EN: jedna gra, 2–4 graczy, pierwszy wybór
języka w ustawieniach stołu, niezależny od języka interfejsu. Wykorzystać
profile content/languages.rb i dane content, nie duplikować silnika.
Akceptacja planu nie jest poleceniem wdrożenia. Solo i 5–8 osób poza zakresem.

Sprawdzono na jego polecenie końcowe rozliczenie PFS: odjąć wartości
stojaków, przy wyjściu dodać ich sumę kończącemu, przy blokadzie bez premii,
blank 0. Nie zmieniać innych reguł QC przy okazji tej korekty; remisy
wspólne są wyborem naszego planu, nie potwierdzeniem reguły QC.
Nowa rekomendacja EN po badaniu to otwarta lista Wordnika na MIT
2021-07-29: 198 422 wpisy, 194 152 po filtrze 2–15 liter. Dokument zawiera
źródło, commit, SHA i ograniczenia (nie NWL/Collins/QC, brak części form
brytyjskich). W pamięci sprawdzono strukturę całości i próbkę, nie pełną
merytorykę; nie dodano danych do gry. Porównany starszy ENABLE2K ma
braki m.in. qi/za/blog. Wordnik pozostaje rekomendacją, nie osobno
zatwierdzonym wyborem. Polski SJP nie jest OSPS; całej listy PL jeszcze
nie pobrano. Nie testowano żywego QC. Poprzednie cztery plany ukończone,
wydanie wstrzymane. Ten krok tylko dokumentacja; bez kodu gry, serwera,
testów gry, zmiany wersji 1.1.10/226, paczki i publikacji.

## Cztery plany wdrożone lokalnie — 17 września 2026

Dokończono Rummy, poprawki wspólne, Domino i Mexican Train. 48/48
celowanych skryptów, składnia 53 Ruby i git diff --check przeszły;
bez pełnego runnera. Kontrola punkt po punkcie i granice testów:
`docs/IMPLEMENTATION_2_0_VERIFICATION.md`. Bieżący punkt wznowienia:
`docs/IMPLEMENTATION_2_0.md`. Próba preferencji/powiadomienia na dwóch
kontach jest zakończona, dane testowe usunięte, nowa pusta tabela
`table_watch_preferences` pozostaje. Nie testowano jeszcze ręcznie
rozgrywki nowych gier na dwóch rzeczywistych klientach.
Użytkownik chce najpierw dodać następne gry. Wersja/manifest/changelog
pozostają 1.1.10/build 226, poprzednia podpisana paczka ma niezmieniony
hash. Nie budować, nie podpisywać, nie instalować ani nie publikować
bez nowego polecenia; nie zgadywać kolejnych gier. Starsze ograniczenia
„tylko plan” niżej są historią, nie powodem do cofania wdrożenia.

## Wydanie wstrzymane — najnowsza decyzja, 17 września 2026

Użytkownik polecił jeszcze nie budować nowego buildu, ponieważ chce dodać
kolejne gry. Doprecyzował: dokończyć obecne cztery plany i ich weryfikację,
a wstrzymać tylko zmianę wersji, budowanie i podpisywanie. Wersja pozostaje
1.1.10/build 226, bez instalacji i publikacji. Zakres kolejnych gier poda
użytkownik. Punkt wznowienia: docs/IMPLEMENTATION_2_0.md.

## Wdrożenie wersji 2.0 — bieżące polecenie, 17 września 2026

Użytkownik zatwierdził wdrożenie czterech planów, kolejno: Rummy,
SAVES_WIDGET_NOTIFICATIONS_PLAN (cztery punkty bez chmury), Domino,
Mexican Train. Następnie zbudować i podpisać wersję 2.0, bez instalacji
i publikacji. Starsze zapisy „bez wdrażania” poniżej są historyczne.
Stan prac i lista kontroli: docs/IMPLEMENTATION_2_0.md. Nie oznaczać
niezakończonych funkcji/testów jako ukończonych.


## Reversi — warianty zapisane w planie, 17 września 2026

Punkt 4 `docs/SAVES_WIDGET_NOTIFICATIONS_PLAN.md`: Allow passing oraz
Mandatory capture, oba domyślnie zaznaczone według opisu użytkownika.
Pierwsze dopuszcza dobrowolny pas mimo ruchu; wyłączenie nie blokuje
przymusowego pasa przy jego braku. Drugie wymaga odwrócenia pionka;
wyłączone pozwala postawić bez bicia, ale tylko obok istniejącego pionka,
na pustym polu. Plan przyjmuje osiem kierunków i dowolny kolor sąsiada;
nie jest to osobno sprawdzona reguła QC. Możliwe bicie nadal odwraca pionki.
Uwzględnić oba warianty w całym planerze bota, legalności, ocenie pozycji,
kluczach pamięci, replayu i zakończeniu gry. Stare archiwa bez opcji muszą
zachować poprzednie zasady. Użytkownik rozstrzygnął: P pomija własną turę,
gdy pas jest dozwolony, bez limitu kolejnych własnych tur. Dwa i więcej
dobrowolnych pasów nie kończą partii przy nadal legalnych postawieniach.
Rzeczywisty brak postawień u obu graczy nadal kończy grę. Zabezpieczenie
planera przed cyklami nie może wprowadzać remisu ani limitu pasów do zasad.
P nie przechwytuje czatu i nie pozwala pomijać tury przeciwnika.
Zmiany tylko w dokumentacji, bez kodu, testów gry, serwera i wydania.

## Opóźnienie botów — plan dla wszystkich gier, 17 września 2026

Użytkownik dopisał trzeci punkt do `docs/SAVES_WIDGET_NOTIFICATIONS_PLAN.md`:
wspólne opóźnienie bota 0–5 sekund we wszystkich grach z botami, również
przyszłych. 0 wyłącza celową pauzę, nie bota. UNO/Makao domyślnie 1;
dla pozostałych 0 zapisano jako propozycję. Zachować istniejące wartości,
uwzględnić thinking time i wyjątki faz. Wspólna definicja i planowanie,
bez blokowania UI, synchronizacji, reakcji ludzi i bez dodatkowych żądań.
Nie zmieniać strategii ani budżetu obliczeń. Obecny szkielet już planuje
oczekiwanie, ale UNO/Makao mają własne minimum 1 także przy wykonaniu.
Nowy plan zastępuje starsze propozycje opóźnienia w projektach Rummy,
Domino i Mexican Train; pozostały zakres tych dokumentów bez zmian.
Starsze wzmianki o dwóch punktach planu widgetu/powiadomień są historyczne.
Wyłącznie dokumentacja; nie wdrażać, nie zmieniać serwera, wersji ani wydania.

## Mexican Train — projekt do uzgodnienia, 17 września 2026

Ostatnia wcześniej nienazwana gra to Mexican Train. Użytkownik przekazał
opis QC; zapisano nowy `docs/MEXICAN_TRAIN_DESIGN.md`, bez implementacji.
Domino pozostaje zakończonym planem, Rummy i widget/powiadomienia bez zmian.
Nie zmieniać serwera, limitów, wersji ani nie budować/podpisywać/publikować.

Oddzielić reguły Mexican Train od Domino: stacja Double 12 schodzi co
rozdanie do 0 i wraca do 12; osobiste i publiczny pociąg; dodatkowe ruchy
po dubletach, stos obowiązków zamykania od ostatniego; ostatni dublet
kończy rozdanie, 0–0 zawsze daje 10. Nie przenosić automatycznie 11 zestawów,
drużyn ani opcji dobierania. Można współdzielić neutralne elementy kostek
i ręki przy przyszłym wdrożeniu, nie udawać gotowej implementacji Domino.
Interfejs, bot i 2–8 osób są propozycjami w dokumencie.
Użytkownik doprecyzował rozdanie: 2–5 osób po 15, 6–7 po 12, 8 po 10.
„17 graczy” odczytano jawnie jako literówkę „i 7”, bez osobnego
potwierdzenia i bez zmiany limitu 8. Pojemność z jedną stacją sprawdzono;
tabela w projekcie podaje pozostałości stosu dla 2–8 osób. Brakuje
startera i części wyjątków kontynuacji dubletów; nie przedstawiać
propozycji jako potwierdzonych reguł QC.
Użytkownik zatwierdził: we własnej serii wolno zamknąć starszy dublet,
zostawiając nowszy; następni zamykają pozostałe od ostatniego. Usunąć
z listy obowiązków konkretny zamknięty dublet, nie zawsze ostatni.
Pusty stos i brak ruchu otwierają własny pociąg z automatycznym pasem.
Limit punktów domyślnie 100, dodatkowa opcja dobierania mimo legalnej
kostki domyślnie wyłączona. Nie kopiować innych wariantów Domino.
Następstwo dobrowolnego dobrania przy nadal legalnej starej kostce
oznaczono jako propozycję do doprecyzowania, nie zatwierdzoną regułę.
Zmieniono wyłącznie dokumentację; nie uruchamiano testów nieistniejącej gry.

## Domino — zakończony plan, 17 września 2026

Pierwszą z dwóch zapowiedzianych nowych gier jest Domino. Użytkownik
przekazał opis Dominos z QC; w `docs/DOMINO_DESIGN.md` zapisano reguły,
interfejs, boty i wszystkie późniejsze doprecyzowania. Użytkownik uznał
plan za zakończony i przechodzi do ostatniej gry, nadal nienazwanej.
Nie jest to zgoda na implementację ani powód do dalszego rozwijania teraz
Domino. Nierozstrzygniętych wyjątków nie przedstawiać jako faktów z QC.
Nie wdrażać, nie zmieniać wersji, serwera ani limitów graczy, nie budować
i nie publikować. Użytkownik następnie zatwierdził pozostawienie limitu
8 osób, otwieranie dowolną kostką (nie tylko dubletem) oraz wygraną
najniższego łącznego wyniku przy jednoczesnym odpadnięciu wszystkich,
ze wspólnym zwycięstwem remisujących na najniższym wyniku. Nie rozszerzać
do większej liczby osób ani przywracać obowiązku otwarcia dubletem.
Zatwierdzenie tych punktów nie jest zgodą na wdrożenie.

Następnie użytkownik dodał 11 zestawów, opcje dobierania, kończenie całą
drużyną oraz thinking time i zażądał nazwy „kostki”. Po 7 w pojedynczym
Double 6 (maks. 4 osoby), w innych po 10. Na pytanie o za małe zestawy
potwierdził limit 5 osób w Double 9 i 2× Double 6, bez rozdania po 9;
pozostałe zestawy obsługują do 8 osób. Każda kostka z 2×/4× ma własne ID.
Domyślnie dobieranie mimo pasującej kostki jest włączone; zakaz, dobieranie
do skutku, drużyny i kończenie całą drużyną wyłączone. Zakaz dobierania
wyłącza i ukrywa oba zależne pola, a kończenie całą drużyną działa tylko
w drużynach. Jedno dobieranie w turze jest potwierdzone jako jedna akcja:
w trybie do skutku Spacja pobiera automatycznie do pierwszej pasującej
albo wyczerpania stosu, bez drugiej serii. Plan obejmuje blokadę mimo
niepustego stosu przy zakazie i pomijanie pustych rąk w kończeniu całą
drużyną. Wyjątki timeoutu, dobrowolnego dobrania, wybór startera w nowych
przypadkach i część UI nadal są propozycjami, nie faktami z QC.
Rummy, widget i powiadomienia pozostają odrębnymi, niezmienionymi planami.

Całe dobieranie do skutku ma być jednym krótkim zdarzeniem i jednym
zapisem ruchu, nie żądaniem dla każdej kostki. Klienci odtwarzają serię
lokalnie z ustalonego stosu. Standardowe odczyty/ponowienia transportu
pozostają, bez mnożenia żądań przez długość serii. Zaplanowano test
liczby wywołań i braku podwójnego dobrania, również dla zestawu 364 kostek.

Użytkownik doprecyzował, że dobieranie drużyn ma wykorzystywać istniejący
wspólny ekran ze Spades, nie nowy formularz. Potwierdzono ogólny
`GameRoomTeams::Assignment` oraz `configure_team_assignment`: automatyczny
skład, ręczna zmiana ludzi/botów i kontrola liczebności. Domino określa
własne dopuszczalne konfiguracje i przeplataną kolejność tur także po
ręcznym przydziale; nie kopiować ograniczeń ani punktowania Spades.
To uzupełnienie dokumentacji, bez implementacji.

## Aktualny zakres: widget i powiadomienia, 17 września 2026

Użytkownik usunął z bieżącego planu zapisy partii na serwerze. Nie wdrażać
chmury ani nie kontynuować prób magazynu; obecne lokalne zapisy, tabelę
diagnostyczną i raporty pozostawić. Projekt Rummy pozostaje bez zmian.
Plan `docs/SAVES_WIDGET_NOTIFICATIONS_PLAN.md` zawiera teraz widget
oraz dopracowany projekt powiadomień o nowych publicznych stołach.
Użytkownik zaakceptował go jako plan, w tym osobną tabelę z jednym małym
rekordem subskrypcji na konto, nadal bez zgody na implementację lub zmiany
serwera. Zapowiedział planowanie dwóch kolejnych, jeszcze nienazwanych
gier. Czekać na ich zakres; nie tworzyć kodu na podstawie tej zapowiedzi.

Aktualny kod ELTEN-a odczytany przez MCP potwierdza Apps.notify do jednego
konta, odbiór poza aktywnym oknem gry i zbiorczą listę online. Projekt:
jeden mały rekord preferencji na konto, odczyt przez klienta zakładającego
stół, lokalny wybór zainteresowanych/online i ograniczona kolejka wysłań.
To nie serwerowa subskrypcja ani jeden broadcast. Preferencje będą czytelne
dla rozsyłających klientów; starsze wersje i wyłączenie nadawcy ograniczają
dostawę. Nie odpytywać stołów okresowo w celu powiadomień i nie używać
Signals. Szczegóły, jawne propozycje i testy są w planie. Bez zmian kodu,
schematu serwera, rzeczywistych powiadomień, wersji i wydania. Historyczne
plany zapisu serwerowego poniżej nie są już bieżącym zakresem.

## Próba magazynu plików aplikacji, 17 września 2026

Na osobne polecenie sprawdzono `AppResources` dla zapisów partii.
API plików istnieje i nie podlega limitowi tekstowego pola tabeli, ale
Game Room ma `maxsize: 0`. Sztuczny plik 128 bajtów odrzucono jako HTTP 422
`apps.resources.quota_exceeded` / `App resource storage limit exceeded`.
Zwykły klient maskował tę odmowę jako `network_error`; dokładną odpowiedź
uzyskano oddzielnym klientem diagnostycznym bez globalnej zmiany transportu.
Przed i po próbach zero zasobów, zero zajętego miejsca; nic nie pozostało.
Nie zmieniano limitu, schematu, kodu funkcji ani paczki. Wariant plikowy
wymaga przydzielenia miejsca po stronie serwera, a następnie kontroli
uprawnień, pobrania i odtworzenia. Nie uznawać zera za brak ograniczeń.
Raport: `docs/SAVED_GAME_STORAGE_FEASIBILITY.md`, szczegółowy wynik poza repo
w `diagnostics/server-save-feasibility-2026-09-17/server-file-resource-results.json`.

## Próba serwerowych zapisów i sprzątanie, 17 września 2026

Użytkownik następnie zatwierdził utworzenie tabeli próbnej, testy i usunięcie
starych tabel. Jawnie potwierdził konto deweloperskie `papierek` i wykluczył
kopię usuwanych danych. Usunięto `tables`, `table_members`, `game_sessions`,
`game_events`, `invitations`, `invitation_responses`; API potwierdza not_found.
Pozostają nienaruszone `game_room_users`, `table_activity` i pusta
`saved_games_capacity_probe`. Nie przywracać usuniętych tabel z dawnych notatek.
Brak kopii usuniętych rekordów. Nie dotykano lokalnych zapisów ani LiveSessions.

W próbie `string:4096` działa, `string:4097` i większe deklaracje odrzucono.
11/15 syntetycznych legalnych archiwów przeszło rzeczywisty zapis/odczyt/replay;
Spades, UNO, Farkle, Monopoly przekroczyły jedno pole. Trzy pola pomieściły
12 288 znaków w jednym rekordzie i odtworzyły Monopoly. Cztery duże pola
z metadanymi oraz 256 pól wywołują błąd wewnętrzny; nie uznawać tego za
udokumentowany globalny limit. Nie powtarzać wielkich migracji na danych.
Nieudana szeroka migracja zepsuła tylko pustą tabelę diagnostyczną; usunięto
ją i utworzono poprawnie ponownie. Wszystkie syntetyczne rekordy sprzątnięto.
Nie wdrażać jednego rekordu dla dowolnej partii na podstawie tego testu.
Raport: `docs/SAVED_GAME_STORAGE_FEASIBILITY.md`, wyniki i skrypt poza repo
w `diagnostics/server-save-feasibility-2026-09-17/`. Duża seria trafiła na
limit żądań: dokończona po przerwie, nie powtarzać bez ograniczenia tempa.
Użytkownik mówi o `protected: true/false`, nie osobnym trybie private;
serwerowe `tables_protected: false` pozostawiono bez zmian. Nie testowano
prywatności z drugiego konta. Bez zmian kodu aplikacji, wersji 226, paczek,
publikacji i wdrożenia Rummy/widgetu/powiadomień. Starsze wpisy poniżej
o braku zgody dotyczą etapu przed tym eksperymentem.

## Zapis na koncie, widget i nowe stoły — tylko plan, 17 września 2026

Trzy nowe propozycje użytkownika zapisano w
`docs/SAVES_WIDGET_NOTIFICATIONS_PLAN.md`: dostęp do zapisanych partii
z innego komputera, usunięcie pobierania widgetu przy strzałkach oraz
powiadomienia o nowych publicznych stołach wybranych gier. Dokument
rozróżnia wymagania, potwierdzoną przyczynę widgetu i propozycje wymagające
sprawdzenia możliwości serwera. To nie jest zgoda na wdrożenie ani wydanie.
Nie zmienia projektu Rummy ani obecnego działania zapisów i powiadomień.
Później użytkownik zaakceptował odświeżanie widgetu przy wejściu i pod R
oraz zapytał o cykl co 5 sekund tylko na aktywnym widgecie. W planie
opisano ten wykonalny wariant, bez odpytywania po opuszczeniu kontrolki,
z zachowaniem bieżącego kursora i bez blokowania interfejsu. Wcześniejsza
propozycja 30-sekundowej ważności danych przy wejściu jest zastąpiona.
Zapis serwerowy opisano jako prywatny rekord jednej partii z obecnym
archiwum JSON; możliwości prywatności i limitów API nadal do potwierdzenia.
Użytkownik następnie wykluczył lokalne kopie zabezpieczające: docelowy
trwały zapis wyłącznie na serwerze, bez lokalnego trybu awaryjnego.
Nie jest to zgoda na usunięcie dotychczasowych plików. W kodzie potwierdzono,
że obecne wznowienie tworzy nową LiveSession i importuje samowystarczalne
archiwum, więc nie wymaga istnienia starej sesji. Tabela ma przechowywać
zapis, nie zastępować transport bieżącej partii. Nadal tylko plan.

Na pytanie o pojemność wykonano offline pomiar archiwów wszystkich 15
obsługiwanych gier i odczyt rzeczywistego schematu przez świeżą sesję MCP.
Raport: `docs/SAVED_GAME_STORAGE_FEASIBILITY.md`; skrypt i liczby poza
repozytorium w `diagnostics/server-save-feasibility-2026-09-17/`.
15/15 próbek przeszło bezstratną kompresję, walidację i odtworzenie.
Spades 815 zdarzeń: 13 748 bajtów po zlib+Base64; UNO 801: 12 976;
Monopoly 300: 6 512. Sztuczne historie 40 880 zdarzeń: około 608–756 KB,
nie legalne pełne partie ani gwarantowana granica. Globalnego limitu
pola/wiersza/żądania nie podaje odczytany schemat ani dokumentacja klienta;
nie ogłaszać, że każda partia mieści się w jednym rekordzie. Odczytane
`tables_protected` było false mimo true w źródłowej deklaracji; nie zmieniono
tego. Ochrona pieczęcią i widoczność własnych rekordów to odrębne ustawienia.
Bez zmian kodu aplikacji, schematu, rekordów, wersji i paczki. Próba zapisu
w tabeli testowej wymaga osobnej zgody i sprawdzenia konta właściciela.

## Rummy — projekt do dalszych ustaleń, 17 września 2026

Pełny projekt pod hasłem „rummy”, wraz ze wszystkimi późniejszymi korektami
użytkownika, znajduje się w `docs/RUMMY_DESIGN.md`. To dokument planistyczny,
nie gotowa implementacja. Użytkownik nadal zgłasza propozycje; aktualizować
ten dokument zgodnie z kolejnymi uzgodnieniami. Sama akceptacja i zapisanie
planu nie są poleceniem wdrożenia, zmiany wersji ani wydania paczki.

## Stan bazowy

Gałąź `main` zaczyna się od opublikowanego ELTEN Game Room 1.1.0, build 176.
Nie przenoś do niej eksperymentalnych zmian z późniejszych lokalnych buildów bez
osobnego zgłoszenia i przeglądu.

## Sposób pracy

Własne okna aplikacji używają `GameRoomUI::Form` lub
`GameSurfaces::RefreshAwareForm` z referencją `program:`. Wspólny szkielet
zapewnia lokalne F1 jako tekst tylko do odczytu oraz F2/F3 i Shift+F2/F3
do głośności. Historia używa GameRoomHistory::View, a nawigacja
GameRoomHistory.bind; index/check to pozycje znaków, entry_index to wpis.
Nie dubluj tych klawiszy w klasach gier, nie zmieniaj źródeł ani zapisanych
QuickActions ELTEN-a. Dynamiczną pomoc gry i pokoju aktualizuj przez te same
definicje co rzeczywiste skróty (`GameRoomContextHelp`), nie dopisuj na stałe
tipsów zależnych od fazy. Szczegóły: `docs/VOLUME_AND_HELP_224.md`.

- Najpierw odtwórz problem i wskaż warstwę, która jest jego właścicielem.
- `Replay#state` jest opcjonalne: Kółko i krzyżyk oraz Czwórki przechowują
  pozycję w polach `board`/`players` i zwracają `state: nil`. Wspólne hooki
  nie mogą wymagać Hasha stanu; opcje partii pochodzą również z ActionContext.
  Przy ich zmianach testuj prawdziwy replay klas gier, nie tylko sztucznie
  zbudowany Hash. Regresja opóźnienia botów: `test/bot_delay_replay_test.rb`.
- Kodowanie tekstów UI sprawdzaj również w paczce: ELTEN może wczytać źródła
  jako ASCII-8BIT, a brak tłumaczenia w `_()` pozostawia taki tekst bez zmiany.
  Nawet angielska etykieta z myślnikiem „—”, znakiem „×” lub innym znakiem
  spoza ASCII może wtedy wywołać Encoding::CompatibilityError przy doklejeniu
  przez kontrolkę polskiego/rosyjskiego opisu roli lub stanu. Teksty i etykiety
  przekazywane do kontrolek oraz składane komunikaty normalizuj do UTF-8 przez
  `GameRoomContent.utf8`, przed łączeniem/formatowaniem. Nie zmieniaj ID,
  wartości opcji ani binarnych danych, nie nadpisuj globalnego gettext ani
  kontrolek ELTEN-a i nie maskuj problemu usuwaniem znaków diakrytycznych.
  Etykiety `OptionDefinition` i `OptionChoice` normalizuje wspólny szkielet;
  nowe ustawienia mają go używać. Test musi przejść przez rzeczywiste
  tworzenie formularza i odczyt fokusu/stanu, także brakujące tłumaczenie
  Game Roomu obok tłumaczenia hosta. Nie wymuszaj UTF-8 w atrapach `_()` lub
  kontrolek, jeśli host tego nie robi — ukrywa to regresje. Używaj
  `test/game_option_encoding_test.rb` (źródła binarne; EN, PL oraz angielski
  tekst z rosyjskim hostem), a przy kolejnym pakowaniu także argumentu
  ze ścieżką gotowej paczki. Sam zwykły `require` albo test wyłącznie PL
  nie wystarcza do potwierdzenia zgodności.
- Tasowanie musi być zgodne z ELTEN-em: host nadpisuje `Array#shuffle`
  i `shuffle!` metodami bez argumentów. Nie używaj ich w kodzie partii ani
  planerów, zwłaszcza `shuffle(random: ...)`. Dla nowych wywołań stosuj
  `GameRoomRandom.shuffle(values, random: Random.new(seed))`, przekazując
  wspólne ziarno zapisane w zdarzeniu, nie nowy losowy seed podczas replaya.
  Zachowuj istniejące deterministyczne pomocniki (`CardGame#shuffled_cards`,
  `GameRoomDominoTiles.shuffle`, pomocniki planerów) i ich konwersję ziarna;
  nie migruj starych gier przy okazji, jeśli zmieniłoby to zapisane partie.
  Nie naprawiaj zgodności usunięciem argumentu random, `srand`, globalnym
  `rand` ani zmianą klasy Array w działającym ELTEN-ie. Testuj z
  `test/support/elten_array_shuffle.rb`, kontrolując rozdanie, ponowne
  tasowanie/wymianę, replay oraz kolejne użycie tego samego RNG. Sam test
  na zwykłym Rubym poza hostem nie wystarcza. Przy pakowaniu uruchom również
  binarne wczytanie z tą symulacją API; źródła i gotową paczkę rozróżniaj.
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
- Ręczne sortowanie ręki udostępnia `hand_sorting_available?` i wspólne
  `hand_sort_shortcuts`. Karty dostarczają semantyczne `sort_keys` dla
  colour/number/none, nigdy tłumaczone etykiety jako klucz. Domyślnego
  układu nie zmieniać przy samym dodaniu tej możliwości. Sortowanie widoku
  nie sortuje stanu partii, paczki ani kolejności zaznaczania układu;
  kontrolki CardTable/PacketCardSurface zachowują fizyczne ID i kursor.
  Sprawdzać konflikty skrótów i faktyczną obecność ręki na danym ekranie.
- Trwałą eliminację udostępnia `eliminated_from_game?`, oddzielnie od
  końca rundy, pasa, rozłączenia i all-in. Wspólny selektor dźwięków
  wykrywa przejście do tego stanu i respektuje ostateczny wynik/remis.
  Nie odtwarzać ponownie efektu porażki na końcu ani podczas replaya.
- Niezależne skutki jednego ruchu mogą mieć równoczesne efekty audio.
  Zbierać je niezależnie, nie przez wzajemnie wykluczające if/elsif;
  zachować deduplikację zdarzeń, akceptację ruchu i głośność gry.
- Tekst zasad ze znakami spoza ASCII tłumaczyć lokalnym
  `GameRoomRules.translate`: słownik hosta może przechowywać binarne klucze
  MO. Samo istnienie tłumaczenia i UTF-8 wyniku nie dowodzi, że klucz się
  dopasował. Testować rzeczywisty słownik albo wierną atrapę binarną.
- Bot wybiera akcję, ale wykonuje ją przez standardową ścieżkę gry.
- Stan stołu i partii synchronizuje stos LiveSessions. Publiczne stoły wyszukuj
  przez discovery i dołączaj do nich bezpośrednio; nie przywracaj bootstrapu
  ani synchronizacji przez Signals.
- Unikaj okresowego odpytywania i pełnej odbudowy formularza. Aktualizacja nie
  może przesuwać fokusu ani powodować zbędnych komunikatów czy dźwięków.

## Gry czasu rzeczywistego — opóźnienia i Communications

- Zapowiedź głosowa nie jest potwierdzeniem gotowości sieciowej. W Pongu
  nie uzależniaj serwu od końcowego znacznika syntezy u któregokolwiek gracza
  ani nie dodawaj po nim kolejnej pauzy: obowiązuje zwykły termin jak w singlu.
  Test z atrapą, która sama podaje końcowy indeks, nie sprawdza niezawodności
  rzeczywistego syntezatora. Uwzględniaj także całkowity brak tego indeksu,
  przerwanie mowy i różne wyjścia syntezy. Patrz `docs/PONG_SERVE_PAUSE_235.md`.
- Korzystaj ze wspólnego `Channel`/`EventChannel`. Przed implementacją
  rozpisz całą drogę akcji: wejście, kolejka, relay, odbiór, zastosowanie
  i prezentacja. Ustal, kto ma prawo rozstrzygać każde zdarzenie.
- Koordynowanie meczu przez gospodarza, także będącego obserwatorem, nie
  oznacza przekazywania przez niego każdej wiadomości. Dla akcji rozstrzyganych przez uprawnionego
  nadawcę wybieraj rozsyłanie przez relay bez dodatkowego skoku przez hosta.
  Model wymagający zatwierdzenia przez hosta musi mieć uzasadnienie i pomiar;
  nie przełączaj automatycznie wszystkich gier na `routing: :peers`.
- Nie czekaj na sieć ani dysk w klatce UI. Gotową akcję wysyłaj w tle od
  razu, bez czekania na okresowy pakiet lub następną klatkę. Zastępowalne
  pozycje mogą zachowywać tylko najnowszą wartość; ważnych akcji nie gub.
- Zachowuj uwierzytelnienie nadawcy, ID meczu/generacji, kolejność,
  deduplikację, ograniczone kolejki i pełne potwierdzenia wymaganych osób.
  Odbiorca chwilowo nieobecny nie znika z wymagań dostawy. Kolejna partia
  dostaje nowego klienta; stare zadania i powtórne zaproszenia nie mogą
  naruszać nowego połączenia. Odzyskiwanie ma działać bez Entera gracza.
- LiveSessions przechowuje trwały stan stołu i wyniki; nie uzależniaj
  każdego ruchu ani bezpiecznej lokalnej prezentacji od trwałego zapisu.
  Nie przyspieszaj kosztem uprawnień do punktów lub zgodności rozstrzygnięć.
- Mierz osobno HTTP, relay RTT, kolejki/UI, zastosowanie akcji i trwały
  zapis; nie odejmuj surowych zegarów różnych komputerów. Sprawdzaj ludzi
  i boty, różne miejsca, gospodarza-obserwatora, rewanż,
  utratę/duplikację/kolejność, tło i reconnect.
  Cztery kopie jednego komputera nie zastępują różnych łączy. Nie maskuj
  transportu zmianą fizyki ani nie uznawaj niewyjaśnionych zacięć za naprawione.

Uzasadnienie i pomiary: `docs/PONG_RELAY_DELIVERY_233.md`,
`docs/PONG_IMMEDIATE_DISPATCH_233.md`, `docs/PONG_RECEIVE_INVITATION_233.md`.

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
