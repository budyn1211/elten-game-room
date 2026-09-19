# Komunikaty Krowy, Statków i Monopoly — 19 września 2026

Zmiany tylko w źródłach. Bez przebudowania, podpisu, instalacji, publikacji,
GitHuba, zmian serwera lub profili. Wersja i changelog pozostają niezmienione.
Zachowano wcześniejszą poprawkę `Base#bot_move_delay` dla pustego stanu.

## Krowa

Skrócono nazwy do „Liczba liter” i „Kryterium wyniku”. Widoczność, wartości
i domyślne ustawienia pozostają te same. Źródłowy opis zasad oraz Sterowanie
wyjaśniają ukrywanie niepasujących opcji; wygenerowano zasady i tłumaczenia.
Nie zmieniano słownika, duplikatów, doboru słów, rankingów ani dźwięków.

## Statki

Sam wybór losowego/ręcznego rozstawienia już istniał, ale automatyczne
rozpoczęcie partii wchodziło w formularz bez odczytania jego nagłówka.
FleetGrid przekazuje teraz pytanie i bieżący wybór do istniejącej kolejki
odczytu. Lokalne zapamiętanie zapobiega powtarzaniu pytania przy odświeżaniu;
ręczny szkic i działanie innych typów plansz pozostają bez zmian.

Po przyjęciu własnego losowego rozstawienia odczyt brzmi „Twoje statki zostały
rozstawione automatycznie”. Nie ogłasza powodzenia samego naciśnięcia Enter
ani nie opisuje cudzej floty jako własnej. Kanoniczna historia i zdarzenie
z samym zobowiązaniem kryptograficznym pozostają bez zmian.

Potwierdzono osobny błąd: przejście rozstawianie → gra nie wywoływało odczytu
pierwszej tury, gdy `current_player` pozostawał taki sam. Rozróżniono fazę
rozstawiania w lokalnej detekcji tur Statków. Komunikaty trafiają do kolejki
bez przerywania poprzednich. Nie dodano pauz, żądań ani modyfikacji hosta.
Brak pierwszego odczytu odtworzono testem; to nie dowód na przyczynę każdego
możliwego ucięcia syntezy mowy na prawdziwym urządzeniu.

## Monopoly

- Shift+D zawiera grupę nieruchomości, zachowując numer pola.
- Listy posiadłości mówią „grupa 2 z 3”, zamiast „w tej grupie…”.
- Budowanie ogłasza pierwszy, drugi, trzeci lub czwarty dom, a potem hotel.
  Cena i liczba budynków nadal są dostępne na liście operacji.
- V/Shift+V, Enter na nieruchomości otwiera aktualny czynsz. Zakłady podają
  mnożnik przyszłego rzutu; zastaw i ustawienie niepobierania w więzieniu
  dają stosowne wyjaśnienie. Kwoty pochodzą z dotychczasowego silnika czynszu,
  bez zmiany ekonomii, równomiernej budowy lub zasad wymiany.

## Historia czatu

Użytkownik ponownie sprawdził zgłoszenie i nie potrafi potwierdzić braku
własnych wiadomości. Kodu czatu ani historii nie zmieniano. Celowane testy
zapisu własnej wiadomości, scalania historii i nawigacji pozostają poprawne.

## Weryfikacja

Końcowy zestaw: 24/24 celowane uruchomienia bez błędów, poprawna składnia
15 zmienionych/dodanych plików Ruby oraz kontrola diff. Ponowne generowanie
zasad i katalogu tłumaczeń pozostawia identyczne bajty. Odczyt SHA-256
istniejącej podpisanej paczki potwierdza, że nie została zmieniona.

Nowe testy odtworzyły przed poprawkami długie etykiety Krowy, brak grup na
planszy Monopoly, niesłyszalne pytanie o flotę i brak pierwszej tury.
Po poprawkach przechodzą także testy starej obsługi wymian, zarządzania
nieruchomościami, regionalnych plansz i modeli Statków.

`battleship_setup_announcement_test` przechodzi od pustej partii przez
automatyczny start, obie kolejności zgłoszenia flot i początek strzelania.
Symuluje przerywający odczyt fokusu kontrolki, sprawdzając brak takiego
odczytu między komunikatami. Dotychczasowa symulacja odbierania zdarzeń,
czatu i dźwięków Statków również przechodzi.

`property_setup_feedback_encoding_test` sprawdza binarne źródła, prawdziwy
słownik ELTEN-a, PL/EN/fallback, polskie nazwy graczy oraz ścieżkę V → Enter
bez wysyłania ruchu. Testy Krowy potwierdzają zachowanie bazy słów i widoczność
opcji. Sprawdzono też formularze, zasady, składnię i powtarzalność kompilacji.
To testy celowane i symulacje — bez pełnego runnera, odsłuchu i żywej partii.

Podpisana paczka 2.0.1/229 o SHA-256 zaczynającym się od `f3935830` nadal
nie zawiera tych zmian ani wcześniejszej poprawki opóźnienia bota.
