# Integracja PR 15–18 — 25 września 2026

Zmiany włączono do bieżących źródeł wymagających ELTEN 3.0.4, zachowując
wcześniejsze lokalne poprawki. Nie podmieniano całych starszych plików
manifestów, katalogów ani wspólnego szkieletu. To integracja źródeł, nie
nowe wydanie: wersja `2.0.3.1`, build `238` i wymagane API `3.0.4` bez zmian.
Nie przygotowywano paczki. Po zakończeniu prób użytkownik polecił wysłać
wszystkie zmiany źródeł na GitHuba i zamknąć włączone PR-y 15–18.

## Zakres czterech PR

Źródłem były osobne referencje `refs/review/pr-15` do `refs/review/pr-18`.

| PR / głowa | Włączony zakres |
| --- | --- |
| [15](https://github.com/papierek1997/elten-game-room/pull/15), `0f1df2f2` | Czeski interfejs: autorskie CS PO/MO, język `cs` i opis aplikacji. Bez dopisywania czeskich zasad. |
| [16](https://github.com/papierek1997/elten-game-room/pull/16), `cdd01ea4` | Hiszpański interfejs: ES PO/MO, język `es`, opis aplikacji oraz izolowane testy ustawień języka, dopasowane do obecnej kategorii „Ogólne”. |
| [17](https://github.com/papierek1997/elten-game-room/pull/17), `2d424ee2` | Angielska nazwa Tysiąca „1000 card game”: nazwa gry, wstęp zasad, etykieta wariantu i komunikat liczby graczy. ID `tysiac`, zasady i polskie brzmienie bez zmian. |
| [18](https://github.com/papierek1997/elten-game-room/pull/18), `f0ed0055` | Model 3-5-8, rejestracja gry, autorski dokument zasad, mapowanie opcji `card_exchange: exchange`, teksty PL, dźwięki i testy; poniższe poprawki integracyjne i bota. |

Zachowano wszystkie wcześniejsze wartości katalogów: 4521 wpisów CS,
4608 ES i 4646 bieżących PL, bez nagłówków. Dodano dokładnie cztery polskie
wartości z PR17 i 57 z PR18, bez redakcji autorskiego brzmienia. Trzy nowe
klucze nazwy Tysiąca otrzymały istniejące czeskie/hiszpańskie tłumaczenia
starych kluczy; nie cofnięto nowych lokalnych wpisów ani określenia
gospodarza stołu. Odświeżono POT/PO i zgodne MO. Nieprzetłumaczone zasady
CS/ES korzystają ze zwykłego mechanizmu języków zapasowych.

## 3-5-8: zasady autora i obecny szkielet

Zachowano autorskie teksty, komentarze, dokument zasad, rozdawanie,
legalność ruchów, wymiany, cele i punktację. W szczególności obowiązuje
opisany wariant: trzeba dokładać do koloru, ale nie trzeba przebijać ani
atutować przy jego braku. Nie zastąpiono go innym wariantem znalezionym
w sieci. Porównanie wszystkich 75 pierwotnych metod wykazało zmianę tylko
czterech metod strategii; pozostałe 71 są identyczne.

Wartość wymiany `target|card` otrzymała wąskie mapowanie odbiorcy przez
`restored_event_value`, potrzebne przy odtworzeniu archiwum i zmianie
uczestnika. Karta oraz historyczni autorzy pozostają niezmienni.
Reguły dźwięków przeniesiono z dawnej gałęzi `game_sounds` do hooka gry
`event_sound_cues`, zachowując równoczesne efekty zagrania i atutu.
Po zgłoszeniu użytkownika usunięto dwa dodatkowe `ding`: przy wyborze
kontraktu i zerowym wyniku rozdania. Omijały ustawienie „moja kolej”;
teraz ten sygnał emituje wyłącznie wspólny prezenter zgodnie z ustawieniem.
Tasowanie oraz dodatni i ujemny wynik zachowują swoje efekty. Tekstów
i zasad gry nie zmieniono. Test autora dostał jedynie jawny import przeniesionego
wcześniej pomocnika `test/support/sequence_random`.

## Bot: naprawy, ulepszenia i granice

Naprawiono odwracanie celu po osiągnięciu wymaganych lew, nieporównywalne
skale wymuszające pierwszy MISERE oraz odrzucanie bezpiecznych niskich
kart w MISERE. Dodatkowo bot rozróżnia pozycję w lewie, wybiera najtańszą
pewną wygraną, uwzględnia zagrane karty i wykazany brak koloru,
ocenia kształt ręki przy odrzucaniu i potencjał poprawy przy wymianie.
Nie powtarza znanej bezowocnej wymiany do tego samego odbiorcy; wiedza
pochodzi wyłącznie z własnych obserwowalnych wyników wymian i jest
konserwatywnie unieważniana.

Punktem odniesienia były nasze Spades/Tysiąc oraz:

- [World of Card Games — Sergeant Major](https://worldofcardgames.com/how-to-play-sergeant-major): wartość nadlewek, mocny długi atut, boczne asy i wymiany słabych kart. Inna kolejność rozdawania, cele i zakończenie nie zostały przejęte.
- [Helsinki Finnish Club — Handbook of Skruuvi](https://www.klubi.fi/site/assets/files/4612/handbook_skruuvi.pdf), strony drukowane 32–36: ochrona wysokich kart niskimi wyjściami i znaczenie kształtu kolorów w MISERE. Bez przenoszenia zasad partnerstwa lub punktacji.
- [BBO — GIB notes](https://rc.bridgebase.com/doc/gib_system_notes.php) oraz [MobilityWare — Hearts strategy](https://mobilityware.helpshift.com/hc/en/42-hearts-card-game/faq/2627-basic-strategy/?f=scoring&s=gameplay-settings): analogie najtańszej równoważnej wygranej i pozbywania się niebezpiecznych przegrywających kart. Bez symulacji GIB, sygnałów partnera i kar właściwych Kierkom.

To własne, ograniczone heurystyki dla zachowanych zasad, nie algorytm
optymalny udowodniony przez te źródła. Bot korzysta z własnej ręki,
publicznych zagrań i lokalnej projekcji obecnych miejsc; nie odczytuje
cudzych rąk, pełnego rozdania, ziarna ani ukrytych kart. Nie wnioskuje
braku atutów z dobrowolnego nieprzebicia. Kontekst powstaje raz na decyzję;
nie ma symulacji całych rozdań, I/O ani cache zatrzymującego replay.

Koszt wzrósł: lokalne mediany siedmiu faz wyniosły około 0,085–1,13 ms
na decyzję, wobec 0,015–0,046 ms wcześniej, zależnie od fazy około 3–39 razy
więcej. Niezależna próba wyjścia z 16 kartami dała około 0,303 ms zamiast
0,046 ms. Są to małe koszty bezwzględne, ale nie koszt niezmieniony ani
gwarancja opóźnienia w każdym hoście. Małe porównanie trzech ziaren
i wszystkich trzech miejsc zakończyło się dziewięcioma wygranymi nowego
bota przeciw dwóm autorskim; nie jest to statystyczny dowód siły wobec ludzi.

## Sprawdzenie lokalne i próby żywe

Zapisane celowane wyniki obejmują katalogi i ustawienia CS/ES, rzeczywisty
izolowany backend językowy hosta, binarne źródła, Tysiąc, opcje i zasady,
autorski pełny test 18 rozdań 3-5-8, 26 scenariuszy strategii oraz archiwum,
zamiany uczestników, dalsze ruchy, wspólny interfejs kart i audio.
Sprawdzono też niezmienność ocen, decyzji i dalszego RNG po zmianie ukrytych
danych oraz ograniczenia prawdopodobieństw i wiedzy o wymianach.
Nie uruchamiano pełnego runnera. Początkowe błędy środowiska, pomocników
i przejściowego scalania zachowano w raportach, oddzielnie od końcowych PASS.

Dowody i chronologia znajdują się w prywatnym katalogu
`diagnostics/integrate-prs-2026-09-25/`: raporty `fixtures-README.md`,
`bots-README.md`, `realtime-notes.md`, `realtime-strategy-review.md`
oraz wyniki `root-targeted-initial.json` i `root-affected.json`.

Zakończono również próby na trzech rzeczywistych kontach ELTEN-a:

- Pełny mecz trzech ludzi: 18 rozdań, wszystkie kontrakty każdego miejsca,
  1029 zaakceptowanych wydarzeń, w tym 864 zagrania, 38 wymian i 19 zwrotów.
  1018 wspólnie zapisanych rewizji bez różnic stanu, historii i hasha wydarzeń.
- Osobna próba człowiek → bot → zapis → nowy stół → człowiek: rzeczywisty
  wykonawca bota, wymiany, odtworzenie 133 wydarzeń z nowym ID bota,
  30 dalszych zagrań, powrót człowieka i dokończenie trzeciego rozdania.
  174 wspólne rewizje miały zgodny stan i historię. Trzy miały chwilowy
  wariant wyłącznie surowego hasha rekordów, potem zgodny; nie ogłaszamy
  pełnej identyczności surowych rekordów w każdej próbce. Zachowanie jest
  zgodne z korektą czasu rekordu w store, ale log nie dowodzi zmienionego pola.
- Po korekcie audio: na wszystkich trzech kontach odczytano wyłączony
  sygnał tury. Cztery rozpoczęcia rozdania w drugiej próbie nie emitowały
  `ding`; tasowanie i pozostałe efekty nadal działały.

To natywne handlery kontrolek, prawdziwy serwer, konta i odtwarzacz na jednym
komputerze/łączu, nie trzy osoby grające ręcznie ani odsłuch. Zapis miał
normalne potwierdzenie klawiaturą; wybór jego UUID do odtworzenia był
celowany, nie ręcznym przejściem listy zapisów. Pierwszy pełny mecz był
przed korektą `ding`, drugi po niej; reguły i strategia nie zmieniły się
między nimi. Nie uruchamiano pełnego runnera po każdym etapie.

Zamknięto wyłącznie własne stoły prób, usunięto jeden próbny zapis z konta,
wyładowano sondy. Aktualne 224 źródła i katalogi pozostawiono w pamięci
wszystkich trzech klientów; każdy jest na ekranie głównym bez aktywnego
formularza gry. Nie instalowano, nie podpisywano ani nie publikowano paczki.
Dowody: `LIVE-HUMAN-SUMMARY.json`, `LIVE-BOT-SUMMARY.json`, potwierdzenia
`LIVE-restore-verified-*`, `LIVE-archive-cleanup-*` i `LIVE-FINAL-*`.
