# Imiona botów — 2.0/build 227

Zaimplementowano listy użytkownika: 24 imiona polskie i 26 angielskich.
Lista zależy od języka interfejsu dodającego bota, nie języka zestawu gry.
Dla pozostałych języków używana jest lista angielska. Zachowano pisownię
użytkownika; usunięto tylko końcowe kropki oddzielające angielskie pozycje.

Imię losowane jest raz przy dodaniu. Pomijane są imiona już zajęte przy
stole, również przez ludzi, bez rozróżniania wielkości liter. Losowanie
nie zmienia generatora używanego przez reguły partii ani jej odtworzenie.
Nie ma nowego ustawienia ani dodatkowego wyboru dla gracza.

Krótki stały kod imienia jest częścią identyfikatora bota i tablicy
`bot_names` zapisanej wraz z `bot_count` w tym samym zdarzeniu stołu.
Nie ma osobnego żądania dla imienia. Wszyscy uczestnicy widzą tę samą
nazwę, również po dołączeniu później, zmianie języka i odświeżeniu.
Nowy zapis i wznowienie partii zachowują imiona. Nie wdrażano migracji
starych zapisów; użytkownik potwierdził, że nie są potrzebne.

Usuwanie komputera usuwa rzeczywiście wskazaną osobę, nie zawsze ostatnie
miejsce. Pozostałe boty zachowują imiona, choć techniczne numery miejsc
są porządkowane. Usuwanie nie jest dostępne podczas trwającej partii.

Historia i odczyt dodawania/usuwania zawierają teraz samo imię, np.
„Dodano Maślana.” i „Usunięto Maślana.”, bez słowa „komputer”. Dotyczy
to własnego i innych klientów, również odczytu wcześniejszych zdarzeń
po zmianie składu. Globalne komunikaty lobby zachowują dodatkowo nazwę
gry i właściciela stołu. ID bota przechowywane jest w istniejącym polu
wiadomości danego zdarzenia, a nie wyszukiwane po aktualnym numerze miejsca.
Nie dodano żądań ani kolumn; prywatne stoły nie wysyłają tych wpisów do lobby.
Kontrola tej późniejszej poprawki i przebudowania: poza repo
`../diagnostics/bot-name-activity-227/`.

Nowe pokoje ogłaszają discovery protocol 5. Starszy klient nie może wejść
i potraktować rozszerzonego identyfikatora bota jako ludzkiego konta.
Do wspólnych testów należy użyć tej samej najnowszej paczki na obu klientach
i utworzyć nowy stół. Nie zmieniano schematu ani danych tabel serwerowych.

## Weryfikacja i paczka

Celowane testy obejmują wszystkie 50 nazw, polskie kodowanie, kolizje,
wybór języka, atomową zmianę stołu, usunięcie wybranego bota, trzech
klientów, późne dołączenie, czyszczenie stosu przed nową partią i zdarzenia
sterowane przez mastera. Zapisy testowe obejmują 15 gier i ponowne
wykonanie ruchu, w tym nazwę odbiorcy wewnątrz zdarzenia Tysiąca.
Wspólny test binarnego ładowania odtwarza też API tasowania ELTEN-a.

Pełny runner ani ręczna gra na rzeczywistych klientach nie są częścią tej
kontroli. Wyniki znajdują się poza repo w `../diagnostics/bot-names-227/`:
`TESTS.json`, `SOURCE.json` oraz, po sprawdzeniu podpisanej paczki,
`PACKAGE.json`. Raport paczki zawiera rozmiar, SHA-256, weryfikację podpisu
autora i zgodności wszystkich plików ze źródłami.

Zachowano wersję 2.0 i numer 227. Do tego samego changelogu PL/EN dodano
krótką informację o imionach, obok wcześniej dodanej informacji o Biblios.
Przebudowanie obejmuje także wcześniejsze niewydane poprawki Rummy,
Domino, Mexican Train i Scrabble oraz lokalną integrację Biblios z PR #7.
Bez instalacji i publikowania na ELTEN-ie albo GitHubie.
