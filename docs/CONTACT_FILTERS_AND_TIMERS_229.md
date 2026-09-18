# Niewydane poprawki po 2.0.1/229

Stan na 18 września 2026. Użytkownik wstrzymał budowanie i podpisywanie,
ponieważ dopisuje kolejne zmiany. Numer wersji i podpisana paczka 229
pozostają bez zmian. Changelog PL/EN uzupełniono na późniejsze polecenie
użytkownika, razem z zapowiedzią tasowania i kolejnością wyników pod S.
Poniższy opis dotyczy źródeł, nie instalatora.

## Kontakty, ustawienia i pomoc

- Nowe filtry „tylko od kontaktów” dla widgetu i powiadomień o stołach są
  domyślnie wyłączone. Filtr zaproszeń korzysta z tej samej pamięci kontaktów.
- Lista kontaktów jest pobierana w tle, oddzielnie dla każdego konta.
  Ważność wynosi 60 sekund; odświeżenie ręczne może wymusić nowe pobranie.
  Po błędzie działają ograniczone ponowienia. Sam odczyt preferencji,
  obsługa powiadomienia lub odświeżenie kontrolki nie czeka na sieć ani dysk.
- Przy zimnej pamięci nowe powiadomienie wymagające filtra czeka na wynik,
  zamiast ujawniać nieznanego nadawcę albo zostać bezpowrotnie odrzucone.
  Zachowano kontrolę rzeczywistego nadawcy, wygasanie, odrzucenie, DND,
  deduplikację i oddzielenie kont. Lista hosta również stosuje filtr.
- Wszystkie 23 instrukcje mają osobne wiersze skrótów pola gry, bez czatu
  i skrótów globalnych. Bieżąca pomoc nadal pochodzi z definicji F1.
- Ctrl+R ma zwięzłe nazwy i jednostki, pomija wyłączone zegary i opóźnienia,
  nie powtarza instrukcji „zero oznacza brak limitu”. Wszystkie 11 zestawów
  Domino są przetłumaczone również w formularzu tworzenia stołu.

## Czas na ruch

Wspólną definicję, walidację i podsumowanie wykorzystują UNO, Makao,
Domino, Mexican Train, Rummy, Scrabble, 99 i Poker. Zegar jest opcjonalny;
domyślnie zero, czyli bez limitu. Mechanizmy Quizu/Taboo i aukcji Monopoly
pozostają osobnymi ograniczeniami właściwymi dla tych gier.

- UNO zachowuje celową karę dobrania po czasie, również po wcześniejszym
  dobrowolnym dobraniu. Oczekująca kara dobierania jest przyjmowana w całości.
- Makao przyjmuje karę dobierania albo stania; w zwykłej turze dobiera jedną
  kartę za czas, także po wcześniejszym dobraniu, i kończy turę. Nie zagrywa
  za człowieka. Powiedzenie Makao i złapanie innego gracza nie odnawia czasu.
- Mexican Train dobiera tylko wtedy, gdy w tej turze jeszcze nie dobierano,
  otwiera własny pociąg i pomija turę. Obowiązki zamykania dubletów pozostają.
- Wcześniejsze zasady timeoutów Domino, Rummy i Scrabble są zachowane.

### 99

Limit 1–600 sekund. Po jego upływie gracz traci jeden żeton, słysząc
„Tracisz 1 żeton za przekroczenie czasu.” Pozostali słyszą ten sam fakt
z imieniem gracza. Zdarzenie jest również w historii.

Tura przechodzi dalej w bieżącym kierunku; karty, suma i rozdanie nie są
zmieniane. Zachowano istniejącą zasadę żetonów: zejście do zera nie
eliminuje, dopiero niemożność zapłacenia kolejnej kary. Po eliminacji
następuje prawidłowy wybór gracza lub zakończenie partii. Stare rozdzielone
zdarzenia zagrania i dobrania nadal kończą należne dobranie bez dodatkowej karty.

### Poker — oba warianty

Limit 1–600 sekund na każdą decyzję. Po czasie następuje pas, nawet gdy
można było czekać bez dopłaty. W Pokerze dobieranym limit obejmuje wymianę.

Wyjątek zatwierdzony przez użytkownika: all-in podczas wymiany zachowuje
wszystkie karty, bez wymiany i bez pasa, i nadal uczestniczy w rozstrzygnięciu.
Zachowanie wymuszone czasem nie jest dla bota dowodem celowego zachowania
mocnej ręki. Zwykły gracz podczas wymiany po czasie pasuje.

Przypadki rozliczenia po takim pasie również sprawdzono: niepokryta nadwyżka
wraca do wpłacającego, a pokryte żetony puli bocznej nie znikają, gdy wszyscy
uprawnieni do niej spasowali podczas wymiany. Trafiają do wcześniejszej puli
z pozostałymi uprawnionymi graczami. Suma żetonów jest zachowana.

## Spójność i zgodność

Wspólny `GameRoomTurnClock` zapisuje czas i numer decyzji w krótkiej otoczce
zdarzenia. Reguły konsekwencji pozostają w klasach gier. Nie ma nowych
odpytań sieciowych ani żądania dla każdej karty. Timeout jest jednym
zdarzeniem właściciela; gracze odtwarzają tę samą decyzję. Numer tury,
termin, kontrola autora i deduplikacja chronią przed spóźnionym ruchem
oraz ponownym naliczeniem kary. Kolejny ruch tej samej osoby, np. po walecie
w dwuosobowym 99, również dostaje nowy zegar.

Przy wyłączonym limicie zachowano wcześniejsze wartości zdarzeń i brak pól
zegara w stanie. Włączenie limitu uwzględnia zapis, zamrożenie i wznowienie:
przerwa nie zużywa pozostałego czasu. Zdarzenia mieszczą się w limicie
64 bajtów, także długie rozdanie Pokera i paczka Makao z oboma jokerami.
Nowe stoły używają discovery protocol 6, aby starszy klient nie pominął
nieznanych timeoutów. To nie zmiana schematu serwera.

## Weryfikacja i ograniczenia

- Zestaw wcześniejszych zmian wspólnych: 52/52 skrypty celowane; składnia
  59 zmienionych plików Ruby, idempotencja kompilatora zasad i diff check.
  Wynik: `../diagnostics/contact-help-time-229/SOURCE.json`.
- Dodatkowa grupa zegarów: 8/8 uruchomień, częściowo powtarzających powyższe
  kontrole. Obejmuje oba warianty i cztery struktury licytacji, wymianę,
  all-in, pule boczne, granice czasu, duplikaty, stare zdarzenia, zapis
  JSON, zmianę ID bota, dźwięki i kodowanie po binarnym wczytaniu źródeł.
  Wynik: `../diagnostics/card-timeouts-229/RESULTS.json`.
- Osobny stary `monopoly_uno_poker_208_feedback_test.rb` nadal ma jedną
  nieprzechodzącą asercję: „Mutually beneficial group completion is ignored”.
  Odtworzono identyczny wynik na czystych źródłach HEAD 53f6023 z GitHuba.
  Nie jest to regresja zegarów; ten test NIE jest policzony jako zaliczony.
  Nie zmieniano tutaj strategii wymian Monopoly ani nie rozstrzygano, czy
  nieaktualne jest oczekiwanie testu, czy decyzja bota.
- Poprawiono przestarzałą atrapę karty i odróżnianie C od Shift+C w teście
  99; rzeczywista obsługa tych klawiszy nie została zmieniona.
- Nie uruchamiano pełnego runnera ani testów na żywych klientach. Pomiary
  responsywności filtrów są syntetyczne, nie gwarantują opóźnienia każdej sieci.
- Nie budowano, nie podpisywano, nie instalowano, nie publikowano ani nie
  wysyłano na GitHub. Nie zmieniano kont, serwera i żywych profili. Stara
  podpisana 229 nadal ma SHA-256
  `8f80d6d32ba07e81ffe7475b793b6cbf97ae0365c886b6a38f9921041d01f01c`.
