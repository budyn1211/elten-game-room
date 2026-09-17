# Powiadomienia o stołach i pierwszy odczyt widgetu — build 227

Późniejsze zgłoszenie odczytu zamkniętego stołu przy powrocie Tabem
i przywrócenie pierwotnej kolejności pobrania/odczytu opisuje
`SHUFFLE_WIDGET_ENTRY_227_FIXES.md`. Opisane tam poprawki zastępują
opis wejścia na widget poniżej; naprawa powiadomień pozostaje bez zmian.

17 września 2026. Poprawki na zgłoszenie użytkownika, bez zmiany wersji
2.0/build 227 i bez zmiany changelogu PL/EN.

## Potwierdzona przyczyna powiadomień

Serwer LiveSessions zwraca nieprzezroczyste identyfikatory złożone z liter,
cyfr, `-` i `_`, a odbiornik Game Roomu wymagał UUID. Powiadomienie dochodziło
z poprawnym nadawcą i kompletnymi danymi, lecz walidacja odbiorcy je odrzucała.
Mapowanie zwracało pusty tytuł i treść. `suppress_default!` wycisza ogłoszenie,
ale nie usuwa pozycji z listy głównego ekranu ELTEN-a.

Wcześniejsza próba sieciowa i testy używały sztucznego UUID. Potwierdzały
transport, ale nie format identyfikatora prawdziwego pokoju — stąd luka.
Odczytany schemat tabel był prawidłowy; zmiana `protected` nie naprawia tego
błędu aplikacji. Preferencje testowego konta faktycznie obejmowały grę 99.

Teraz odbiornik dopuszcza ograniczony długością token URL-safe, bez wymuszania
układu UUID. Otwarcie nadal sprawdza dokładną sesję, ID stołu, grę, właściciela,
publiczną dostępność i ważność. Nie nadaje uprawnień do prywatnych stołów.
Nieaktualny lub odfiltrowany wpis ma czytelną treść zastępczą bez dźwięku
i akcji dołączenia, zamiast pustej pozycji do czasu sprzątnięcia.

Za osobną zgodą wysłano dokładnie jedno kontrolne powiadomienie z konta
deweloperskiego na konto testowe. Odtworzyło odrzucenie i pustą treść w starym
kodzie. Ten sam przechwycony pakiet, odtworzony w chwili doręczenia z nowym
odbiornikiem w odizolowanym obiekcie, daje „Nowy stół: 99, papierek”, akcję
`open_new_table` i pojedyncze wywołanie dźwięku notice. Powtórzenie jest ciche.
Usunięto tylko kontrolny wpis. Nie zmieniano preferencji, tabel, pokojów ani
zainstalowanego Game Roomu. To nie był test dołączenia do rzeczywistego stołu.

## Widget

Wcześniej pusta tablica przed ukończeniem pierwszego żądania miała etykietę
„Brak pasujących stołów Game Roomu”. Teraz oznacza wczytywanie. Po pierwszym
wyniku z pustej listy widget odczytuje znaleziony stół albo potwierdzony brak
stołów, tylko gdy nadal jest aktywny. Przy powrocie gotowy wynik jest stosowany
przed odczytem fokusu, bez podwójnego komunikatu. Błąd lub brak odpowiedzi nie
jest utożsamiany z pustym wynikiem; poprzednie niepuste dane pozostają.

Zachowano odświeżanie po wejściu, pod R i co pięć sekund wyłącznie na aktywnym
widgecie, jedną operację naraz, brak pobierania od strzałek, bieżącą pozycję
kursora i ciszę podczas okresowego odświeżania. Dodano tylko tłumaczenie błędu
pobierania; teksty changelogu nie uległy zmianie.

## Sprawdzenie

Nowe regresje najpierw odtworzyły oba błędy na poprzednim kodzie. Kontrola
obejmuje rzeczywisty format tokenu, walidację, duplikaty, dźwięk i mapowanie,
wygasanie oraz dołączanie, pierwsze/ponowne wejście na widget, powolną i pustą
odpowiedź, błędy, powrót z innej zakładki i zachowanie kursora. Test binarnego
wczytania obejmuje także nowe powiadomienia i polską etykietę wczytywania.
Dokładne wyniki i kontrola podpisanej paczki: poza repozytorium,
`diagnostics/table-notice-widget-227/`. Bez pełnego runnera, instalacji,
publikacji i zmian na GitHubie.
