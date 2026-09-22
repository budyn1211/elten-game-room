# Cat, head, tail — wdrożenie PR #12

## Późniejsza decyzja użytkownika: teksty autora

Przy ponownym przygotowaniu buildu 233 użytkownik polecił przywrócić
oryginalny dokument zasad PL/EN i wszystkie teksty oraz tłumaczenia autora
z 7930486. Ta decyzja zastępuje opis redakcji poniżej; ten pozostaje zapisem
wcześniejszego etapu. Nie zmienia punktowania, poprawki bota ani odczytu D.
Katalog `cat-head-tail-pl.json` i dokument zasad zachowują treść autora.
Kontekst `cat_head_tail` oddziela te tłumaczenia od innych gier, szczególnie
Farkle. Katalog dodatków zawiera tylko brakujące wcześniej tłumaczenie
limitu oraz nowego odczytu D. Changelog nie jest zmieniany.

21 września 2026. Na polecenie użytkownika zaimportowano lokalnie grę
**TD Programs / td-programs** z [PR #12](https://github.com/papierek1997/elten-game-room/pull/12),
head `7930486d9051e557b36d392af558139921fda606`. Świeży odczyt GitHuba
potwierdził, że od przeglądu head się nie zmienił. Zawartość włączono do
bieżących źródeł bez zastąpienia starszymi wersjami wspólnego katalogu PL,
manifestów lub plików z lokalnymi poprawkami po buildzie 233. To wdrożenie
w katalogu roboczym, nie scalanie ani zamykanie PR-a na GitHubie.

## Gra i poprawki

- Gra dla 2–8 osób jest w głównym rejestrze, korzysta ze wspólnych stołów,
  zdarzeń, odtwarzania, zapisu partii, historii, pomocy oraz opóźnienia botów.
  Limit punktów domyślnie wynosi 100; punktowanie i zakończenie okrążenia
  pozostają takie jak w kodzie autora. Nie dodano limitu czasu na ruch.
- Zasady PL/EN są samodzielnym opisem: zapisane punkty i punkty tury,
  każdy wynik kości, ogon z wartością ujemną, zapis zera lub wartości ujemnej,
  przykład oraz dokładny moment rozpoczęcia i zakończenia ostatniego okrążenia.
  Autorstwo TD Programs i inspiracja Pig z RS Games pozostają w zasadach.
- Bot na ostatnim miejscu nie zapisuje remisu, jeżeli wynik już zapisany
  zabezpiecza co najmniej remis, a dalszy rzut daje szansę wygranej bez
  utraty tego zabezpieczenia. Jedynka zeruje tylko punkty tury. Bot nadal
  zapisuje przewagę dającą zwycięstwo oraz remis, który dopiero wymaga
  zapisania niezabezpieczonych punktów. Progi 19–24 i strategia wcześniejszych
  miejsc nie zostały zmienione; nie dodano kosztownego planera.
- Wspólne D odczytuje ostatniego rzucającego i wynik, również po zmianie
  tury. Ósemka zawiera także +8 albo -8 punktów. Przed pierwszym rzutem jest
  komunikat o braku rzutu. Nieprawidłowe lub odrzucone zdarzenia nie zmieniają
  tej informacji. D jest wyłącznie odczytem, dostępnym także obserwatorowi.
- Podsumowanie limitu ma polskie tłumaczenie. Poprawiono język nowych
  komunikatów; etykieta rzutu używa osobnego klucza. Zapis otrzymał własny
  klucz tłumaczenia, żeby nie zmieniać istniejącego komunikatu Farkle.
- Dodano pięć nagrań z PR-a i ich deklaracje w obu manifestach. Rzut oraz
  jego osobny skutek zachowują równoczesne efekty. Wszystkie nagrania są
  identyczne bajtowo z PR-em, bez kolejnego kodowania. Informacje o ich
  niepotwierdzonym pochodzeniu/licencjach są w THIRD_PARTY_NOTICES.md;
  należy uzyskać je od autora przed publiczną dystrybucją.

## Weryfikacja

13/13 celowanych skryptów, 11 kontroli składni oraz `git diff --check`
przeszło. Kompilatory zasad i polskiego katalogu są idempotentne. Wyniki:
`../diagnostics/pr12-implementation/SOURCE.json`. Przed poprawką regresja
odtworzyła błędne bankowanie remisu i brak D; raport zachowano osobno.

- Testy autora oraz osiem dodatkowych przypadków: zabezpieczony remis,
  ujemny ogon, remis wymagający zapisu, ochrona zapisanej wygranej,
  wcześniejsze miejsca, błędne zdarzenia, D, zakończenie przy 2 i 8 osobach.
- Binarne wczytanie źródeł z lokalnym, rzeczywistym słownikiem ELTEN-a:
  polski, angielski i brak tłumaczenia. Sprawdzono akcje, komunikaty,
  reguły oraz podsumowanie stołu. Wspólny test fokusu obejmuje także
  nieprzetłumaczone etykiety przy rosyjskim hoście.
- Prawdziwa wspólna powierzchnia Game Roomu w lokalnym szkielecie UI:
  Enter wybiera rzut/zapis, D nie wysyła akcji, F1 i skróty zasad są zgodne,
  fokus i tekst czatu pozostają; lista akcji nie staje się ręką kart.
- Zapis, dokładne odtworzenie stanu, import dla drugiego klienta, następny
  ruch i błędy zapisu przeszły wspólne asercje na lokalnym brokerze.
  Do skryptu saved_games_test dodano opcjonalny wybór klas; domyślne
  wywołanie nadal sprawdza wszystkie wymienione gry, wraz z nową.
- Sprawdzono listę plików wykonawczych, spójność manifestów, selekcję
  dźwięków oraz pełne dekodowanie pięciu nagrań bez odsłuchu.
- Celowane regresje ustawień, makr, przydziału drużyn i tłumaczeń po 233
  również przeszły. Nie uruchamiano pełnego runnera ani setek partii.

Nie testowano na żywym serwerze, w grze użytkownika ani w nowym instalatorze.
Wersja 2.0.2.2/build 233, API 3.0.3 i changelog pozostają bez zmian.
Nie budowano ani nie podpisywano paczki, nie instalowano, nie publikowano,
nie zmieniano kont, profili, tabel lub działającego ELTEN-a.
