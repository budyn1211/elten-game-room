# Tasowanie ELTEN-a i świeża lista przy wejściu na widget

17 września 2026. Poprawki po poprzednim podpisanym 2.0/build 227.
Po zakończeniu prac użytkownik zlecił przebudowę i podpisanie tego samego
buildu, bez zmiany wersji i changelogu, bez instalacji ani publikacji.

## Tasowanie

ELTEN w src/ri/__ri.rb definiuje Array#shuffle i shuffle! bez argumentów.
Scrabble przekazywało random: przy rozdaniu i wymianie, Taboo przy
przygotowaniu talii (również po jej wyczerpaniu). Stąd ArgumentError;
testy w zwykłym MRI bez hostowych nadpisań go wcześniej nie wykrywały.

Trzy wywołania korzystają teraz z GameRoomRandom.shuffle(values, random:).
To deterministyczny Fisher–Yates, taki sam kierunek zamian jak w istniejących
pomocnikach karcianek i kostek. Ziarno nadal pochodzi z zapisanego zdarzenia.
Test porównuje wynik z dotychczasowym MRI shuffle i dalsze losowania z tego
samego generatora, ważne m.in. dla wyboru zaczynającego w Scrabble.
Nie zmieniono innych gier, zasad, zdarzeń, wersji zapisów ani hostowego Array.

Dodano testową symulację bezargumentowego Array#shuffle, odrzucającą również
niebezpieczny pomysł użycia go bez ziarna. Obejmuje testy Scrabble, Taboo
i binarne ładowanie. Obowiązek takiej weryfikacji i używania pomocników
zapisano w AGENTS.md, nie tylko w tym raporcie.

## Porównanie widgetu

W wersji sprzed tego tematu (lib/game_room_widget.rb z HEAD/build 226)
focus najpierw wywoływał loader, ten uruchamiał zadanie ELTEN-a, a dopiero
po wyniku następowało super i odczyt natywnej listy. Błędem było uznawanie
wewnętrznego fokusu przy strzałkach za wejście, ograniczane tylko 0,5 sekundy.

Zmiana na pracę w tle odczytywała listę przed pobraniem. Pierwsza poprawka
usuwała fałszywy brak stołów dla pustej pamięci, ale nie odczyt zamkniętych
stołów z poprzedniej wizyty. Dokładnie to odtworzono na kodzie z paczki
o SHA-256 f5097d11bea9bbd01a122e14a6ce9278e41bd04dd7642dd6223ce84dc2878fd7.

Przywrócono pierwotną sekwencję przy rzeczywistym wejściu: standardowe zadanie
ELTEN-a pobiera aktualną listę, potem zastąpienie pozycji i natywny odczyt.
Nie ma najpierw starego stołu, a następnie drugiego odczytu. Na wolnej sieci
trzeba poczekać na odpowiedź jak dawniej; nie obiecujemy zerowego czasu sieci.
Zadanie nie jest ręczną pętlą UI ani nowym transportem.

Strzałki nie uruchamiają pobierania. Co pięć sekund tylko na aktywnym widgecie
i pod R pozostaje ograniczone pobieranie w tle. Okresowe odświeżenie nie mówi
ponownie, nie zmienia fokusu i zachowuje bieżący wybór. Żądania są szeregowane;
wcześniejsza odpowiedź nie nadpisuje nowszego wejścia. Przy błędzie wejścia
odczytywany jest błąd, nie zapamiętany stół; zachowano ochronę przed zbyt
częstymi próbami po błędach i ograniczeniu żądań. Po opuszczeniu widgetu
rozpoczęta operacja może się dokończyć, ale nie są zlecane następne.

## Weryfikacja i granice

12 skryptów celowanych przeszło: seeded_shuffle, scrabble, scrabble_surface,
taboo, taboo_surface, taboo_network, new_games_2_announcements,
packaged_rules_encoding (binarne źródła), widget_fresh_entry, widget_loading,
widget_concurrent_entry, game_room_settings_widget. Sprawdzono składnię
15 plików Ruby i diff check. Odtworzono stary błąd tasowania z gotowej
paczki oraz zamknięty stół odczytywany przed odświeżeniem.

Testy widgetu uwzględniają rzeczywisty moment odczytu przez ListBox#focus,
odpowiedzi gotowe i jeszcze wykonywane podczas powrotu, puste listy, błędy,
R, kursor, sto strzałek bez nowych żądań oraz jeden rzeczywisty wątek roboczy
z synchronizowanym wejściem. Taboo ma symulację pięciu klientów, nie nową
partię na pięciu rzeczywistych kontach.

Raport poza repozytorium: diagnostics/shuffle-widget-entry-227/RESULTS.json.
Nie uruchomiono pełnego runnera ani nowych prób żywego UI/serwera.
Poprzednia paczka o SHA f5097d11… nie zawiera tych zmian; jest zachowywana
jako ELTEN-Game-Room-build-227-before-shuffle-widget-entry-fix-signed.eltsetup.
Osobna kontrola nowej podpisanej paczki obejmuje podpis autora, manifesty,
zgodność ze źródłami, niezmieniony changelog i katalog PL.mo oraz binarne
wczytanie z symulacją bezargumentowego shuffle ELTEN-a. Wynik tej kontroli,
SHA i rozmiar: diagnostics/shuffle-widget-entry-227/PACKAGE.json.
Raport RESULTS.json opisuje wcześniejszy etap źródeł, nie gotowy artefakt.
