# Wdrożenie poprawek po 228

18 września 2026: wdrożenie w źródłach i testy celowane zakończone. Zakres:
`POST_228_FIXES_PLAN.md`, punkty 1–12. Skróty sortowania zatwierdzone.
Bez zmiany wersji/changelogu, budowania, podpisywania, instalacji,
publikacji, GitHuba i zmian serwera. Paczka 228 pozostaje niezmieniona.

## Lista kontroli

- [x] 1. Odbiór powiadomień bez blokującego zapisu, pomiary i zabezpieczenia.
- [x] 2. Nazwa powiadomienia: właściciel, gra, pojedynczy typ.
- [x] 3. Język Quiz/Taboo bez przeskoku na zestaw.
- [x] 4. Shift+Enter Makao w pomocy F1.
- [x] 5. Wspólne lokalne sortowanie ręki bez utraty kursora/paczek.
- [x] 6. Diagnoza i poprawka mieszanych języków pomocy Taboo.
- [x] 7. Niezależne, nakładające się efekty, w tym walet i próg w 99.
- [x] 8. Farkle: dźwięk bankowania.
- [x] 9. 99: dźwięk dokładnie 33/66.
- [x] 10. Nowy dźwięk wygranej partii.
- [x] 11. Nowy dźwięk przegranej, także w momencie trwałej eliminacji.
- [x] 12. Tysiąc: dźwięk mariażu dowolnego gracza.

## Powiadomienia

Odbiór nie zapisuje już `seen` na dysku. ELTEN sam pamięta identyfikatory
dostaw i nie odczytuje od nowa istniejącej listy przy uruchomieniu; Game Room
zachowuje dodatkową pamięć w RAM dla stołu. Restart/dołączenie nie tworzy
nowego powiadomienia. Stary plik nie jest kasowany.

Pozostawiono `resolved`: dołączenie lub obsłużenie stołu ma ukryć istniejący
wpis i powstrzymać spóźnioną dostawę dotyczącą tej samej sesji. Ten rzadki
zapis odbywa się w tle. Jeden aktywny zapis i jeden zastępowalny oczekujący
stan, kopia danych, uchwycony kontekst aplikacji i konto, scalanie trwałych
znaczników, najwyżej trzy próby z odstępem pięciu sekund. Błąd zapisu nie
blokuje odczytu ani nie usuwa ochrony w RAM. To zapis best-effort: awaria
dysku lub nagłe zamknięcie procesu może nie utrwalić ostatniego znacznika.

Pierwszy odczyt małego pliku przy inicjalizacji nadal jest synchroniczny
(etap `receipts_startup_read`); nie odbywa się dla każdego odbioru. Pomiary
ostatnich 128 operacji są w RAM, wyłącznie etap i milisekundy. Obejmują
mapowanie, odbiór, wywołanie dźwięku, sprzątanie listy i zapis obsłużenia.
Nie zawierają nazw graczy, treści, ID sesji ani poświadczeń.

Próba syntetyczna z celowo wolnym zapisem 150 ms: dawny blokujący callback
152,093 ms; nowa ścieżka mapowania/odbioru/dźwięku 2,901 ms (mapowanie
1,991 ms, odbiór 0,012 ms, atrapa dźwięku 0,001 ms). Wynik nie jest pomiarem
rzeczywistego dźwięku, dostawy sieciowej ani dwusekundowego incydentu
u zgłaszającego. Usunięto potwierdzoną blokującą operację, nie ogłasza się
rozwiązania wszystkich możliwych przyczyn zawieszania.

Nazwa prezentacji to właściciel i gra, treść to pojedyncze „Nowy stół”.
Native `NotificationPresentation#alert` łączy je w tej kolejności; lista
powiadomień używa tej samej prezentacji. Dołączanie, filtry i ważność bez
zmian. Nie zmieniono mechanizmu zaproszeń ani tabel serwera.

## Interfejs, sortowanie i języki

Zmiana języka aktualizuje tylko listę zestawów w tym samym formularzu.
Fokus pozostaje na języku; zgodny zestaw i pozostałe pola są zachowane.
Sprawdzono rzeczywiste Quiz/Taboo i dodatkową imitację trzech języków,
wspólne/niezgodne zestawy, anulowanie i edycję istniejących ustawień.

Wspólne sortowanie: UNO, Makao, Rummy, Spades, Tysiąc, 99 i ekran wymiany
Pokera. Domyślny układ każdej gry pozostaje bez zmian. Shift+C przełącza
kolor rosnąco/malejąco, Shift+H rangę, Shift+M przywraca kolejność otrzymania.
W talii standardowej: kier, pik, karo, trefl; rangi 2–10, walet, dama, król,
as, następnie jokery. Ranga nie jest siłą ani punktami karty, także w Tysiącu.
UNO zachowuje własny porządek i Shift+D. Rummy zachowuje dotychczasowe klucze
(as na początku według jego wartości) i Shift+D do stosu odrzuconych.
Nie zmieniono Shift+C w Biblios ani podglądów licytacji Pokera.

Sortowanie jest wyłącznie lokalne, bez akcji sieciowej. Zachowuje fizyczną
kartę pod kursorem, zaznaczenia i kolejność tworzenia paczki/układów.
Nowe karty trafiają w odpowiednie miejsce, a kursor na ostatnią dobraną.
Z/Shift+Z korzysta z widocznej kolejności. Nie dodano odczytu „Twoja ręka”.
Wybór koloru UNO nie udostępnia sortowania listy kolorów.

F1 Makao opisuje Shift+Enter i Enter przez rzeczywistą kontrolkę paczki;
Poker otrzymuje osobny opis wymiany. Opisy PL/EN bez duplikatów.

Taboo: odtworzono brak tłumaczenia dwóch akapitów ze znakami Unicode
w rzeczywistym kodzie słownika ELTEN-a. Klucze MO są binarne, a źródło
deklaruje UTF-8. Lokalny `GameRoomRules.translate` ponawia wyłącznie
nieznaleziony nie-ASCII klucz jako bajty i normalizuje wynik do UTF-8.
Nie zmieniano globalnego gettext. Wszystkie dawne tłumaczenia pozostają;
dodano tylko cztery etykiety pomocy paczki/wymiany. Obie sekcje Taboo
działają w języku interfejsu niezależnie od języka kart.

## Dźwięki

W 99 efekt waleta/zmiany kierunku, przekroczenia progu, dokładnego trafienia
33/66 i wyniku są wybierane niezależnie. Przejrzano pozostałe selektory;
nie usuwano rozróżnienia wzajemnie wykluczających się akcji. Nie dodano
pauz ani wzajemnego wyciszania. Zachowano deduplikację zdarzeń.

Dodano pięć wskazanych plików, zweryfikowanych względem źródeł i sum z planu:
`farkle_bank`, `ninety3366`, `1000_mariage`, `win_party`, `lose_party`.
Bankowanie i mariaż wymagają zaakceptowanego zdarzenia. Wynik całej partii
używa nowych efektów zamiast win2/lose3; win1/lose1 dla rund bez zmian.

Przegrana odtwarza się przy trwałej eliminacji w UNO, Rummy, 99, Monopoly,
Domino/Mexican Train i Pokerze, także drużyny. Nie ponawia się przy końcu
tej samej partii. No Mercy tylko w rundzie, pokerowy all-in, pas i rozłączenie
nie oznaczają eliminacji. Końcowa wygrana/remis ma pierwszeństwo przed
przekroczeniem limitu w tym samym zdarzeniu. Odtworzenie historii jest ciche.
Wszystkie nowe efekty podlegają głośności gry i wspólnej oraz wyciszeniu.

## Weryfikacja

23/23 wybrane skrypty testowe, składnia 37 zmienionych/nowych Ruby oraz
`git diff --check` poprawne. Wyniki: `../diagnostics/post-228-fixes/TESTS.json`
(względem katalogu repozytorium). Binarne wczytanie źródeł, rzeczywisty
lokalny słownik ELTEN-a, PL/EN oraz rosyjski opis hosta; test opcji obejmuje
72 formularze, 276 stanów pól wyboru i 720 etykiet. Test Quizu uaktualniono
o istniejącą wspólną sekcję opóźnienia botów i serializację opcji zamiast
nieaktualnego limitu 256 znaków dawnego transportu.

Bez pełnego runnera, odsłuchu nowych efektów w żywym mikserze ani dostawy
rzeczywistych powiadomień. Bez budowania i testowania nowej paczki:
podpisana 228 ma nadal SHA-256
`1534481cdd62043022f4eb4d51792a6fd8eb15f1bb262d4f5d2ded25c09d2922`.
Wersja 2.0/228, API 3.0.3, dokument i moduł changelogu bez zmian.

Następne polecenie użytkownika: po tym etapie przepisać zasady wszystkich
gier na przystępniejsze, z porównaniem źródeł i kodu oraz wspólną listą
skrótów z F1. Ten osobny etap opisuje `RULES_REWRITE_PROGRESS.md`.
