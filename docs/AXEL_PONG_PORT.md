# Axel Pong / Fire Pong — adaptacja do Game Roomu

**Opis historyczny pierwszej adaptacji.** Aktualny model dwóch ludzi,
fizykę, boty, dźwięki i dodatki opisuje
[PONG_ORIGINAL_PARITY_231.md](PONG_ORIGINAL_PARITY_231.md). Zastępuje on
poniższe założenia o braku lokalnego silnika gościa i pauzie po 0,6 s.
Opisany niżej dawny test żywego kanału nie sprawdzał jeszcze nowego modelu.

Poprawki po ręcznym teście podpisanej 231 opisuje
[PONG_FEEDBACK_FIXES_231.md](PONG_FEEDBACK_FIXES_231.md). Poniższy opis
weryfikacji i zestawu jedenastu nagrań dotyczy pierwotnego snapshotu wydania.

Adaptacja z 20 września 2026, przeznaczona do zatwierdzonej przez użytkownika
testowej wersji 2.0.2/build 231. Build 230 pozostaje niezmieniony. Poniżej
oddzielono testy lokalne od kontrolnej wymiany danych między dwoma
rzeczywistymi klientami ELTEN-a. Wynik kontroli podpisanej paczki, gdy będzie
gotowa: `../diagnostics/release-2-0-2/PACKAGE.json` w katalogu roboczym.

## Zakres

- Rdzeń sprawdzony statycznie w dostarczonej wersji 1.26.4.178: plansza
  30 × 20, ruch paletki, odbicia i przyspieszanie piłki, serwis co dwa
  punkty, zwycięstwo przewagą dwóch przy limicie 7/11/21, sześć trudności.
- Classic oraz Arcade Classic: odnawialna tarcza na 10 sekund i niewidzialna
  piłka, po 7% niezależnej szansy po odbiciu. Bot nie śledzi niewidzialnej piłki.
- Game Room zastępuje konta, lobby, czat, zaproszenia, obserwatorów i wyniki
  oryginału. Nie kopiujemy jego serwera, protokołu, aktualizatora ani telemetrii.
- Strzałki lewo/prawo przesuwają paletkę; strzałka w górę lub Spacja odbija
  i serwuje. Nie przechwytujemy samego Ctrl, żeby nie zakłócać skrótów hosta.
  Automatyczne odbijanie jest jawną wspólną opcją stołu, nie ukrytą przewagą.
- Wyniki trwałe przez LiveSessions, szybkie pozycje przez Communications.
  Początkowa adaptacja nie oferuje zapisywania niedokończonego meczu.

## Wspólny szkielet gier zręcznościowych

Nie wracamy do dawnego transportu turowego. Communications przenosi pełne
aktualne obrazy, nie niezbędny do odtworzenia łańcuch pojedynczych ruchów.
Wspólna warstwa odpowiada za powiązanie z konkretną partią LiveSessions,
tożsamość nadawcy, generacje połączeń, kolejność pakietów, ograniczone bufory,
gotowość, potwierdzenia otrzymanego stanu, pauzę i ponowne połączenie.
Silnik gry definiuje własny obraz i wejścia oraz bezpieczny punkt zatwierdzenia.

Elementy wielokrotnego użytku to `lib/realtime/protocol.rb`, `channel.rb`
i monotoniczny `timer.rb`, a nie gotowy silnik wszystkich gier. Protokół
ma limit 1100 bajtów (natywne maksimum to 1200). Pong wysyła aktualny stan
lub sterowanie najwyżej co 40 ms. Kanał wybiera odbiorców z członków
konkretnego stołu; natywna sesja pozostaje prywatna i szyfrowana także przy
publicznym stole. Boty nie dostają kont ani połączeń sieciowych.

Właściciel stołu oblicza jeden autorytatywny stan. Gość wysyła sterowanie,
nie punkty ani dowolne pozycje piłki. Obserwator nie steruje. Utrata pakietu
nie wymaga Entera: następny pełny obraz zastępuje poprzedni. Stare generacje
i numery pakietów są odrzucane. Bez odpowiedzi gracza gra zatrzymuje się;
przerwa nie jest rozgrywana w przyspieszeniu. Po utracie kanału wracamy do
ostatniego trwale zatwierdzonego wyniku i powtarzamy niedokończoną wymianę.
Punkt wymaga potwierdzenia odbioru końcowego obrazu przez uczestników,
następnie przechodzi przez zwykłą walidację i zapis Game Roomu dokładnie raz.

To model z autorytetem właściciela, nie ochrona przed zmodyfikowanym klientem
właściciela. Potwierdzenie odbioru nie dowodzi, że człowiek zdążył usłyszeć
dźwięk. Nie stosujemy przewidywania lokalnej paletki ani cofania fizyki
według opóźnienia wejścia; jakość odbić na słabszym łączu wymaga oceny w grze.

## Różnice względem oryginału

To adaptacja wskazanego rdzenia, nie identyczna kopia wszystkich modułów
Axel Ponga. Z oryginału nie przeniesiono logowania, lobby, serwera, czatu,
aktualizatora, telemetrii, mowy ani muzyki. Tę część zapewnia Game Room.
Nie stosujemy dawnego przesyłania głównie zmian położenia bez regularnych
pełnych obrazów. Opcja automatycznego odbicia jest wspólna dla obu stron.

Kontakt przy krańcu boiska jest ograniczony do jego brzegu, by szybka piłka
nie przeskakiwała całej strefy odbicia. Własne kroki bota i czas tarczy są
liczone w czasie symulacji, bez upływu podczas pauzy. Nie odwzorowano
dodatkowych bonusów hitboxa zależnych od sieciowego bezruchu/zwolnienia
klawisza w oryginale. Odbicie przytrzymanym klawiszem ma tylko obronę
w ostatniej chwili; osobne naciśnięcie może odbić wcześniej.

## Weryfikacja

- Reguły, geometria obu stron, sześć trudności i ograniczenia wiedzy botów.
- Zgubione, powielone, opóźnione i błędne pakiety; milczące połączenie,
  nowa generacja, obserwator i brak zapisu punktu przed potwierdzeniem.
- UI, fokus i czat, F1/głośności, binarne źródła i tłumaczenia PL/EN.
- Sprzątanie kanału/timerów, koszt obliczeń, regresje istniejących gier.
- Wyniki konkretnych uruchomień: `../diagnostics/axel-pong-port/LOCAL.json`.
  Końcowo 22/22 celowane skrypty oraz 23/23 kontrole składni.
  Pełny runner nie był używany. Próba binarna wczytuje źródła jako bajty
  i używa rzeczywistego słownika ELTEN-a; nie oznacza nowej gotowej paczki.

Użytkownik zezwolił na test rzeczywistego Communications. Drugą kopię
uruchomiono zwykłym skryptem. Próba ładuje kod transportu/silnika do osobnej
przestrzeni nazw w obu procesach, bez podmieniania zainstalowanej gry.
Sterowanie jest automatyczne, dźwięk celowo wyłączony, nie powstaje normalny
stół ani serwerowy wynik. Test obejmuje prywatne zestawienie, pełne obrazy,
krótką utratę danych, wymianę kanału, potwierdzenie końcowego stanu i cleanup.
Konta znajdują się na jednym komputerze; nie jest to test dwóch odległych
łączy ani ręczne sprawdzenie odczuć graczy.

Pierwsza 48-sekundowa próba wykazała działający UDP, powrót po utracie
danych i po wymianie kanału. Pod koniec wystąpiła dodatkowa pauza, której
przyczyny nie udało się ustalić z tamtego zapisu. Użytkownik dopowiedział,
że w tym czasie aktualizował Game Room na jednym z kont, i polecił na razie
nie badać tej pauzy. Nie traktujemy jej jako potwierdzonego błędu Ponga ani
dowodu dawnego problemu Game Roomu. Powtórka z dokładniejszym
zapisem nie wykazała tej późnej pauzy, ale ujawniła zbyt szybkie ponawianie
zestawiania: limit czterech sekund wyprzedzał natywne ponowienie zaproszenia
po pięciu. Początkowy handshake otrzymał limit dziesięciu sekund, a działający
wcześniej strumień zachował czterosekundowy próg odzyskiwania. Zatrzymanie
fizyki nadal następuje dużo wcześniej — przy braku świeżych danych przez
0,6 sekundy. Szczegółowe kolejne ślady są w `LIVE*_MAIN.json` i `LIVE*_TEST.json`.

Ostatnia 58-sekundowa próba z poprawką (`LIVE3_MAIN.json`, `LIVE3_TEST.json`)
zakończyła się poprawnie po obu stronach. Kanał UDP przeniósł ponad tysiąc
odebranych obrazów/wejść na każdej stronie; największy obraz miał 478 bajtów,
a wejście 132. Po dwusekundowej przerwie w wysyłaniu wznowienie nastąpiło
bez klawiszy. Celowa wymiana kanału zakończyła się wznowieniem po około
2,4 sekundy, bez dodatkowego ponowienia. Oba końcowe obrazy były identyczne,
host otrzymał potwierdzenie końcowego punktu. Oba rejestry zasobów były puste
po zamknięciu testu. Jedynym natywnym zdarzeniem zamknięcia w środku próby
było to wywołane celowym testem. Nie są to pomiary gwarantowanego opóźnienia.

Ścieżkę trwałego punktu, także gdy właściciel jest obserwatorem, sprawdzono
lokalnie z prawdziwym GameScreen/GameRepository i atrapą transportu. Nie
wysyłano takich punktów na serwer. Natywny TCP fallback sprawdzono w kodzie
API i testach lokalnych; nie wymuszano go na żywych kontach. Pozostaje ręczny
mecz, odsłuch i test na różnych łączach. Sprawdzanie niewielkiego silnika
nie gwarantuje braku przycięć całego hosta ELTEN-a.

## Zasoby i publikacja

Jedenaście nagrań `Audio/pong_*` pochodzi z dostarczonej paczki Axel Pong:
rolling, Hit, Ballborder, Move, move_opponent, Border, Goal, invisible ball
oraz shieldon, shieldoff, shieldhit1. Nie modyfikowano nagrań. Oryginalne
nazwy i porównanie SHA-256 są zapisane w prywatnym raporcie weryfikacji.

Źródła porównawcze pozostają w prywatnym outputs/axel-pong-recovery-20260920.
Nie uruchamiać odzyskanego Pythona ani łączyć się z usługami oryginału.
Przed publiczną dystrybucją materiałów oryginału potwierdzić prawa do ich
wykorzystania. Użytkownik zatwierdził podpisanie paczki do testów; nie obejmuje
to publikacji ani instalacji.
