# Zasady i podgląd ustawień — build 209, 11 września 2026

## Nowe okno

Wspólny `GameRoomRules::Book` nadal przechowuje sekcje, ale przetwarza je
na dokumenty: „Zasady” i „Skróty klawiszowe w grze”. Nagłówki i wszystkie
akapity zasad są w jednym polu tekstowym tylko do odczytu. Ekran nie dodaje
osobnego przystanku Tab ani pozycji listy dla każdego nagłówka. Escape
wraca do listy z zachowaniem wybranego dokumentu.

Przy otwarciu zasad bieżącego stołu trzeci dokument to „Ustawienia tego
stołu”. Zwykła biblioteka zasad, bez konfiguracji stołu, ma dwie pozycje.
Pozostawiono dotychczasowy Ctrl+F1 i jego istniejącą obsługę.

Podgląd jest lokalnym odczytem opcji przekazanych przez ekran stołu/partii.
Nie odpytuje serwera ani nie dodaje timera. Szkielet uwzględnia zależności
`visible_if`, wyświetla tylko prawdziwe checkboxy, nazwy wybranych wariantów,
liczby oraz zaznaczone elementy list wielokrotnego wyboru. Nie używa już
krótkiego podsumowania lobby pomijającego część reguł. Numery drużyn są
prezentowane od 1. W UNO pomija się także zerowy, wyłączony timer/limit
No Mercy; ta zmiana nie ukrywa pól w formularzu konfiguracji.

## Treść

Przeredagowano wszystkie 16 gier: kółko i krzyżyk, czwórki, Reversi, szachy,
warcaby, Chińczyk, Państwa-Miasta, Farkle, Ninety-Nine, Tysiąc, Spades,
Monopoly, UNO, Yahtzee, Poker i Makao. Zrezygnowano ze sztywnego wymogu
sekcji cel/konfiguracja/przebieg/zakończenie/warianty. Tematyczne nagłówki
są dostosowane do gry; kontrola nadal wymaga niepustych zasad i skrótów,
unikalnych identyfikatorów i tytułów.

Opisano zasady faktycznie zaimplementowane, nie zadeklarowano zgodności
ze wszystkimi oficjalnymi wariantami ani QC. Dotyczy to m.in. punktacji
Yahtzee, kart specjalnych UNO, rozliczeń Tysiąca, przestojów Makao i
regionalnej ekonomii Monopoly. Szczegóły 19 plansz Monopoly są wyliczane
z ich profili danych, a nie z ręcznie przepisanej drugiej tabeli. Regionalne
nazwy własne ulic pozostają nazwami własnymi.

Każda gra ma opis własnych skrótów. Wspólne informacje o Tab, F1/Ctrl+F1,
czacie, filtrach i nawigacji historii oraz komendach planszowych są dodawane
raz przez szkielet. Opisy uwzględniają ochronę pisania w polach edycyjnych.
Nowe teksty angielskie i polskie są w źródłach oraz PL.mo; dodatki katalogu:
`locale/game-rules-209-pl.json`.

## Audyt Makao

Własny profil już zawiera cały uzgodniony zestaw: dwa jokery, mieszane kary
dwójek i trójek, kumulację czwórek, zmianę koloru asem, żądania waletem,
uniwersalną damę, atakujące króle, zagranie dobranej karty, liczbę rozdawanych
kart i liczbę kart za brak deklaracji Makao. Żaden z tych przełączników nie
wymagał dodania. Nie zmieniano reguł gry ani gotowych profili.

Gotowe profile blokują niektóre kontrolki w edytorze, ale ich włączone
reguły nadal są prezentowane w podglądzie. Osobna metoda widoczności
podglądu odróżnia to od niedziałającej opcji niewłaściwego wariantu.
Test rzeczywistego formularza konfiguracji sprawdza wszystkie kontrolki,
zapis do lokalnych preferencji i ponowny odczyt po wybraniu profilu własnego.
Domyślnym profilem nowego stołu nadal jest prosty Makao.

## Weryfikacja

Przeszły celowane testy:

- `game_rules_test.rb`: wszystkie 16 gier, dokumenty 2/3, kompletność
  akapitów, opcje boolean/choice/integer/multiple_choice, zależności,
  profile Makao, drużyny oraz dane 19 plansz Monopoly;
- `game_rules_ui_test.rb`: wejście i powrót z każdego dokumentu, liczba
  pozycji/przystanków, tylko do odczytu; cały formularz własnego Makao,
  zapis i odtworzenie ośmiu checkboxów oraz obu wartości liczbowych;
- `game_rules_translation_test.rb`: polskie dokumenty i opcje 16 gier,
  obecność nowych tłumaczeń w MO i zgodność znaczników interpolacji;
- `room_interface_test.rb`, `categories_test.rb`, `new_board_games_test.rb`
  po dostosowaniu oczekiwań dotyczących nowego układu/treści zasad;
- `tools/check-five-game-translations.rb`.

Nie uruchamiano pełnego zestawu projektu ani klientów ELTEN-a. Wcześniejsze
poprawki rozgrywki i botów po 208 przeszły osobne celowane próby opisane
w `MONOPOLY_UNO_POKER_208_FEEDBACK.md`; również wchodzą do paczki 209.

Build 209 zachowuje wersję 1.1.6. Po próbie instalacji użytkownika potwierdzono
konflikt UTF-8/ASCII-8BIT w generowaniu opisu plansz Monopoly. Build 210
zachowuje wszystkie opisane zmiany i naprawia kodowanie danych plansz.
Pozostaje paczką do testów, bez automatycznej instalacji ani publikacji.
