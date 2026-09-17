# Wdrożenie planu Scrabble, Mexican Train i Biblios

17 września 2026. Użytkownik polecił wdrożyć `POST_227_GAME_CHANGES_PLAN.md`,
następnie przebudować i podpisać **2.0/build 227**. Zachować poprzedni
changelog i dopisać krótki punkt o Biblios od dawidpieper w PL i EN.
Bez instalowania, publikowania i wysyłania zmian na GitHub.

**Najnowsza decyzja: ponownie zbudować i podpisać 227 po dodaniu imion
botów.** Użytkownik przekazał 24 imiona PL i 26 EN; losowanie przy dodaniu
według języka interfejsu, wspólne dla wszystkich klientów. Nie wykonywać
migracji starych zapisów — użytkownik potwierdził, że ich nie ma.
Biblios zachowuje skład talii i wariant z PR dawidpieper zgodnie z jawną
decyzją użytkownika; nie dostosowywać do pudełkowej edycji gry.

## Postęp

- [x] Scrabble: pojedynczy sposób układania i celowane regresje.
- [x] Mexican Train: wszystkie cele, odmowy, Z bez automatycznego ruchu.
- [x] Biblios PR #7: przegląd, integracja, bot, tłumaczenia i testy.
- [x] Celowane testy wspólnego UI, replayu, pomocy i binarnego ładowania.
- [x] Changelog PL/EN, zachowane numery 2.0/227.
- [x] Losowane imiona botów; dodatkowy krótki punkt changelogu PL/EN.
- [ ] Kopia poprzedniej paczki, budowa, podpis i kontrola gotowego artefaktu.

Wcześniejsze niewydane poprawki Rummy i interakcji nowych gier pozostają
w źródłach i mają wejść do paczki. Pełnego runnera nie uruchamiać.
Ten dokument jest punktem wznowienia; niewykonane etapy nie są wynikiem testu.

## Wynik prac w źródłach

25/25 celowanych skryptów, składnia 37 plików Ruby i diff check poprawne.
Binarne wczytanie dotyczy bieżących źródeł, nie nowej paczki. Sprawdzono
117 tłumaczonych tekstów Biblios. Rejestr ma 23 gry. Raport:
`POST_227_VERIFICATION.md`; wyniki i logi poza repo:
`../diagnostics/post-227-plan/TESTS.json` i `SOURCE.json`.
Nie przeprowadzono ręcznej gry na rzeczywistych klientach ani pełnego
runnera. Nie scalano PR na GitHubie i nie zmieniano serwera.

Dotychczasowa podpisana paczka 227 jest niezmieniona, SHA-256:
`c8dd0b8c7ef8f8884b8656e815414fec940a1f161dec3113fca8c5b00d07b92d`.
Nie zawiera tych nowych zmian. Zostanie zachowana osobno przed zatwierdzonym
ponownym pakowaniem. Bieżąca kontrola: `../diagnostics/bot-names-227/`.
