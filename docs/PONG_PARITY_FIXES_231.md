# Axel Pong — poprawki F02–F08 po pogłębionym audycie

20 września 2026. Punkt F01 pozostawiony bez zmian na najnowsze polecenie
użytkownika. Nie zmieniano modalnej pomocy, timerów innych gier ani
LiveSessions. Opis tego punktu w audycie dotyczy ścieżki lokalnego timera;
odłożenie pracy nie jest nowym dowodem przyczyny po stronie serwera.

Wcześniejsza zgoda obejmowała poprawianie potwierdzonych różnic od razu.
Samo sporządzenie poprzedniego raportu nie kończyło więc zadania.

## Co poprawiono

- **F02, zasięg odbicia.** Zawsze jest jeden gracz o roli serwera fizyki
  i jeden gościa: 4 oraz 4,5 jednostki bazowego zasięgu. Gdy właściciel
  tylko obserwuje, pierwszą rolę otrzymuje pierwszy gracz. Właściciel nadal
  zatwierdza punkty dotychczasową ścieżką; rola widza nie daje prawa ruchu.
- **F03, brzeg paletki przeciwnika.** Odbiór pozycji przy brzegu odtwarza
  odgłos brzegu, nie zwykłego kroku. Licznik kolejnych prób ruchu pozwala
  usłyszeć ponowne naciśnięcie przy brzegu również wtedy, gdy pozycja nie
  zmieniła się. Zwykłe okresowe obrazy stojącej paletki pozostają ciche.
  Licznik jest częścią obecnych pakietów pozycji, nie nowym żądaniem HTTP.
  Po utracie kilku pakietów odtwarzana jest ostatnia informacja, bez serii
  zaległych dźwięków. Bot zachowuje własny akumulator małych kroków.
- **F04, panorama.** Już odtwarzany krok lub odgłos brzegu przeciwnika
  przemieszcza się razem ze zmianą pozycji słuchacza/przeciwnika. Zmiana
  parametrów nie uruchamia ponownie nagrania. Głosy wyniku pozostają
  nieruchome; nie przypięto takiej aktualizacji do wszystkich efektów.
- **F05, odbicie tarczą przeciwnika.** Przywrócono oryginalny domyślny
  mnożnik 0,91 (0,2 na drugim końcu boiska × 4,55), zamiast 0,455.
  Zatwierdzone paletki 50%/20% i lektor 25% pozostają bez zmian.
- **F06, nasycenie stereo.** Ograniczenie poziomu do 1 stosowane jest
  oddzielnie dla lewego i prawego kanału, po głośności głównej Game Roomu.
  Zachowujemy surowe parametry, dlatego ściszenie i ponowne podgłośnienie
  w trakcie nagrania nie traci informacji o pierwotnej panoramie/poziomie.
- **F07, obie strzałki.** Najpierw wykonywane są osobne naciśnięcia lewej
  i prawej, potem powtarzanie z pierwszeństwem lewej. Kierunek serwisu jest
  niezależny: obie trzymane strzałki dają serwis prosto. Liczniki zachowują
  krótkie naciśnięcia między odświeżeniami, bez powtórzeń przy nowej wymianie
  lub odtworzeniu kontrolki. Mysz zachowuje kolejność klawiatura–odbicie–mysz
  oraz obie próby ruchu, nawet jeśli ich łączne przesunięcie wynosi zero.
- **F08, bot przed serwisem.** Końcowa korekta nie większa niż 0,05 jednostki
  ustawia dokładny cel bez dźwięku i bez dopisywania reszty do akumulatora
  kroków. Parametry strategii, losowania i czas przygotowania nie zmieniają się.

Dla F06 sprawdzono również API backendu: Sound ELTEN-a przekazuje poziom
i panoramę do BASS. [Głośność BASS](https://www.un4seen.com/doc/bass/BASS_ATTRIB_VOL.html)
może przekraczać 1, a [domyślna krzywa panoramy](https://www.un4seen.com/doc/bass/BASS_CONFIG_CURVE_PAN.html)
jest liniowa. Nie zmieniamy jej globalnie; przeliczamy ograniczone kanały
z powrotem na poziom i balans konkretnego nagrania Ponga.

## Dowody i granice

Nowy `test/axel_pong_parity_fixes_test.rb` odtworzył wszystkie siedem
niezgodności przed poprawkami. Po nich przechodzi również rozszerzone
przypadki: oba brzegi/obie strony, właściciel grający lub obserwujący,
utracone pakiety i bezczynność, 112 kombinacji panoramy/poziomu/głośności,
klawiatura z myszą i bez, lokalny/zdalny bot, odtworzenie kontrolki,
nowa wymiana, pole czatu oraz nieprawidłowe dane wejściowe.

Stare oczekiwania testów tarczy (2,0 bez ograniczenia i 0,455) zastąpiono
wartościami wyprowadzonymi z oryginału, nie usunięto ich asercji. Nowa
regresja jest również w celowanym teście binarnych źródeł/gotowej paczki.
Zapis uruchomień i kontroli wydania: `../diagnostics/pong-parity-fixes-231/`.

Nie wykonywano odzyskanego Pythona, pełnego runnera, nowego meczu na żywych
kontach, fizycznego testu myszy ani odsłuchu urządzenia. Sprawdzenie poziomów
API i matematyki stereo nie jest pomiarem głośników. Nie deklarujemy pełnej
zgodności wszystkich modułów ani identycznego brzmienia różnych backendów.

Pozostają wcześniejsze osobno opisane braki funkcjonalne: ręczna pauza,
wybór perspektywy widza i osobiste ustawienia. Nie przerabiano uzgodnionej
wspólnej opcji automatycznego odbijania. Brakujących nagrań publiczności
nie zastępowano innymi dźwiękami. Grafika i oryginalne lobby pozostają
poza zakresem.

## Paczka

Użytkownik zatwierdził ponowne zbudowanie i podpisanie 2.0.2/build 231.
Changelog PL/EN, numer i API 3.0.3 pozostają bez zmian. Poprzednia podpisana
paczka o SHA-256 `82f84e12c7a90f7d05709dadb70779b6a3326bebfd72e199d5699607bba1de56`
ma być zachowana jako `ELTEN-Game-Room-build-231-before-deep-parity-fixes-signed.eltsetup`.
Końcowym potwierdzeniem nowego artefaktu jest `PACKAGE.json`, nie sam ten
opis przygotowania. Bez instalacji, publikacji, GitHuba i zmian serwera/profili.
