# Dalsze porządki po audycie utrzymywalności

Zakres: czternaście punktów audytu z 25 września 2026, zatwierdzonych do
wdrożenia. Nie jest to zmiana reguł gier, strategii lub siły botów, modelu
LiveSessions ani zawartości pakietów danych. Weryfikacja obejmuje zmienione
przypadki, nie ponowny pełny przebieg wszystkich testów.

## Granice i odpowiedzialności

- `GameRoomLiveSessionStore::RecordValidator` sprawdza rekordy bez operacji sieciowych.
  Indeks zawiera tylko wcześniejsze **zaakceptowane** początki partii.
  Spóźniony początek po wstawieniu w porządku sekwencji wymaga ponownej walidacji;
  odrzucony początek nie daje prawa do ruchów. Kontrola autora i epok pozostaje.
- Retencja przechowuje najwyżej osiem nieaktywnych stołów, poza pozycjami
  chronionymi przez niepewny zapis, operację w toku lub nieodebrane odzyskane
  ruchy. Aktywne członkostwo nie jest usuwane z powodu braku powiadomień.
  Spóźnione callbacki i publikacja wyniku walidacji sprawdzają tożsamość
  natywnej sesji i kolekcji, nie sam licznik, który może zacząć się od nowa.
- Edytor opcji ma jawne zależności od programu i odczytu/zapisu preferencji.
  Nie tworzy sam stołu. Zmiana języka nadal aktualizuje wybory w istniejącym
  formularzu; błędne dane i fokus pozostają do poprawienia.
- Wspólne wiązania skrótów znają definicje, modyfikatory i tekst pomocy, ale
  nie znają sesji ani nie wysyłają ruchów. Te czynności pozostają w ekranie.
- Gry deklarują ograniczenia prywatnych faz, lokalne ustawienia, pamięć
  opcji i efekty dźwiękowe. Odtwarzacz nadal odpowiada za zasoby, głośność,
  nakładanie niezależnych efektów i deduplikację.
- Klient realtime sam resetuje swoje pola. Wspólne są kontrola obsady,
  rejestracja pomiaru pingu i sekwencer zapowiedzi wyniku; fizyka i jej
  harmonogramy pozostają osobne. Audio Ball nie dziedziczy od odtwarzacza Ponga.
- Symulacja botów powstaje leniwie. Znane strategie bez symulacji jawnie
  rezygnują z niej; strategie zewnętrzne domyślnie zachowują wcześniejszy
  kontrakt. Nie usunięto obsługi starszej sygnatury `choose` dla dodatków.
- Limit kandydatów Remika stosowany jest przed kosztownym sprawdzeniem,
  zachowując kolejność i zestaw wcześniej rozważanych możliwości.
- Powierzchnie kart współdzielą czystą decyzję nawigacji Z, zachowując własne
  blokady paczek i deklaracji. Pomocniki tasowania delegują sam rdzeń do
  `GameRoomRandom`; ich konwersje ziaren i stan RNG pozostają bez zmian.

## Odczyt kandydatów z tabel

W natywnym kliencie nie znaleziono udokumentowanego grupowego operatora
filtrowania po liście kont. Nie wprowadzamy domyślnego `IN` ani pętli jednego
żądania na osobę. Zastosowano zatwierdzoną alternatywę: snapshot na maksymalnie
15 sekund i 4096 wierszy. Większy wynik nie jest utrzymywany w cache.
Puste listy kandydatów nie wywołują zapytania.

Odczyty własnych ustawień pozostają świeże; lokalny zapis unieważnia snapshot
także po niepewnym wyniku. Zmiana preferencji wykonana przez inne konto może
być widoczna w doborze odbiorców do 15 sekund później. To jawny kompromis,
nie gwarancja natychmiastowej propagacji. Błąd odczytu nie staje się pustą
listą. Weryfikacja autora rekordu i filtrowanie aktualnych kandydatów pozostają.
Tabele, ich ochrona i schematy nie są zmieniane.

## Testy i narzędzia

Test nie powinien importować pełnego innego scenariusza. Wspólne dane i atrapy
są w `test/support`, a zestawy binarne uruchamiają scenariusze osobno, z
binarnym wczytaniem źródeł. Starsze nazwane zestawy korzystają ze wspólnego
runnera, zachowując kontrole katalogu i wymagane środowisko hosta.
Nie usuwać asercji tylko dlatego, że wcześniej wykonywały się podczas importu.

Stan walidacji i próby rzeczywistych klientów są zapisywane osobno w prywatnym
raporcie `diagnostics/maintainability-followup-2026-09-25` katalogu roboczego.
Pierwsze niepowodzenia pozostają w raporcie. Nie należy nazywać połączonych
wyników wielu prób jednym bezbłędnym pełnym przebiegiem ani porównania modeli
testem na wielu komputerach.

## Wynik wdrożenia — 25 września 2026

Wdrożono wszystkie czternaście zatwierdzonych kierunków, w podanym wyżej
ograniczonym zakresie. Nie wykonywano dalszych eksperymentalnych optymalizacji
strategii ani walidacji wyłącznie końca historii. Zachowano zgodność zewnętrznej
czteroargumentowej strategii `choose`, której usunięcia audyt nie zalecał bez
ustalenia publicznego kontraktu.

- Celowane zestawy obejmują 253 różne scenariusze; ostatnie wyniki wszystkich
  są poprawne. To zestawienie wielu przebiegów, nie pojedynczy pełny runner.
  Cztery agregaty binarne są raportowane osobno; ich dzieci nie są liczone
  dwukrotnie. Pierwsze niepowodzenia i poprawione próby pozostają w raporcie.
- Sprawdzono składnię 245 zmienionych/dodanych plików Ruby. Graf runtime nie
  ma nierozwiązanych importów ani zależności od testów/treningu/narzędzi.
- Stary i nowy walidator dały identyczne decyzje na historii 1600 i 3200
  rekordów, również przy fałszywych startach, autorach i niepoprawnej kolejności.
  Dla gęstej historii 3200 rekordów mediana pięciu prób wyniosła około
  483 ms przed zmianą i 9 ms po zmianie. To czas samej walidacji, nie pingu
  ani całej tury. Porównania botów i efektów obejmują również dalszy stan RNG.
- Niezależne próby retencji wykryły trzy wyścigi we wstępnej wersji tej zmiany.
  Poprawiono je przed żywymi próbami; kontrolne przywrócenie wersji wadliwej
  nadal odtwarza wszystkie trzy. Testy nie zostały osłabione do uzyskania PASS.
- Na trzech rzeczywistych kontach wykonano osiem zakończonych scenariuszy:
  99, Scrabble, UNO, Makao, Remik z botem, Audio Ball, Pong single i Pong debel
  z botami. Łącznie 182 końcowe porównania. Sprawdzano m.in. zgodność zdarzeń
  i stanu, zamiany, gospodarza-obserwatora, powroty, fokus i szkic czatu,
  natywne okna opcji, odczyt za Wiadomościami, kanały/ping i kolejkę nagrań.
- Dodatkowo rzeczywiste API utworzyło, odczytało i zamknęło 11 własnych pustych
  stołów: retencja zatrzymała się na ośmiu. Osobna próba odczytu tabel pokazała
  jedno zapytanie przed cache, zero przy powtórzeniu i jedno po unieważnieniu;
  nie wysyłano w tej próbie powiadomień ani nie zmieniano preferencji.

Próby żywe używały normalnych formularzy, repozytoriów i API/relay, z wejściem
przez handlery kontrolek i kolejki pól. Nie są testem fizycznej klawiatury,
odsłuchu, wszystkich możliwych partii ani różnych łączy. Kontrola powtórzenia
punktu ponawiała przyjęty event w handlerze, nie symulowała duplikacji relay.
Nieukończone próby pomocników są opisane oddzielnie, nie jako sukcesy gry.

Własne stoły prób zamknięto, sondy usunięto. Bieżący kod pozostawiono w pamięci
trzech klientów, do ich restartu lub ponownego wczytania zainstalowanej paczki.
Nie zmieniano instalacji, profili, schematów, ochrony ani limitów serwera;
nie budowano/podpisywano, nie zmieniano wersji/changelogu i nie publikowano.
