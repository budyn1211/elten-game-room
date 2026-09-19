# Zegar serwera, kolejność historii i krótsza pomoc — 19 września 2026

Zmiany są w źródłach, nie w podpisanej paczce 2.0.1/229. Nie instalowano,
nie budowano, nie podpisywano, nie publikowano ani nie zmieniano serwera.
Zachowano wcześniejsze lokalne poprawki Krowy, Statków, Monopoly i opóźnienia
bota przy pustym stanie replaya. Wersja, changelog i ochrona tabel bez zmian.

## Co potwierdzono

Metadane zaproszenia były datowane zegarem nadawcy, a odbiorca porównywał je
ze swoim zegarem. W zgłoszonym przypadku różnica wynosiła około dwóch godzin;
pięciominutowe zaproszenie mogło zostać uznane za wygasłe natychmiast.
Nie jest to sam problem sposobu wyświetlania strefy czasowej: porównywano
niezgodne znaczniki czasu. Koperta powiadomienia ma datę nadaną przez serwer.

Potwierdzono również osobny błąd historii. Po potwierdzeniu wysłania ruchu
lub czatu nadawca lokalnie nadawał mu czas komputera. Gdy później docierały
metadane serwera, nie zawsze poprawiały ten czas. Drugi klient miał już czas
serwera, więc sortowanie po datach dawało różną kolejność. Regresja odtworzyła
problem na dwóch symulowanych klientach z rzeczywistym magazynem LiveSessions.

Nie jest to dowód wyjaśniający wszystkie wcześniejsze incydenty utykania
partii ani zgłoszenie nieistniejących stołów 99. Tych wniosków nie rozszerzano.

## Wspólny zegar

`GameRoomClock` pobiera potwierdzony czas z istniejącego endpointu ELTEN-a
`/api/v1/system/time`. Pierwsza synchronizacja odbywa się w już istniejącym
zadaniu sieciowym łączenia lub w tle przy ładowaniu preferencji powiadomień.
Odczyt czasu, fokus, skróty i mapowanie powiadomień nie wykonują HTTP.

Między synchronizacjami upływ czasu mierzy licznik monotoniczny. Przestawienie
systemowego zegara nie zmienia już potwierdzonej daty. Ponowny odczyt jest
możliwy przy kolejnej okazji po pięciu minutach; nie dodano osobnego pollera.
Nieudany odczyt ma 60 sekund przerwy przed kolejną próbą. Mając wcześniejszą
kotwicę serwerową, program zachowuje ją podczas awarii sieci. Bez pierwszego
potwierdzenia operacja sieciowa zgłasza błąd, zamiast uznawać lokalny czas za
potwierdzony. Nieprawidłowa odpowiedź nie uruchamia fallbacku hosta do Time.now.

Pobieranie nie blokuje blokady odczytywanej przez interfejs. Równoczesne
rozpoczęcia współdzielą jedno zapytanie. Anulowanie i błędy programistyczne
nie są ukrywane przez fallback. Pozostaje zwykła dokładność endpointu,
opóźnienie odpowiedzi i dryf lokalnego licznika; nie deklarujemy idealnej
synchronizacji co do milisekundy.

## Przejrzany zakres

| Zastosowanie | Rozstrzygnięcie |
| --- | --- |
| Ważność zaproszeń i ogłoszeń stołów | Czas wspólny; data koperty serwera zamiast daty nadawcy. |
| Odroczone powiadomienia i zapisane potwierdzenia | Przed pierwszą synchronizacją bez decyzji o wygaśnięciu na podstawie zegara systemu; kolejka w pamięci. |
| LiveSessions: tworzenie, aktualizacja, zdarzenia, granice partii | Daty serwera; minimalne potwierdzenie ma czas tymczasowy poprawiany przez późniejsze metadane. |
| Historia partii i czatu | Wspólna kolejność stosu serwera, kolejność poleceń wewnątrz paczki, archiwum przed nowymi zdarzeniami. |
| Globalna historia lobby | Kolejność ID nadanych przy zapisie, nie dat klientów. |
| Limity i ich odczyt | Wspólny zegar przeliczony do epoki konkretnej partii. |
| Zapis i wznowienie | Zachowany czas gry i pozostały limit, bez przepisania zapisanych ruchów. |
| Dzienna Krowa | Potwierdzony wspólny czas i dotychczasowa data warszawska; brak potwierdzenia nie uprawnia do rozpoczęcia dnia. |
| Rejestr użytkowników, zaproszenia, wyniki i stare adaptery repozytoriów | Wspólny czas przy tworzeniu nowych dat. |
| Opóźnienie botów, odświeżanie, retry, bufory i budżety obliczeń | Nadal licznik monotoniczny; kontakt z serwerem byłby tu zbędny i szkodliwy. |
| Wyświetlanie dat, konwersja UTC/strefy i narzędzia offline | Zachowane konwersje; lokalny fallback tylko przed dostępem do zegara w narzędziach/offline. |

Przeszukano kod wykonawczy aplikacji, `lib` i `games` pod kątem odczytów
Time/Date oraz pomocników zegara. Pozostałe `Time.now.to_f` poza wspólnym
zegarem są istniejącymi awaryjnymi fallbackami liczników wydajności na
środowisko bez zegara monotonicznego; normalny ELTEN ich nie używa.

## Zaproszenia, historia i gry

- Zaproszenie nadal ma maksymalnie pięć minut od daty serwera, nie od kliknięcia.
  Po wolnym wysłaniu przekazywany jest pozostały czas. Krótsze serwerowe
  uprawnienie do prywatnej sesji nie jest wydłużane. Nie zmieniono dostępu do
  publicznych/prywatnych stołów ani weryfikacji tożsamości.
- Obsłużono stare powiadomienia z błędną datą nadawcy. Przy braku serwerowej
  koperty stary adapter offline zachowuje swój dotychczasowy format.
- Początkowe oczekiwanie na zegar korzysta z ograniczonej kolejki istniejących
  powiadomień; samo odroczenie nie pobiera listy kontaktów przy wyłączonym filtrze.
- Korekta daty istniejącego zdarzenia unieważnia widok także wtedy, gdy liczba
  ruchów i ich ID się nie zmieniły. Nie dodaje ruchu i nie powtarza jego odczytu.
- Zegary UNO, Makao, 99, Pokera i pozostałych wspólnych limitów, a także Quizu,
  Państw-miast, Rummy, Taboo, Scrabble, domina/Mexican Train i aukcji Monopoly
  stosują tę samą epokę przy wysyłaniu, sprawdzaniu i prezentacji czasu.
- Stare partie mogą mieć epokę założyciela inną od serwera. Zachowujemy ją
  przez przeliczenie, włącznie z pauzą i wznowieniem. Nie przerabiamy istniejących
  zdarzeń, ukrytych odpowiedzi, reguł punktacji, kar za czas ani losowania.

## Granica po stronie ELTEN-a

Przejrzano lokalne źródła hosta, bez ich modyfikacji. W
`src/eapi/notifications.rb`, `normalize_active_notifications`, główna lista
ELTEN-a nadal porównuje termin powiadomienia z `Time.now`. Również natywne
`LiveSessions::Invitation#expired?` i ścieżka `pending?` używają zegara systemu.
Host może więc ukryć natywne powiadomienie przed przekazaniem go Game Roomowi.
Nie należy twierdzić, że poprawka dodatku usuwa ten błąd hosta. Normalna ścieżka
otwierania zaproszenia Game Roomu korzysta z koperty i świeżego wyszukania sesji.
Naprawa ogólnej listy/natywnej kolejki ELTEN-a wymaga odrębnej zmiany tamtego kodu.

## Krótsze opisy skrótów

Na dodatkowe polecenie użytkownika wspólny generator opisuje skróty jako
„Ctrl+R, Odczytaj wariant i ustawienia stołu.”, bez „Naciśnij” i „aby”.
Dotyczy powiązań gry, akcji stołu, zaproszeń, listy stołów i pomocnika Ctrl+F1.
F1 oraz aktualne skróty w zasadach czytają te same opisy. Nie zmieniono
handlerów, klawiszy, kolejności, listy dostępnych działań ani pomocy ELTEN-a
poza Game Roomem. Zachowano istniejące tłumaczenia nazw akcji; nie trzeba
przebudowywać katalogu tłumaczeń dla samej zmiany formatu.

## Weryfikacja i ograniczenia

Wyniki: `../diagnostics/server-clock-20260919/RESULTS.json` względem repozytorium.
59 celowanych uruchomień: 58 poprawnych, jeden zastany problem referencji pomocy.
Składnia wszystkich 62 zmienionych/dodanych plików Ruby i kontrola diff poprawne.
`rules_shortcut_reference_test` odrzuca zbiorczy wpis Tab/Shift+Tab w instrukcji
Krowy, dodany w poprzedniej lokalnej redakcji. Ten wpis nie był modyfikowany
w bieżącej poprawce. Nie uznano tego testu za zaliczony ani nie osłabiono
jego asercji. Oddzielne testy nowego formatu F1 i cyklu otwierania zasad przechodzą.

Nowe regresje obejmują przesunięcia zegara o godziny/dni, zmianę czasu w trakcie
działania, brak połączenia, odzyskanie czasu, brak blokowania odczytów przez
HTTP, duplikaty i obie kolejności potwierdzeń, dwa widoki historii, stare
archiwa, pełny przebieg pytania Quizu i granice jego pauzy oraz dzienną Krowę.
Ponowiono testy transportu i odzyskiwania, zapisy 15 gier, limity, aukcje,
filtry kontaktów, zaproszenia i poprzednie poprawki UI. Binarne źródła oraz
prawdziwy słownik ELTEN-a sprawdzono w PL/EN/fallback.

Starszy test błędów sieciowych uaktualniono do faktycznie istniejącej ścieżki
prywatnego zaproszenia i wpisu historii zamiast nieistniejącego osobnego alertu.
Test zapisu oddziela metadane nowej sesji od stanu gry i dodatkowo sprawdza
zachowanie czasu gry po wznowieniu, także dla replayów bez stanu.

Nie uruchamiano pełnego runnera, żywych klientów, prawdziwej rozgrywki ani
odsłuchu. Odczyt podpisanej paczki służył tylko sprawdzeniu, że pozostała
niezmieniona: SHA-256 `f39358303db650b3e30a97bcf9d324a3edc5bb17a23aa55aa5d2253015b31b99`.
