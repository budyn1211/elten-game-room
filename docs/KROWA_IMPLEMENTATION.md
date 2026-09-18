# Krowa — wdrożenie PR #10

## Uzgodniony zakres (18 września 2026)

Użytkownik zatwierdził poprawki 1–11 z przeglądu PR #10 oraz wariant B
zapisu: Wyścig i Wieża Słów mają przenosić zweryfikowany sekret do prywatnej
części lokalnego zapisu i odtwarzać go pod identyfikatorem nowej sesji.
Nie zamykać stołu przed potwierdzeniem pełnego zapisu. Nie publikować sekretu
we wspólnej historii ani w publicznym ładunku wznowienia.

Punkt 12 wyłączono na wyraźne polecenie użytkownika: zachować bazę autora
razem z duplikatami, kolejnością i algorytmem wyboru słów.

Podstawa: PR paoscripts #10, commit
50ea3081e6d6e7a59ee63eee8b7809cb643d7e50. Raport przeglądu znajduje się poza
repozytorium w diagnostics/pr-10-review-20260918/REVIEW.md.

Nie zastępować wcześniejszych lokalnych poprawek audytu, Statków ani Mankali.
Najnowsze polecenie zezwala po weryfikacji ponownie zbudować i podpisać
2.0.1/build 229. Zachować dokładnie 28 wcześniejszych punktów changelogu
i dodać tylko jeden opis Krowy z autorstwem **paulinux**, po polsku i angielsku.
Bez pełnego runnera, instalacji, publikacji na ELTEN-ie lub GitHubie,
scalania albo zamykania PR-u. Wcześniejsze niewydane poprawki audytu
pozostają w źródłach i wejdą do tej samej paczki.

## Kontrola zakresu

- [x] 1. Opcjonalne rankingi, wstrzykiwany dostęp do tabel, obsługa niedostępności.
- [x] 2. Cykl klienta, galeria/ustawienia/definicje, dzienne rozpoczęcie,
      widoczność stołu, dołączanie, role i zaproszenia.
- [x] 3. Pełny zapis i wznowienie Wyścigu/Wieży, bez ujawniania sekretu.
- [x] 4. Bezpieczne błędy lokalnego magazynu, zachowanie sekretu przy ponowieniu.
- [x] 5. Prywatne ujawnienie po poddaniu, z walidacją i ponowieniem dostawy.
- [x] 6. Rzeczywista data Warszawy oraz spójny zegar Wyścigu.
- [x] 7. Współzwycięzcy i dźwięki wyniku.
- [x] 8. Audio respektujące wspólne przełączniki i głośność.
- [x] 9. Trwałe świadome usuwanie własnych słów, bez odtwarzania z historii.
- [x] 10. Odporna na częściowy sukces publikacja Wieży i odczyt rankingów.
- [x] 11. Warunkowa widoczność ustawień, PL/EN, zgodne zasady i pomoc.
- [x] Tabele: kontrola zastanego schematu i wyłącznie cztery nowe tabele Krowy.
- [x] Celowane regresje, binarny runtime, wieloklientowe scenariusze symulowane.
- [x] Kontrola zakresu względem checkpointu; baza słów identyczna z PR.

## Stan

Wdrożono zakres 1–11. Kod pozostałych gier, dane quizowe, stare nagrania,
istniejąca kontrola dostępu do tabel i naprawy poprzedniego audytu nie są
zastępowane wersjami z PR-u. Powtórzenia słownika pozostają celowo:
98 170 wpisów, 84 865 różnych słów. Osiem nagrań oraz źródła wyboru słowa
są porównywane bajtowo z zatwierdzonym commitem autora.

Testy `krowa_*` obejmują cztery warianty, odrzucenia prób, współzwycięzców,
precyzję zegara, dzień Warszawy, błędy dysku, ponowienia i utratę potwierdzeń,
prywatne adresowane wiadomości oraz zapis/wznowienie na nowym stole.
Osobny scenariusz przechodzi przez rzeczywiste repozytorium i symulowany
natywny stos: zapis, zamknięcie starego stołu, nowa sesja, import u drugiego
gracza, następna próba i jej sprawdzenie bez ujawnienia sekretu publicznie.
Interfejs sprawdzono z Enter, Ctrl+D, galerią, własnymi słowami i zachowaniem
tekstu/czatu. Binarne wczytanie obejmuje PL/EN/fallback, prawdziwy słownik
ELTEN-a, polskie znaki i parser definicji na kontrolowanym materiale.

Powtórzono celowany zakres poprzedniego audytu i wspólnych elementów.
Próba dostępu deweloperskiego wykryła konieczność zachowania bramki
uprawnień do zaproszeń przed odczytem opcji konkretnej gry; poprawiono
kolejność, nie osłabiając samej kontroli ani oczekiwań testu.
Końcowe wyniki, skróty wszystkich źródeł i zakres zmian są w
`../diagnostics/krowa-implementation/SOURCE.json`.
Ostateczne dane podpisanej paczki oraz kontrole jej binarnej zawartości:
`../diagnostics/krowa-implementation/PACKAGE.json` (tworzony po pakowaniu).

## Serwer i granice weryfikacji

Po potwierdzeniu przez użytkownika konta deweloperskiego `papierek` dodano
cztery tabele: `krowa_daily_completions`, `krowa_word_scores`,
`krowa_tower_scores`, `krowa_tower_rounds`. Zachowano zastane cztery tabele
(w tym wcześniejszą diagnostyczną), flagę `protected` oraz powiadomienia.
Świeży odczyt schematu i zerowej liczby rekordów potwierdził wykonanie;
dowód: `../diagnostics/krowa-implementation/SERVER.json`. Nie wykonywać
ponownej migracji ani usuwać zastanych tabel na podstawie tego dokumentu.
Nie zapisywano próbnych rankingów ani blokad dnia na żywych kontach.

Nie wykonano ręcznej rozgrywki na żywych klientach, odsłuchu ani pełnej
weryfikacji językowej bazy. Symulacje nie są dowodem działania rzeczywistej
dostawy sieciowej w każdych warunkach. Sekret jest prywatny wobec innych
zwykłych graczy, ale zna go klient gospodarza. Rankingi i blokada dzienna
nie stanowią zabezpieczenia przed celowo zmodyfikowanym klientem.

Przed publikacją pozostaje uzyskanie informacji o pochodzeniu i warunkach
dystrybucji słownika oraz nagrań autora. Brak tych informacji w PR nie jest
stwierdzeniem naruszenia licencji.
