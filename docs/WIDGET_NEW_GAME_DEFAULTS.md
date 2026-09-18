# Domyślne zaznaczanie nowych gier w widgecie

Poprawka źródeł po podpisaniu 2.0.1/build 229, 18 września 2026.

## Przyczyna i decyzja użytkownika

Stare ustawienia przechowywały tylko listę zaznaczonych ID w widget_games.
Nowa instalacja zaznaczała wszystkie gry, lecz aktualizacja filtrowała
zapisaną listę i nie dodawała pozycji wprowadzonych w nowszym wydaniu.
Nie zapisywano informacji, jakie gry użytkownik mógł już wybrać. Dlatego
brak zaznaczenia nowej gry był nieodróżnialny od ręcznego odznaczenia.

Użytkownik zatwierdził jednorazowe zaznaczenie Rummy, Domino, Mexican Train,
Scrabble, Taboo i Biblios w takich starych ustawieniach, pozostawiając
wybór wcześniejszych gier bez zmian. Zażądał także domyślnego zaznaczania
każdej nowej gry w przyszłości.

## Działanie

Preferencje zawierają teraz także widget_known_games — ID gier, które
ustawienia już znały. Gdy rejestr gier zawiera nowe ID, normalizacja dodaje
je do wybranych pozycji. Nie zaznacza ponownie gry, która była już znana
i została odznaczona. Nie zależy to od tłumaczenia nazwy ani kolejności listy.

Przy braku informacji o znanych grach zamknięta lista 17 gier sprzed 2.0
stanowi punkt wyjścia migracji. Nie należy powiększać tej listy przy
dodawaniu nowych gier — wystarczy wpisać nową grę do wspólnego rejestru.
Nowa instalacja nadal zaczyna ze wszystkimi grami zaznaczonymi.

Odczyt pozostaje czystą operacją: odświeżanie widgetu, odczyty preferencji
i obsługa powiadomień nie powodują dodatkowych zapisów. „Zapisz” w oknie
ustawień utrwala wybory i znane ID razem w istniejącym zapisie. Dzięki temu
odznaczenie Domino po tej aktualizacji pozostaje skuteczne również po
ponownym uruchomieniu. „Anuluj” nie zapisuje wyborów ani migracji.

Całkowicie wyłączony widget pozostaje wyłączony. Nie zmieniono list lobby,
subskrypcji powiadomień, zaproszeń, dźwięków, prywatności stołów ani sposobu
odświeżania. Profile osobnych kopii programu pozostają niezależne. Nie
edytowano ustawień działających klientów użytkownika.

## Sprawdzenie i wydanie

Test najpierw odtworzył brak sześciu gier przy odczycie starego wyboru.
Po poprawce sprawdza wszystkie nowe gry z 2.0, zachowanie wcześniejszych
wyborów, pustą listę, wyłączony widget, kolejne dwie aktualizacje,
ręczne odznaczenia, ponowny odczyt po zapisie, dwa osobne profile oraz
rzeczywisty przepływ formularza ustawień z atrapą pamięci zamiast dysku.

13/13 skryptów celowanych przeszło, w tym wcześniejsze regresje widgetu,
powiadomień, formularza tworzenia stołu i kodowania. Składnia trzech Ruby
i kontrola diff poprawne. Wyniki: diagnostics/widget-default-games-229/RESULTS.json
w katalogu roboczym poza repozytorium. Nie uruchamiano pełnego runnera
ani testów żywych klientów.

Wersja 2.0.1/build 229, changelog i katalog tłumaczeń pozostają bez zmian.
Podpisana paczka 229 o SHA 0ac85551… jest nietknięta i nie zawiera tej
poprawki ani poprawki formularza prywatności. Nie budowano, podpisywano,
instalowano, publikowano, wysyłano na GitHub ani zmieniano serwera.
