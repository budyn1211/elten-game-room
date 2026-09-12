# Uwagi po buildzie 208 — lokalna implementacja, 2026-09-11

Przy wdrożeniu nie zmieniono wersji 1.1.6/208 ani istniejącej podpisanej
paczki. Te zmiany wchodzą do kandydata 1.1.6/209 wraz z nowymi zasadami.
Do testów paczki należy rozpocząć nowe partie z tą samą wersją u wszystkich
graczy. Nie instalowano ani nie publikowano automatycznie.

## Monopoly

- Potwierdzona przez użytkownika reguła: ujemne saldo kończy obecną turę,
  również dodatkowy rzut za dublet. Dopiero po kolejce innych graczy dłużnik
  wraca do zarządzania majątkiem i spłaty. Rzut jest niedozwolony do spłaty.
  Dług z karty pobierającej pieniądze poza własną turą nie przejmuje kolejki.
  Wycofano mechanizm `debt_resume` wyrywający kolejkę innym graczom. Księga
  rzeczywiście wypłaconych kwot i niespłaconych długów pozostaje bez zmian.
- `PawnTrackSpec.menus` rozszerza dotychczasową kontrolkę o lokalne listy
  działań. Monopoly deklaruje listy budowania, sprzedaży, zastawu i wykupu;
  kontrolka zachowuje ich tryb i wybór przez identyfikator po odświeżeniu.
  Nie ma nowej pętli UI ani dodatkowej ścieżki zapisu ruchu. Listy odtwarzają
  aktualne legalne działania, znikają po wyczerpaniu możliwości/zmianie tury,
  a Escape zamyka listę zamiast wychodzić z pokoju. Otwarcie z historii/listy
  osób przekierowuje również fokus do pola gry, bez powtórnego odczytu.
- H i pozostałe skróty informują o braku możliwości. Wiersze zawierają nazwę,
  grupę, koszt/przychód i przy budowie/sprzedaży obecny stan budynków (hotel
  opisany jako hotel). Sprawdzenia równej budowy/sprzedaży, pełnej grupy,
  zastawów, gotówki i zapasów banku pozostają obowiązujące.
- Wykup zastawu używa całkowitoliczbowego zaokrąglenia 110%, a nie Float,
  który potrafił pobrać 111 od zastawu 100. Wyświetlanie, walidacja, zapis
  i ocena bota używają tej samej funkcji kosztu.
- **Luxury Tax:** nie odtworzono braku pobrania pieniędzy. Wszystkie 19
  plansz poprawnie potrąca należność i przekazuje ją do jackpotu tylko przy
  odpowiednim ustawieniu. Brakowało osobnego komunikatu: teraz zdarzenie
  podatku ogłasza osobę, podatek, kwotę i saldo (również ujemne). Nie zmieniono
  istniejących kwot ani adaptacji regionalnych zasad. Zgłoszenie braku
  potrącenia na żywym kliencie wymagałoby konkretnego stanu/logów.
- Bot proponuje najwyżej jedną wymianę w swojej turze, a do tego samego
  odbiorcy nie częściej niż co dwa pełne obiegi. Odrzucone dokładne propozycje
  nie są resetowane kolejnym rzutem. To ograniczenia strategii, nie ludzi.
  Korzyść liczona jest dla całego majątku przed/po wymianie, dla obu graczy,
  z rezerwą gotówki odbiorcy. Generator dodaje uzgodnione ceny dzielące
  korzyść z ukończenia grupy. Nadal nie jest to pełny negocjacyjny planer.

## UNO

`bot_delay` to całkowite sekundy 1–5, domyślnie 1. Formularz nie przyjmuje
większej wartości niż dodatni `thinking_time`; czas 0 nadal oznacza brak
limitu. Przed faktycznym ruchem pauza jest ograniczana pozostałym czasem
z sekundą zapasu na wysłanie (więc ustawienie 1/1 nie blokuje każdego ruchu).

Gra deklaruje `bot_move_delay`. Wspólny wykonawca odmierza ją lokalnie na
zegarze monotonicznym dla identyfikatora sesji, aktora i rewizji zdarzeń.
Odświeżenie tej samej pozycji/czat nie rozpoczyna odliczania od nowa.
Dotychczasowy timer formularza wyzwala gotowy ruch; nie dodano `sleep`, wątku,
odpytywania ani pauzy w transporcie. Ruchy ludzi są niezmienione. Domyślna
deklaracja w innych grach wynosi 0, a potwierdzenie poprzedniego ruchu bota
nadal jest wymagane. Nie gwarantuje to wysłania przed czasem przy awarii sieci.

## Poker

Poprzednio check otrzymywał ocenę 0, a podbicie dostawało wartość również
za już istniejącą pulę. To premiowało podbicie przeciętną ręką zamiast
darmowego czekania. Obecnie obie możliwości uwzględniają udział w tej samej
puli. Pasowanie jest minimalnie niżej od zerowego check, co eliminuje losowe
pasowanie bez konieczności wpłaty. Kolejne podbicia dodatkowo obniżają
optymistyczną ocenę szans. Zachowano wycenę call, ryzyko dużych zakładów,
legalne limity, własne kwoty ludzi i symulację bez znajomości cudzych kart.

## Weryfikacja

Nowe testy:

- `monopoly_uno_poker_208_feedback_test.rb`: 9 grup regresji; najpierw
  odtworzono błędy istniejącego kodu, następnie sprawdzono nowe zachowanie.
- `monopoly_management_ui_test.rb`: listy po kolejnych akcjach, ceny,
  równomierna budowa, fokus z listy osób, Escape, wyczerpanie możliwości i
  zmiana kolejki. Korzysta z produkcyjnej kontrolki i lokalnych atrap ELTEN-a.
- `monopoly_poker_bot_208_feedback_test.rb`: prawdziwa strategia i replay
  po każdym ruchu. Monopoly 280 działań, w tym 152 rzuty i 6 ofert (wszystkie
  przyjęte); Texas: 59 check, 32 call, 28 raise, 14 fold, 4 all-in; dobierany:
  26 check, 12 call, 31 raise, 14 fold, 6 all-in, 22 wymiany. Obie partie
  Pokera zakończone; Monopoly to próba ograniczona, nie test zakończenia gry.
- Uzupełniono `bot_turn_controller_test.rb` o gotowość, brak restartowania
  pauzy, anulowanie obliczeń i czyszczenie pauzy przy zmianie sesji.

Przeszły również: 28 regresji pięciu gier, 36 sprawdzeń follow-up (zmieniono
oczekiwania poprzedniej reguły długu i jednorazowej listy), 17 grup po buildzie
207, UI pięciu gier, celowany `new_games_116_test` z flagą FIVE_GAMES_ONLY,
plansze regionalne, wspólna kontrolka, cykl pokoju i wysyłanie botów.
Polskie komunikaty dołączono do PL.mo z osobnego JSON; kontrola tłumaczeń
nie wykazała braków. Pełnego zestawu projektu i klientów ELTEN-a nie uruchamiano.
