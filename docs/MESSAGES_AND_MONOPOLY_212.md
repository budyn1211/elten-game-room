# Komunikaty pięciu gier, Monopoly i pomoc F1 — build 212

11 września 2026. Wdrożenie zatwierdzonego przeglądu
`MESSAGES_REVIEW_AFTER_211.md` i dodatkowych poleceń użytkownika.
Wersja 1.1.6, build 212. Bez zmian transportu, nowych odpytywań czy migracji.

## Komunikaty

- Monopoly podaje strony i powód płatności, faktycznie przekazane pieniądze
  oraz pozostały dług i jego późniejszą spłatę. Karty wskazują gracza;
  rzut i przemieszczenie poprzedzają skutki pola. Rozróżnione są premie,
  sposoby wyjścia z więzienia, zakup i komplet grupy, handel, aukcja oraz
  odbiorca majątku bankruta. Bez ciągłego dopisywania sald. Krótkie komunikaty
  zarządzania z 211 pozostają; koszty i budynki nadal widać na listach.
- UNO: rzeczywista liczba dobranych kart, bez ujawniania ich tożsamości;
  wskazanie kary/koloru ruletki i adresata, buzzera, wyboru gracza po siódemce,
  stron kwestionowania +4 oraz efektów Flip, zera i odrzucenia koloru.
  „Za późno!” nie odczytuje kary, ale nadal nalicza 3 punkty.
- Poker: krótkie R z własną kwotą i niezmienioną walidacją; G nie nazywa
  wysokiej karty układem, ale rankingi i rozstrzyganie nadal ją uwzględniają.
  All-in podaje bieżącą wpłatę, podbicie rozróżnia „o”/„do”. Opisy wpłat
  obowiązkowych, wygranych i podziałów pul oraz odrzucenia działań są dokładniejsze.
  Cyfry 1–5 w dobieranym odczytują własne karty; Hold'em zachowuje 1–7.
- Yahtzee ogłasza przyznane premie 35 i 100. Bez zmiany punktacji,
  dodatkowych podpowiedzi Jokera ani nowych odczytów sum arkuszy.
- Makao: odrębne znaczenie deklaracji asa, waleta i jokera; właściwy nagłówek
  wyboru, podgląd reprezentowanej karty i pozostałych kolejek postoju.
  P odczytuje faktycznie przygotowany pakiet w kolejności zaznaczenia,
  bez modyfikowania ręki, zaznaczenia i zdarzeń sieciowych.

## Aukcja i bankructwo Monopoly

- B podczas aukcji otwiera pole całkowitej oferty. Kwota musi przekraczać
  aktualną ofertę i mieścić się w gotówce gracza; nie musi być wielokrotnością
  szybkiego kroku. Enter i dotychczasowe szybkie podbicie pozostają.
- Opcja liczby sekund dotyczy jednej decyzji każdego kolejnego licytującego.
  Domyślnie 0 — bez limitu. Opcja jest widoczna przy włączonych aukcjach.
  Po upływie czasu następuje automatyczny pas. Terminy są zapisywane w
  zdarzeniach, a replay nie korzysta z aktualnego zegara. Timeout sprawdza
  gracza, numer decyzji i termin, aby nie spasować kolejnego licytującego
  po spóźnionym albo zdublowanym zdarzeniu.
- Automatyczne bankructwo: własna tura, ujemne saldo, brak legalnej sprzedaży
  budynków i zastawu. Nie uwzględnia możliwości składania ofert handlowych.
  Powstanie długu nadal kończy bieżący ruch; pozostali gracze wykonują swoje
  tury przed kolejną turą dłużnika. Nie zmieniono rozliczenia wierzycieli.

## Pomoc i weryfikacja

Powtarzane odświeżenia zachowanej kontrolki dopisywały te same podpowiedzi.
Wspólny ekran zastępuje teraz aktualne podpowiedzi gry, oddzielnie od menu
kontekstowego i podpowiedzi kontrolki. Nie dodano drugich handlerów skrótów.
Regresja sprawdza pięć kolejnych wiązań tej samej kontrolki, usuwanie
nieaktualnych skrótów i zachowanie pozostałej pomocy.

Przeszły celowane testy pięciu gier, nowych komunikatów, kwot i limitów aukcji,
starych/zdublowanych timeoutów, automatycznego bankructwa, polskich tłumaczeń,
zasad oraz zmienionego wspólnego interfejsu. Cztery niezależne odtworzenia
tych samych zdarzeń aukcji dały ten sam stan i historię. To test w pamięci,
nie próba czterech rzeczywistych klientów. Pełnego zestawu nie uruchamiano.

Szczegóły podpisania i kontroli gotowej paczki:
`../../diagnostics/build-212/README.md` w katalogu całego środowiska.
Do prób używać nowych partii i buildu 212 u wszystkich uczestników.
Nie instalowano ani nie publikowano na ELTEN-ie lub GitHubie.
