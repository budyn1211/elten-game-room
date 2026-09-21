# Pong — porównanie z oryginałem i poprawki 231

Późniejsze uzupełnienie: PONG_TIMING_FIX_231.md opisuje naprawę tempa przy
nierównych wywołaniach interfejsu oraz nowy wybór użytkownika: głośność
paletek 50%/20%, zamiast wcześniejszych 25%/25%. Lektor nadal ma 25%.
Poniższy raport dokumentuje wcześniejszy etap porównania.

20 września 2026. Na polecenie użytkownika dostosowano obecną adaptację
do zweryfikowanego zachowania Axel Ponga. Ten opis zastępuje wcześniejsze
założenia w AXEL_PONG_PORT.md oraz PONG_FEEDBACK_FIXES_231.md tam, gdzie
dotyczą fizyki, aktywnego protokołu meczu i czasu nagrań. ELTEN nadal
zapewnia interfejs, konta, stoły, transport oraz trwały zapis punktów.

Użytkownik zatwierdził po zakończeniu kontroli ponowne podpisanie
2.0.2/build 231, z dotychczasowym changelogiem i API 3.0.3. Sam ten dokument
nie potwierdza gotowej paczki: wynik wydania jest w PACKAGE.json opisanym
na końcu. Bez instalowania, publikacji, GitHuba i zmian serwera.

## Materiał porównawczy

Sprawdzono statycznie odzyskane funkcje i bytecode dostarczonej wersji
1.26.4.178 oraz zainstalowanej 1.26.3.170. Nie uruchamiano odzyskanego
Pythona, nie łączono się z usługami oryginału i nie przeniesiono jego kodu,
telemetrii ani danych dostępowych do repozytorium. Niekompletnie odzyskane
moduły nie są dowodem samym w sobie: kluczowe zachowania sprawdzono także
w bytecode i zweryfikowanych pojedynczych funkcjach.

W obu wersjach istotny dla tych zmian rdzeń jest zgodny. Różnica w
sprawdzonym fragmencie przygotowania meczu dotyczyła wpisu diagnostycznego.
Nie jest to twierdzenie, że całe dystrybucje są identyczne.

## Rozgrywka dwóch osób

Oryginał ma wyłączoną ciągłą synchronizację piłki. Aktywna ścieżka oblicza
lot lokalnie, a przez niezawodny kanał przekazuje serwis, odbicie, tarczę
i nietrafienie. Zastosowano ten model, zamiast przewidywania po ostatnim
obrazie i późniejszego cofania piłki. Po odebraniu odbicia nowy przylot
zaczyna się od przeciwnej linii; oś X pozostaje taka sama dla obu osób.

Communications ma teraz opcjonalną, uporządkowaną ścieżkę takich zdarzeń
obok zastępowalnych pozycji paletek. Wywołania sieciowe odbywają się w
ograniczonej pracy w tle, nie w obsłudze klatki. Sprawdzane są natywny
nadawca, rola, partia, generacja, numer, rozmiar i zawartość pakietu.
Każda kolejka ma limit. Przepełnienie powoduje odzyskanie kanału, nie
ciche usunięcie ważnego ruchu. Zdarzenie następnej wymiany może zaczekać
na punkt LiveSessions; obserwator nie może podszyć się pod gracza również
przy odkładaniu takiego zdarzenia.

Właściciel nadal zatwierdza punkt przez GameScreen/GameRepository, dopiero
po zgodnym potwierdzeniu uczestników. Może być obserwatorem. Właściciel
losuje efekty Arcade, nie dwa niezależne klienty. Pełne obrazy służą
obserwatorom; u graczy nie przestawiają lokalnej paletki ani piłki.
Gra z botem zachowuje jeden silnik po stronie właściciela.

Brak pozycji przez 0,6 sekundy nie zatrzymuje już meczu dwóch ludzi.
Rzeczywiste dłuższe milczenie nadal prowadzi do pauzy i odzyskiwania kanału
(cztery sekundy dla ustanowionego połączenia, dziesięć na pierwsze
zestawienie). Przerwy nie są nadrabiane kilkunastoma klatkami naraz.
Po wymianie kanału niezatwierdzony punkt nie zmienia wyniku. Obie osoby
muszą używać nowej paczki: znacznik odmiany kanału oddziela ją od starej.

To nie serwerowa ochrona przed oszukującym właścicielem lub zmienionym
klientem. Jak w aktywnym oryginalnym modelu, gracz ocenia własne odbicie
i nietrafienie. Nie należy przedstawiać tego jako pełnej walidacji fizyki
przez serwer ELTEN-a.

## Fizyka i boty

- Ujednolicono oś X, kolejność fizyki i sterowania oraz pierwszy powtarzany
  krok przytrzymanej strzałki. Przed odbiciem bot nie dostaje dodatkowego
  ruchu, który ratowałby już przepuszczoną piłkę.
- Odtworzono granice bramki człowieka i bota, dalszy boczny ruch przy
  przeciwnej linii, przyrosty prędkości, losowania, tłumienie i limity
  ruchu bocznego. Zdarzenia odbicia przekazują tysięczne jak oryginał;
  lokalne obliczenia zachowują większą precyzję.
- Uwzględniono aktywne różnice zasięgu hosta/gościa i pomoc automatycznego
  odbicia przy brzegach oraz szybkiej piłce. Pomocnika bonusu po zwolnieniu
  klawisza, który w sprawdzonym kodzie wpada w obsługę błędu i zwraca zero,
  nie zamieniono arbitralnie w nową działającą przewagę.
- Zachowano sześć poziomów i sprawdzone stałe botów. Poprawiono rozpoczęcie
  reakcji, ograniczenie przy przyjęciu serwisu, odstępy śledzenia, wybór
  kierunku i czas własnego serwisu. Bot nie śledzi niewidzialnej piłki,
  ale może ją trafić, jeśli przypadkiem stoi we właściwym miejscu.
- Po punkcie paletki nie wracają do środka. Pozostały czas tarczy przechodzi
  dalej; nie maleje podczas oczekiwania na serwis. Odbicie tarczą nie
  ujawnia niewidzialnej piłki.
- Pierwszy serwis dwóch osób ma jeden wspólny wybór; zamiast niezależnych
  zegarów komputerów użyto identyfikatora meczu. Przeciwko botowi zaczyna
  człowiek. Następnie zmiana serwisu co dwa punkty pozostaje bez zmian.
- Po punkcie są trzy sekundy nagrania bramki i kolejne 2,7 sekundy do
  serwisu; zapowiedź serwującego następuje po pięciu sekundach. Można
  przestawić paletkę, ale klawisze z pauzy nie serwują następnej piłki.
  Przytrzymanie podczas aktywnej wymiany nadal może odbić blisko bramki.

## Dźwięki i dodatkowe funkcje

Odtworzono pięć zakresów wysokości dźwięku ściany, jego tłumienie,
rozmieszczenie własnego/cudzego odbicia, osobne uchwyty dźwięków i tarcze
(po dziesięć losowanych trafień obu stron). Ruch paletki ma najwyższy ton
na środku i najniższy przy obu krańcach. Kroki bota uwzględniają sumę
małych przesunięć i odstęp co najmniej 50 ms.

Dodano nagrania początku i końca meczu. Wynik ma oryginalne odstępy pół
sekundy, a po ostatnim punkcie również końcowe ogłoszenie. Opóźniona klatka
nie uruchamia kilku nagrań naraz. Punkt nadal uruchamia nagrania dopiero
po trwałej akceptacji, bez powtórzeń i bez ucięcia przez zwykłe odświeżenie.
Wynik ponad nagrane 0–21 pozostaje odczytywany zwykłą mową.

Uzgodniony wcześniej cichszy balans paletek i lektora (25%) zachowano
świadomie. Nie jest to domyślne ustawienie skompilowanego oryginału.
Suwaki i wyciszenie Game Roomu nadal działają. Nie wymieniano nagrań
wcześniejszych gier ani profili użytkownika.

Echolokacja pod Shift+E przełącza wyłączenie, szum i tony wskazujące
odległość od boków. Domyślnie jest wyłączona. Oryginał ma kod tych wskazówek,
lecz w sprawdzonych wersjach nie znaleziono podłączonego przełącznika.
Udostępnienie funkcji jest zatwierdzonym dodatkiem, nie kopią istniejącej
opcji menu. Cztery sygnały generuje deterministyczny lokalny skrypt;
ton ma 180 Hz i 150 ms, bez przerywania go w każdej klatce.

Ctrl+W ponagla wyłącznie człowieka przed serwisem. Właściciel mierzy
dziesięć sekund monotonicznie; następne ponaglenie najwcześniej po 15 s.
Po przekroczeniu przeciwnik dostaje punkt, nie odejmuje się już zdobytego.
Prawidłowy serwis anuluje termin. Zerwane połączenie nie jest karane.
Uwzględniono wyścig spóźnionego lokalnego serwisu z potwierdzonym timeoutem:
obie strony przyjmują ten sam wynik, zamiast utknąć na różnych stanach.

Publiczność pozostaje nieaktywna i bez skrótu, ponieważ żadna z dwóch
dystrybucji nie zawiera jej nagrań, a użytkownik również ich nie ma.
Przygotowane są punkty podłączenia dopingu i reakcji, sprawdzone jedynie
na atrapach dźwięku. Nie zastępowano braków przypadkowymi nagraniami.

## Granice i weryfikacja

Nie przenoszono oryginalnego menu pauzy/resetu, muzyki, logowania ani
usług sieciowych: interfejs i zarządzanie stołem pozostają eltenowe.
Nie dodawano zapisu niedokończonego meczu. Początkowe zestawienie kanału
oraz trwałe potwierdzenie punktu są adaptacją wymaganą przez Game Room.

Nowe regresje obejmują ręcznie wyprowadzone przypadki fizyki i botów,
pozycje bez aktualizacji, niezawodne odbicia, opóźnienie punktu/rundy,
Arcade, serwis na granicy timeoutu, uwierzytelnianie i bufory, rolę
właściciela-obserwatora, polskie/angielskie skróty oraz ich cleanup.
Test binarny uruchamia te warstwy z rzeczywistym słownikiem ELTEN-a.
Nie wykonywano pełnego runnera ani kolejnego meczu na żywych kontach.
Testy dźwięków sprawdzają wywołania, parametry i nagrania, nie odsłuch.

W katalogu roboczym `diagnostics/pong-original-comparison-231/`:

- SOURCE.json — konkretne wyniki celowane, składnia, zakres zmian,
  zgodność nagrań, idempotencja kompilatorów i snapshot źródeł.
- PACKAGE.json — wynik kontroli podpisu, zgodności plików i testów
  binarnej zawartości nowej paczki, gdy budowanie zostanie zakończone.

Poprzednia podpisana 231 o SHA-256 7281d98a76604c2ecc5f554f23906d49d9751bd41f4283d03fa1958d5cb3ddf8
jest zachowywana jako build-231-before-original-parity-signed.eltsetup.
Przed publiczną dystrybucją nadal trzeba ustalić prawa do oryginalnych
nagrań. Lokalna symulacja nie zastępuje ręcznego meczu, odsłuchu ani
sprawdzenia dwóch odległych łączy.
