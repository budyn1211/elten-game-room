# Powiadomienia i widget — kontrola 2.0

Uzupełnienie po teście wydania 227: `NOTIFICATIONS_WIDGET_227_FIXES.md`.
Poniższa pierwsza próba używała sztucznego UUID sesji i nie sprawdzała
rzeczywistego formatu identyfikatora pokoju. Poprawka oraz druga próba
opisane w uzupełnieniu zastępują jej wniosek o pełnej poprawności odbiornika.
Widget odczytuje teraz również pierwszy wynik po wejściu na pustą listę;
odświeżenia okresowe nadal są ciche.

17 września 2026. Użytkownik potwierdził konto deweloperskie `papierek`
i mały test z kontem `papiertestowy`.

Dodano `table_watch_preferences` do aplikacji serwerowej
`468f59c5-c9d7-47cd-80f1-1a6fbfd1aa80`. Zachowano bez zmian trzy
dotychczasowe tabele, `tables_protected: false`, właściciela, limit zasobów
i ustawienie powiadomień. Nowa tabela przechowuje username, format i games.
Lista gier jest publiczna; zmienia ją właściciel rekordu.

Próba rzeczywista potwierdziła:

- zapis i odczyt preferencji przez konto testowe, odczyt przez twórcę stołu;
- odmowę zmiany rekordu papiereka przez papiertestowy
  (`apps.tables.row_not_found`);
- doręczenie dokładnie jednego `game_room.table_created` z uwierzytelnionym
  nadawcą papierek do papiertestowy;
- prezentację „New table: UNO, papierek”, akcję `open_new_table`, zapis
  odebrania i brak dźwięku w ponownym mapowaniu;
- usunięcie obu próbnych preferencji, odwołanie testowego powiadomienia
  i przywrócenie wcześniejszych funkcji w kliencie. Nie instalowano paczki.

Test nie dotyczył masowej wysyłki ani dołączania do prawdziwego stołu
z tego ogłoszenia. Te ścieżki sprawdza model lokalny i wspólna, wcześniej
używana ścieżka dołączania. Nie testowano wielogodzinnej pracy ani wszystkich
kombinacji ustawień systemowych dźwięku. Nie naprawiano wygasania zaproszeń.

Testy lokalne obejmują autorstwo, duplikaty rekordów, brak zapisu przy
niezmienionych preferencjach, deduplikację odbiorców i ogłoszeń, termin,
rozliczenie po wejściu, tempo 2/s, 429 i nieponawianie niepewnych zapisów.
Widget pobiera poza UI; wejście/R/5 sekund, nie strzałki. Odpowiedź zachowuje
aktualny kursor; nie ogłasza odświeżenia poza R. Nowe gry dziedziczą
opóźnienie bota 0–5, UNO/Makao nadal domyślnie 1, inne 0.

Końcowa kontrola integracji przeszła, szczegóły:
`IMPLEMENTATION_2_0_VERIFICATION.md`. Terminy nowych ogłoszeń korzystają
z ostatniego czasu serwera odebranego przez hosta, z monotonicznym upływem
między próbkami; dopiero przed pierwszą próbką zastępczo z czasu lokalnego.
Testy obejmują rozjazd i zmianę lokalnego zegara, bez nowych żądań HTTP.
Wydanie/podpisanie paczki zostało wstrzymane przez użytkownika do dodania
kolejnych gier. Nie rozpoczynać go na podstawie starszego planu.
