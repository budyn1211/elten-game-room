# Tasowanie i odczyt punktacji — niewydane zmiany 229

Stan na 18 września 2026. Nadal obowiązuje wstrzymanie wydania.
Źródła pozostają w wersji 2.0.1/build 229. Changelog został uzupełniony;
podpisana paczka nie była przebudowywana.

## Ponowne tasowanie w trakcie rozdania

UNO, Makao, 99, Rummy oraz Poker dobierany otrzymały komunikat
„Przetasowano talię.” / „The deck was reshuffled.” i dźwięk card-shuffle.
Dotyczy to faktycznego wykorzystania odrzuconych kart po wyczerpaniu talii,
nie zwykłego rozdania. Pusta talia bez kart do ponownego wykorzystania nie
wywołuje komunikatu. Dotychczasowe reguły, generator i kolejność kart są
zachowane; Poker nadal nie dobiera własnych kart odrzuconych w bieżącej wymianie.

Wspólny GameRoomCardDeckHistory porównuje istniejący licznik recyklingu
przed i po przyjętym zdarzeniu. Wpis trafia do historii przed komunikatem
dobrania lub wymiany. Jedno zdarzenie ma najwyżej jeden taki wpis i dźwięk,
również przy seryjnym dobieraniu kary. Nie dodano żądań sieciowych.
Odczyt i audio używają standardowej obsługi zaakceptowanych nowych zdarzeń;
odświeżenie, odtworzenie historii, ponowne otwarcie i odrzucony ruch nie
powtarzają efektu. Efekt słyszą także inni uczestnicy i obserwatorzy,
również kiedy dobiera bot. Zachowano głośność, wyciszenie i nakładanie efektów.

Nagranie z dostarczonego folderu Freesound: „Card Shuffle”, empraetorius,
CC BY 4.0, https://freesound.org/s/201253/. Skopiowano bez zmiany dźwięku,
pod nazwą Audio/card-shuffle.ogg; atrybucja jest w THIRD_PARTY_NOTICES.md.
107494 bajty, SHA-256:
313fbb765b613fd36d325262ebfa916bcfa7aa75e2eef8a8a1de8ced6f1943df.

## Kolejność wyników

Wspólny score_announcement_order sortuje liczbowo malejąco, a trwale
wyeliminowanych umieszcza na końcu. Przy równym wyniku zachowuje kolejność
miejsc. Nie zmienia punktacji, miejsc, historii rozliczeń ani zasad wygranej.
Dotyczy także gier, w których niższy wynik jest lepszy: zgodnie z poleceniem
jest to kolejność liczb, a nie nowy ranking zwycięzców.

- S: UNO, Yahtzee, Spades, Tysiąc, Farkle, Państwa-miasta, Quiz Party,
  Rummy, Domino, Mexican Train, Scrabble i Taboo.
- Biblios: końcowa punktacja; nie ujawniono ukrytych wyników podczas gry.
- 99: liczba żetonów; zero nadal nie oznacza automatycznej eliminacji.
- Monopoly: wartość majątku; bankruci na końcu, z zachowaniem opisu gotówki.
- Poker: cudze żetony pod Shift+S. Zwykłe S nadal podaje tylko własne żetony.
- Drużyny są odczytywane razem według wspólnego wyniku.
  All-in w Pokerze ani wypadnięcie z samej rundy UNO nie są trwałą eliminacją.
- Nie zmieniono S liczącego figury/pionki ani pozostałych znaczeń tego klawisza.

## Changelog

Zachowano 14 dotychczasowych punktów pod jednym nagłówkiem 2.0.1/229.
Dopisano osiem brakujących: filtry kontaktów, wspólny czas na ruch, kara
czasu w 99, pas i wymiana po czasie w Pokerze wraz z pulami bocznymi,
krótsze Ctrl+R i polskie zestawy Domino, osobne skróty w zasadach,
ponowne tasowanie oraz kolejność wyników. Dokument, moduł i PL.mo są zgodne.

## Weryfikacja

- Końcowe 21/21 celowanych skryptów zakończonych powodzeniem.
- Składnia wszystkich 67 zmienionych lub nowych plików Ruby poprawna;
  git diff --check bez błędów, kompilacja tłumaczeń idempotentna.
- Nowy test odczytu S sprawdza 16 gier, wyniki ujemne i zerowe, remisy,
  drużyny, eliminację, prywatność wyników i brak mutacji stanu/historii.
- Nowy test tasowania sprawdza pięć silników przez action_for i replay,
  ludzi/boty/obserwatorów, komunikaty, dźwięki, puste talie i nowe rozdania.
  Wyłączenie samego dodatku prezentacyjnego daje identyczny stan gry,
  zaakceptowane zdarzenia oraz wcześniejsze komunikaty.
- Binarne źródła i rzeczywisty lokalny słownik ELTEN-a sprawdzone w PL/EN;
  ponowna próba po kompilacji katalogu także przeszła.
- Przeszły regresje dźwięków, wyników, komunikatów, zegarów i zapisów,
  Makao, intercepcji UNO oraz zasad i wariantów Rummy.
- Uaktualniono stary test pomocy: Enter i Shift+Enter są stałymi wskazówkami
  kontrolki paczek, nie dodatkowymi dynamicznymi skrótami. Test sprawdza
  dokładną listę, brak duplikatów i usuwanie nieaktualnych skrótów, bez
  usuwania stałej pomocy. Nie zmieniano runtime pomocy przy tej poprawce.

Pełne wyniki: ../diagnostics/card-reshuffle-scores-229/RESULTS.json.
Nie wykonywano pełnego runnera ani prób żywego interfejsu i odtwarzacza.
Nie budowano, nie podpisywano, nie instalowano, nie publikowano,
nie wysyłano na GitHub i nie zmieniano serwera ani profili.

Dotychczasowa podpisana paczka ma nadal 12966768 bajtów i SHA-256
8f80d6d32ba07e81ffe7475b793b6cbf97ae0365c886b6a38f9921041d01f01c.
Nie zawiera opisanych tutaj zmian ani wcześniejszych niewydanych filtrów
i zegarów.
