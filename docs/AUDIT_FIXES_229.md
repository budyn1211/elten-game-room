# Poprawki po audycie 2.0.1/build 229

18 września 2026. Zmiany w źródłach, bez nowego wydania.

## Zakres zatwierdzony przez użytkownika

Naprawiono potwierdzone błędy z listy 1–12. Punkt 2 (F11) po rozmowie
z użytkownikiem nie był już błędem: celowa kontrola dostępu do tabel
pozostaje bez zmian. Nie wdrażano optymalizacji O01–O04, innych propozycji
ani wcześniej odłożonych ograniczeń. Poniżej zachowano numerację listy
użytkownika i identyfikatory raportu audytu.

| Punkt | Audyt | Poprawka |
| --- | --- | --- |
| 1 | F02 | Nowy ruch nie otrzymuje czasu wcześniejszego niż zaakceptowany stan. Ekran przelicza dostępny czas serwera na wspólną oś czasu partii; między aktualizacjami używa zegara monotonicznego. Nadal obowiązują identyfikator tury, wersja stanu i dokładna granica timeoutu. |
| 2 | F11 | Bez zmian: zamierzona blokada funkcji wymagających dostępu do tabel. |
| 3 | F12 | Przejściowy błąd pobrania odbiorców nowego stołu nie usuwa ogłoszenia, którego jeszcze nie wysłano. Ponowienie po przerwie, do wygaśnięcia; zamknięcie stołu i zmiana konta nadal anulują zadanie. |
| 4 | F06 | Decyzja o zaproszeniu jest oddzielona od dostawy odpowiedzi. Niewysłana odpowiedź trafia do ograniczonej kolejki ponowień w tle; duplikaty rozpoznaje dotychczasowa tożsamość zaproszenia. |
| 5 | F07 | Ctrl+R na liście stołów pobiera definicję wybranej gry, zamiast odwoływać się do nieistniejącej zmiennej. |
| 6 | F08 | Gdy wybrany stół zamknie się podczas dołączania, sprzątane jest jego powiadomienie; nie występuje dodatkowy wyjątek niezdefiniowanej zmiennej. |
| 7 | F01 | Właściciel-obserwator może zapisać i wznowić grę. Właściciel zapisu pozostaje oddzielny od miejsc grających; po odtworzeniu nadal obserwuje, a oryginalni gracze otrzymują swoje miejsca. |
| 8 | F09 | Błąd walidacji ustawień nie odtwarza formularza od zera: wpisane wartości, zaznaczenia, prywatność i fokus pozostają dostępne do poprawienia. |
| 9 | F05 | Planer Tysiąca nie usuwa wszystkich alternatyw tylko dlatego, że ma asa bocznego koloru, którego można przebić atutem. Budżet obliczeń nie został zwiększony. |
| 10 | F10 | Heurystyka Tysiąca i obserwacja bota liczą ujawnione karty wyłącznie od ostatniego rozdania. |
| 11 | F03 | D w Chińczyku pamięta ostatni poprawny rzut również po automatycznym przejściu kolejki; nowa partia zeruje ten odczyt. |
| 12 | F04 | Wynik końcowy pozostaje w historii, ale jego identyczny automatyczny odczyt nie jest powtarzany przez opis ruchu i wspólną obsługę wyniku. Mankala nie ogłasza następnej tury po zakończeniu gry. |

## Czas i bezpieczeństwo ponowień

Nie zwiększano tolerancji dla starych zdarzeń i nie wyłączano walidacji.
Nie zmieniono formatu komend sieciowych ani archiwów. Pomocniczy znacznik
początku pochodzi z metadanych natywnego wpisu. Gdy odpowiedź na zapis
zawiera tylko numer wpisu, stosowane jest tymczasowe oszacowanie czasu
serwera. Późniejsze metadane zastępują oszacowanie, bez ponownego wykonania
zdarzenia. Odczyt zegara nie wykonuje dodatkowych żądań HTTP.

Zapis zamrożonej partii przelicza czas serwera na tę samą oś co ruchy.
Wznowienie nie zeruje ani nie przesuwa pozostałego limitu. Stare repozytoria
bez metadanych zachowują ścieżkę zgodności. Przy braku jakiejkolwiek próbki
czasu hosta nadal potrzebny jest lokalny punkt początkowy; nie deklarujemy
idealnej synchronizacji podczas dowolnie długiej awarii ani naprawy wszystkich
historycznych, już rozbieżnych zapisów.

Odpowiedzi na zaproszenia są ponawiane w pamięci bieżącego procesu,
maksymalnie przez 5 minut, z przerwą 15 s po zwykłym błędzie przejściowym
lub co najmniej 60 s po ograniczeniu żądań. Zmiana konta usuwa cudzą kolejkę.
Limit 500 wpisów zabezpiecza pamięć. Błąd trwały nie jest bez końca ponawiany.
Restart ELTEN-a nie zachowuje tej kolejki. Nie zmieniano prezentacji,
wygasania zaproszeń ani zamierzonej kontroli dostępu do tabel.

Ogłoszenia nowych stołów mają inną politykę niż odpowiedzi: ponawiany jest
bezpieczny odczyt odbiorców. Niepewne wysłanie widocznego powiadomienia nadal
nie jest automatycznie powtarzane; zachowano istniejący wyjątek pojedynczego
ponowienia po jednoznacznym 429.

## Starsze narzędzia do pytań

Sprawdzono powiązania `tools/merge-quiz-pool.rb` (F13) oraz
`tools/refine-quiz-decisions-semantic-safety.rb` (F14). Są ręcznie uruchamianymi
narzędziami z argumentami plikowymi. Nie znaleziono ich wywołań w grze,
obecnej ścieżce przygotowania danych, skryptach wydania ani automatyzacji
projektu. Obecne skrypty importu/audytu korzystają z `quiz-pack-writer`.
Nie oznacza to, że nikt nigdy nie uruchamiał dawnych skryptów ręcznie.

Zgodnie z warunkiem użytkownika nie zmieniano niepodłączonych narzędzi.
Przed ich ewentualnym ponownym użyciem nadal obowiązują ostrzeżenia F13/F14
z audytu. Nie odsiewano pytań, nie uruchamiano narzędzi zmieniających dane
i nie zmieniano pytań, identyfikatorów, map ani sum zestawów.

## Weryfikacja

Nowe testy `audit_229_*` odtwarzają usterki i ich otoczenie: rzeczywiste
callbacki formularza, oba komunikaty wyniku, zapis z ruchem gracza przez
właściciela-obserwatora, pełne wyliczenie końcówki Tysiąca, dwa zegary
różniące się o sześć godzin, granicę timeoutu, zapis/wznowienie, kolejność
potwierdzeń oraz awarie przed dostawą odpowiedzi/odczytem odbiorców.
Istniejące testy obejmują też synchronizację, niepewne zapisy, prywatne
zaproszenia, karty, boty, opcje, Ctrl+F1 i kolejkę dźwięków Statków.

W starym teście Tysiąca uzupełniono atrapę karty o istniejące w produkcji
`sort_keys`; brak tego pola po wcześniejszym sortowaniu zatrzymywał test
przed sprawdzaniem planera. Nie zmieniano silnika w celu obejścia testu.

Test startu Quizu wymagał dawnych sześciu sztywnych rozdziałów, sprzecznie
z wcześniej zatwierdzonym przepisaniem instrukcji. Identyczny błąd
potwierdzono w kopii źródeł sprzed obecnych poprawek. Test sprawdza teraz
dwa dokumenty interfejsu (zasady i skróty), zachowując kontrolę niepustych
treści. Nie zmieniano zasad Quizu ani zawartości zestawów.
Ten sam stary test nadal zakładał limit 256 znaków dawnej kolumny tabeli.
Zastąpiono to próbą utworzenia i rozpoczęcia czterech zestawów przez
obecny LiveSessionStore, z kontrolą pełnych pakietów oraz zachowania opcji.

Końcowe wyniki i sumy kontrolne: `../diagnostics/audit-fixes-229/RESULTS.json`.
**59/59 celowanych uruchomień i 25 kontroli składni Ruby zakończonych
poprawnie.** Kontrola różnic nie zgłasza błędów. 579 wcześniejszych plików
zachowało identyczne sumy; wszystkie pozostałe zmiany i nowe pliki mieszczą
się w jawnej liście zakresu. Dane pytań, tłumaczenia, dźwięki, manifesty,
changelog i dotychczasowa podpisana paczka są niezmienione.
Są to testy kodu oraz symulowanego transportu/UI, również z binarnym
wczytaniem Ruby. Nie wykonywano pełnego runnera, prób żywych klientów,
odsłuchu ani wielkiej kampanii partii. Przejście testów nie jest gwarancją
braku wszystkich rzadkich błędów; potwierdza wymienione przypadki.

## Wydanie

Wersja 2.0.1/build 229 i changelog są niezmienione. Nie budowano,
podpisywano, instalowano ani publikowano paczki. Nie zmieniano serwera,
żywych profili ani GitHuba. Dotychczasowa podpisana paczka pozostaje
niezmieniona i **nie zawiera tych poprawek**:
SHA-256 `9d2d6fdd2a326914f2e0529716e4b86a0aa531ab158188b5680d05dfad4fb7c8`.
