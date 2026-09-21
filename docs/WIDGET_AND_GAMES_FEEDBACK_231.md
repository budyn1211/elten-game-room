# Widget i poprawki gier — build 231

21 września 2026. Wdrożono zakres zatwierdzony przez użytkownika oraz później
dodane ręczne przelosowanie słowa Krowy. Następnie użytkownik polecił ponownie
przebudować i podpisać 2.0.2/build 231, uzupełnić changelog oraz autorstwo
Ponga. Wyniki końcowej kontroli i paczki:
`../diagnostics/widget-games-feedback-231/SOURCE.json` i `PACKAGE.json`.
Sam ten dokument nie potwierdza ukończenia podpisywania.

## Widget

Ctrl+N otwiera zwykły wybór gry do utworzenia stołu. Ctrl+1 do Ctrl+0
wywołują dziesięć lokalnych zestawów ustawień. Konfiguracja:
Game Room → Ustawienia → Widget, a następnie Tabem do ostatniej listy
„Skróty tworzenia stołów”. Pozycje Ctrl+1–Ctrl+0 mają informację o przypisaniu
oraz podpowiedź Enter. Enter otwiera wybór gry, a następnie jej opcje
i prywatność. Zatwierdzenie zapisuje przypisanie od razu, z nazwą gry,
bez osobnego okna nazwy. Anuluj w głównych ustawieniach nie cofa tego zapisu,
ale nadal odrzuca inne oczekujące zmiany ustawień. Anulowanie wyboru gry
lub jej opcji nie zmienia przypisania. Usunięcie z menu kontekstowego listy
również zapisuje się od razu. Po operacji pozostaje ten sam skrót na liście.
Nie wykonujemy zapisu podczas przeglądania listy. Późniejsze Zapisz
w głównym oknie nie przywraca starej kopii przypisań.

Skróty działają wyłącznie na widgecie. Korzystają z pierwszego naciśnięcia
oraz dokładnego zestawu modyfikatorów hosta, nie z autorepeat. Pomoc i menu
lokalne nie rejestrują skrótów w globalnym menu ELTEN-a. Otwarty formularz
nie uruchomi drugiej operacji tworzenia.

Zapisujemy ID gry, nazwę, reguły i prywatność, nie stan partii, uczestników,
boty ani dane dostępowe. Nieprzypisany klawisz tylko informuje o braku
ustawień. Nieaktualny zestaw musi przejść edytor; anulowanie nie tworzy
stołu. Prawidłowy zestaw używa wspólnej ścieżki tworzenia, wraz z ochroną
istniejącego członkostwa i zakazem publicznych ogłoszeń prywatnych stołów.
Skrót nie rozpoczyna partii automatycznie. Odświeżanie widgetu przy wejściu,
pod R i co pięć sekund podczas aktywności nie jest zmieniane.

## Chińczyk

- 1 odczytuje własne pionki; 2–4 kolejnych graczy według miejsc przy stole.
  Obserwator zaczyna od pierwszego miejsca. Nieistniejących miejsc nie dodajemy.
- D podaje autora ostatniego rzutu i wynik, także po zmianie tury.
- Shift+V porządkuje pionki wszystkich graczy według numerów wspólnego toru,
  bez grupowania właścicielami. Dalej są ścieżki do domu, bazy i meta.
  Każda pozycja zachowuje nazwę właściciela i numer pionka.
- P, Shift+P, V oraz reguły ruchu pozostają bez zmian.

## Yahtzee

D podaje tylko wartości. Opcja, karta wyników i komunikat premii wskazują
Jedynki–Szóstki zamiast górnej części kartki. Zasady opisują próg 63 punktów
i premię 35 punktów oraz wyjaśniają Jokera bez przestrzennych określeń karty.
Misery jest tłumaczone jako Nędza. Punktacji ani zachowania kości nie zmieniono.

## Makao

Dobranie mimo posiadania legalnej karty jest domyślnie włączone w trzech
gotowych profilach. We własnych ustawieniach nowy checkbox można wyłączyć;
jest zapamiętywany razem z pozostałymi własnymi opcjami.

To jedno dobranie na turę. Pasująca dobrana karta może być zagrana przy
włączonej odpowiedniej regule, a następna Spacja kończy turę bez dobierania.
Niepasująca dobrana karta kończy turę. Nie można w ten sposób ominąć
skumulowanej kary, stania ani limitu czasu. Bot nadal preferuje legalne
zagranie nad zbędnym dobieraniem.

## Mexican Train

Nowy wymagany dublet jest ogłaszany raz. Kolejne pasy nie powtarzają
identycznego obowiązku. Zmiana na wcześniejszy dublet w stosie zobowiązań
jest ogłaszana. Odczyt pod T i komunikat odmowy przy złym pociągu pozostają.
Nie zmieniono zasad kolejności domykania ani wyjątku autora serii.

## Krowa

Losowe słowo otrzymuje przycisk Przelosuj słowo, przed pierwszą próbą
lub później, po rozliczeniu oczekujących prób. Poprzednie słowo ujawnia się
normalną ścieżką, nowe jest losowane bez tworzenia nowego stołu; próby się
zerują. Nie zapisuje to zwycięstwa, galerii ani wyniku rankingu.

Uprawnienie ma grający właściciel, nie obserwator. Przycisk przekazuje
numer rundy, więc spóźnione ponowne zatwierdzenie nie pomija następnego słowa.
Wyścig zachowuje istniejące ręczne przelosowanie właściciela — nie dodano
automatycznego przelosowania. Krowa dzienna i Wieża słów go nie udostępniają.

## Wydanie i sprawdzenie

Changelog PL/EN 231 ma dziewięć punktów i opisuje nowości względem publicznej
230, bez historii błędów testowych Ponga. Zawiera bieżącą ścieżkę przypisań.
Na początku changelogu i zasad Ponga jest ten sam opis pochodzenia:
Dragon-Pong, późniejsze ulepszenia Axela i balteama, port za ich zgodą;
gra nie jest autorskim projektem papierka. Informację o zgodzie na port
przekazał użytkownik. Nie dodano nowych funkcji z niezatwierdzonych części
audytu oryginału. Szczegóły wcześniejszych poprawek:
`PONG_SOURCE_FIXES_231.md`.

Celowane testy obejmują zasady, replay, boty Makao, role i stare zdarzenia
Krowy, rzeczywisty formularz ustawień na atrapach interfejsu, publiczne
i prywatne tworzenie, brak podwójnego uruchomienia, anulowanie, odświeżanie
widgetu i zgodność binarnych źródeł z rzeczywistym słownikiem PL/EN/fallback.
Starsze oczekiwania komunikatów Yahtzee i Chińczyka zaktualizowano do
uzgodnionego brzmienia. Stary test pięciu gier dostał brakujący import
modułu sortowania; asercji reguł nie osłabiono.

Nie wykonywano pełnego runnera, nowej żywej partii, fizycznego testu myszy
ani odsłuchu urządzenia. Osobno sprawdzana jest binarna zawartość paczki,
podpis, manifesty i zgodność z końcowym snapshotem źródeł.
Nie instalować, nie publikować, nie wysyłać na GitHub i nie zmieniać
serwera lub profili w ramach samego polecenia zbudowania paczki.

Uproszczenie edytora skrótów i krótszy changelog z 21 września są zmianami
źródeł po podpisaniu 231 z SHA 79757ec0… . Tej paczki nie przebudowano
w ramach poprawki interfejsu. Test widget_inline_presets odtworzył brak listy
przed zmianą; obejmuje wspólny formularz, natychmiastowy zapis, niezależne
Anuluj/Zapisz głównego okna, obie ścieżki anulowania edytora i cache.
