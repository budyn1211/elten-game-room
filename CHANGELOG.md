# Historia zmian

## 1.1.3 — build 193

- wspólne menu kontekstowe jest dostępne z każdego pola stołu i partii;
  zawiera zaproszenia, dodawanie komputera, zasady gry i wyjście, a związane z
  nim skróty działają globalnie;
- zasady gry nie zajmują już osobnego pola pod Tabem; Ctrl+F1 pozostał bez
  zmian, natomiast Delete nadal usuwa wyłącznie komputer wskazany na liście
  użytkowników;
- wspólna kolejność pól to rozpoczęcie, restart albo oczekiwanie, następnie
  pole gry, czat, historia i na końcu użytkownicy;
- gracz niebędący właścicielem widzi przed partią informację o oczekiwaniu na
  jej rozpoczęcie, a po partii — o oczekiwaniu na nową grę;
- po zakończeniu fokus przechodzi cicho na restart albo oczekiwanie, więc
  końcowe wyniki pozostają w kolejce mowy, a zakończoną planszę nadal można
  otworzyć Tabem.

## 1.1.3 — build 192

- aplikacja pomija operacje na trwałych tabelach, gdy ELTEN nie przyznał do
  nich dostępu, dzięki czemu tryb deweloperski może nadal korzystać z
  podstawowych funkcji Game Roomu;
- ekran oczekującego stołu, aktywnej partii i zakończonej gry jest teraz jednym
  trwałym formularzem, który zachowuje fokus, pozycje list oraz zawartość czatu;
- lista użytkowników pokazuje role i — w obsługiwanych grach — bieżące wyniki;
- zapraszanie oraz dodawanie i usuwanie komputerów jest dostępne z menu
  kontekstowego listy użytkowników;
- po rozpoczęciu gry fokus trafia na pole gry, a po jej zakończeniu na listę
  użytkowników; zakończona plansza pozostaje dostępna do przeglądania.

## 1.1.3 — build 191

- stoły są publicznymi sesjami LiveSessions i znikają z lobby wraz z
  zamknięciem sesji, bez pozostawiania osieroconych rekordów;
- wyszukiwanie oraz ręczne dołączanie korzystają z natywnego discovery ELTEN-a
  3.0.3, bez pomocniczego Signal;
- skład pokoju pochodzi bezpośrednio z uczestników LiveSession, a stan pokoju,
  czat, rozpoczęcie gry i ruchy tworzą jeden uporządkowany stos;
- cały ruch, także akcja złożona z kilku poleceń, jest zapisywany atomowo w
  jednym wpisie stosu;
- zaproszenia korzystają z natywnego API LiveSessions zamiast własnych tabel;
- zachowano oddzielne widoki historii: Wszystko, Gra, Czat i Zdarzenia pokoju;
- tabele aplikacji nie przechowują już aktywnych stołów, członkostwa, sesji gry,
  ruchów ani zaproszeń; pozostał trwały rejestr użytkowników i ogłoszenia lobby.

## 1.1.1 — build 184

- bieżący komunikat głosowy ruchu w Warcabach używa wybranego sposobu
  prezentacji pól; po przełączeniu na współrzędne szachowe wypowiada np. A3–B4
  tak samo jak historia, zamiast numeracji pól warcabowych.

## 1.1.1 — build 183

- bot Warcabów nadal analizuje do głębokości 7 z limitem 60 000 węzłów i
  używa niezmienionej funkcji oceny, ale nie przelicza wielokrotnie tych samych
  legalnych ruchów podczas jednej gałęzi;
- wyszukiwanie korzysta z dokładnej, wewnętrznej ścieżki symulacji, pamięci
  ocen pozycji, tablicy transpozycji i kolejności ruchów z poprzedniej
  głębokości; rzeczywiste ruchy graczy i zapis zdarzeń pozostały bez zmian;
- generowanie ruchów pomija niegrywalne pola, szybciej kontynuuje wymuszone
  bicie i zapamiętuje wspólne fragmenty wielokrotnych bić;
- klucz pozycji obejmuje wszystkie dane mające wpływ na legalność i remis,
  w tym trwające bicie, ruchy bez bicia oraz historię powtórzeń.

## 1.1.1 — build 182

- pole czatu pozostaje tym samym polem podczas odświeżeń formularza i jest
  czyszczone dopiero po pomyślnym wysłaniu wiadomości;
- LiveSessions, boty i lokalne automatyczne akcje działają bez wstrzymywania
  podczas pisania, a techniczne zakończenie formularza nie pobiera i nie gubi
  następnego znaku z klawiatury.

## 1.1.1 — build 181

- zdarzenia LiveSessions i automatyczne odświeżenia czekają, gdy aktywne jest
  pole czatu, aby szybkie pisanie nie gubiło wypowiedzianych znaków; po wysłaniu
  wiadomości lub opuszczeniu pola oczekujące zmiany są przetwarzane;
- pole czatu znajduje się bezpośrednio za historią, zarówno przy otwartym stole,
  jak i podczas partii.

## 1.1.1 — build 180

- czat zachowuje pozycję kursora i zaznaczenie podczas zdalnych aktualizacji,
  a własna wysłana wiadomość jest odczytywana jeden raz;
- zwykłe skróty literowe gier nie przechwytują liter wpisywanych w edytowalnych
  polach, natomiast skróty z klawiszem Ctrl nadal działają;
- zaproszenie otwarte z powiadomienia pokazuje Przyjmij i Odrzuć na jednej
  liście obsługiwanej strzałkami;
- główne pole Chińczyka pokazuje tylko akcję rzutu, oczekiwanie albo legalne
  wybory ruchu; V otwiera listę własnych pionków, a Shift+V listę wszystkich;
- wyjście klawiszem Escape z partii zatrzymuje oczekujące komunikaty historii,
  aby ekran stołu nie odczytywał ich ponownie.

## 1.1.0 — build 176

Pierwszy stan opublikowany w tym repozytorium. Odpowiada paczce ELTEN Game Room
build 176 opublikowanej w ELTEN-ie.

Najważniejsze elementy tego stanu:

- jedenaście dostępnych gier oraz wspólny szkielet dla kolejnych;
- synchronizacja stołu i partii przez LiveSessions;
- bezpieczne dołączanie: członkostwo gracza jest zapisywane dopiero po
  pomyślnym przyjęciu do sesji;
- dostępne powierzchnie plansz, kart, kości, pytań i oceniania;
- boty oraz narzędzia do audytu strategii;
- polskie i angielskie komunikaty;
- pełna fizyczna siatka w numerycznym widoku warcabów, z dźwiękiem na polach
  niegrywalnych.

Zmiany eksperymentalne przygotowane po buildzie 176 nie należą do tej bazy.
