# Wspólna obsługa kursora ręki — build 213

Zmiana dotyczy wyłącznie oznaczonych kontrolek ręki. Nie obejmuje plansz,
kości, odpowiedzi, czatu, historii ani zwykłych list używających technicznie
klasy CardTable. Nie zmienia zasad, transportu, wykonywania ruchów ani mowy
zdarzeń innych gier. Wersja pozostaje 1.1.6.

## Zachowanie

- Po zagraniu karty: najbliższa pozostała karta powyżej. Jeśli nie ma takiej,
  następna poniżej. Dla A B C D: zagranie D wybiera C, B wybiera A, A wybiera B.
- Po zagraniu pakietu pomijane są wszystkie usunięte karty.
- Dobranie ma pierwszeństwo przed zagraniem w tej samej aktualizacji; wybierana
  jest ostatnia faktycznie otrzymana karta, nie ostatnia według sortowania.
- Bez jawnie wybranego sortowania zachowany jest porządek pozostałej ręki,
  a nowe karty są dopisywane na dole. Sortowanie UNO pozostaje aktywne.
- Odczyt dotyczy tożsamości nowej karty pod kursorem. Nie dodaje etykiety
  „dobrano”; obejmuje też zmianę na inną kartę o identycznej nazwie.
- Niezmieniona ręka, ruch innej osoby i techniczne odświeżenie nie powtarzają
  odczytu. Gdy aktywny jest czat, historia albo inne pole, nie ma odczytu ręki,
  przejęcia fokusu ani zaległego komunikatu po powrocie do ręki.
- Nowe rozdanie nie jest traktowane jak dobieranie. Przygotowany pakiet lub
  wybór sposobu zagrania nie przechodzą do następnego rozdania.
- Zwykła aktualizacja ręki zachowuje istniejącą listę i formularz. Faktyczne
  przejścia faz zachowują dotychczasowe znaczenie i obsługę końca partii.

## Nowe gry

Logika jest raz w `lib/game_surfaces/card_hand_cursor.rb`. CardTable i
PacketCardSurface używają jej wspólnie. Nowa gra korzysta z tych kontrolek
(lub pomocnika `CardGame#card_hand_surface`) i podaje:

- unikalne, stabilne `Card#id` dla fizycznych kart, także duplikatów;
- `hand_order`: identyfikatory w rzeczywistej kolejności ręki, z dobranymi
  kartami dopisanymi na końcu, niezależnie od prezentowanego sortowania;
- `hand_epoch`: tożsamość właściciela i rozdania, zmieniana przy nowym rozdaniu;
- normalne etykiety, wartości akcji i ewentualne klucze sortowania.

Nie trzeba kopiować sterowania kursorem, odczytu ani obsługi odświeżenia.
`hand_order: nil` oznacza zwykłą kontrolkę poza tym mechanizmem. Na przyszłość
nie oznaczać nim talii publicznej, list akcji lub kości. Zmiana samego właściciela
oglądanej ręki także wymaga innego `hand_epoch`.

Adnotacje istnieją w UNO, Ninety-Nine, Spades, Tysiącu, Makao i ręce do wymiany
w Pokerze. Poker nadal przechodzi po potwierdzeniu wymiany do następnej fazy:
nie dodano nowej listy ręki do licytacji ani automatycznego czytania kart w menu
zakładów. Widok końcowy również nie jest nadpisywany odczytem ręki.

GameRoomLayout ponownie wykorzystuje tylko oznaczoną rękę, także przy
otaczających ją dodatkowych polach. GameScreen kolejkuje komunikat wybranej
karty bez przerywania wcześniej ogłoszonych zdarzeń. Pozostałe powierzchnie
nie zwracają takiego komunikatu i korzystają z dotychczasowej ścieżki.

## Sprawdzenia

`test/card_hand_cursor_test.rb` obejmuje zagrania, pakiety, dobieranie,
oba kierunki sortowania, duplikaty, nowe rozdania, wybory karty, ponowne
wykorzystanie kontrolek, przejścia złożonego widoku, czat i izolację innych gier.
`test/uno_sort_order_test.rb` sprawdza pełną klasyczną talię, kierunki, zachowanie
wybranej karty i przywrócenie kolejności. Celowane testy istniejącego UI,
karcianek, kości, plansz oraz binarnego ładowania chronią wspólny szkielet.
Nie jest to test instalacji ani rozgrywki na rzeczywistych klientach.
