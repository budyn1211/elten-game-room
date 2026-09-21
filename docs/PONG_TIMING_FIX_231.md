# Pong — tempo ruchu i balans paletek, build 231

20 września 2026. Ten opis uzupełnia PONG_ORIGINAL_PARITY_231.md. Na
zgłoszenie wolniejszego ruchu poprawiono planowanie kroków Ponga, a na
wyraźny wybór użytkownika przywrócono proporcje głośności obu paletek
z domyślnych ustawień oryginału. Pozostają wersja 2.0.2, build 231,
API 3.0.3 i dokładnie ten sam changelog PL/EN.

## Przyczyna spowolnienia

Oryginalna pętla celuje w krok 16 ms i odejmuje od oczekiwania czas
obliczeń. ELTEN wywołuje timery formularza z inną, zmienną częstotliwością:
sam aktywny interfejs ma oczekiwanie 10 ms, do którego dochodzi jego praca.
Adaptacja po jednym kroku ustalała następny termin jako „teraz + 16 ms”.
Przez to gubiła pozostały czas. Przy regularnym wywołaniu co 10 lub 20 ms
wykonywała 40 zamiast 50 kroków w 800 ms, a przy 32 ms tylko 25.
Wcześniejsze symulacje z idealnym odstępem 16 ms nie wykrywały tej różnicy.

Harmonogram zachowuje teraz resztę czasu i wykonuje kroki o stałej długości
16 ms. Jedno wywołanie może nadrobić najwyżej cztery kroki. Przy przerwie
dłuższej niż 64 ms odrzuca zaległość i wraca do bieżącego czasu; nie
przyspiesza całej wymiany po powrocie z zawieszonego okna. Każdy krok
otrzymuje swój czas, zamiast wspólnego czasu końca wywołania.

Zmiana obejmuje silnik właściciela w grze z botem oraz lokalne silniki
dwóch ludzi, także przy właścicielu-obserwatorze. Zdarzenia odbicia są
odbierane z silnika po każdym kroku, bez zwielokrotniania jednej akcji.
Reset wymiany czyści harmonogram. Kroki sprzed końca pauzy nie uruchamiają
lotu, a klawisze trzymane podczas pauzy nadal nie serwują nowej piłki.

Nie zmieniono prędkości piłki, reguł odbicia, powtarzania strzałek, poziomów
botów, odstępów sieciowych ani wspólnego timera ELTEN-a. Nie dodano pętli
interfejsu, wątku fizyki, blokującego oczekiwania ani odświeżania formularza.
Jest to naprawa potwierdzonego spowolnienia zależnego od częstotliwości UI,
nie obietnica stałych 60 klatek na przeciążonym komputerze.

## Głośność

Zweryfikowany kod i bytecode wzorca mają domyślne suwaki własnych i cudzych
kroków na 100. Własny krok jest odtwarzany z bazową głośnością 50/100.
Przeciwnik po aktualizacji przestrzennej ma tłumienie odległości 20 × 4,
czyli poziom 20/100. Nie należy mylić wartości awaryjnej 0,5 w pomocniku
odczytu ustawień z domyślną wartością skompilowanego programu.

Użytkownik wybrał te proporcje zamiast podniesienia obu poprzednich 25%
o dziesięć procent. W Game Roomie własna paletka ma mnożnik 0,50,
przeciwnika 0,20, dodatkowo pomnożone przez istniejącą głośność gry.
Lektor pozostaje na 0,25. Pozostałe efekty, w tym tarcze Arcade, zachowano
bez zmiany poziomu. Pliki nagrań, symetryczna wysokość tonu i ustawienia
użytkownika są niezmienione. To porównanie parametrów odtwarzania, nie
pomiar głośności na konkretnym urządzeniu ani odsłuch.

## Weryfikacja i wydanie

Nowy axel_pong_frame_timing_test używa rzeczywistego opakowania FormTimer
z symulowanym zegarem. Sprawdza 13 równych i nierównych rytmów UI, sześć
poziomów, boty i ludzi: 234 kontrole liczby kroków/lotu oraz 156 kontroli
przemieszczenia paletki. Obejmuje też różne częstotliwości obu klientów,
właściciela-obserwatora, pojedyncze niezawodne odbicie po kilku krokach,
długie zatrzymanie oraz klawisze na granicy pauzy po punkcie. Ten sam test
odtwarza błąd w poprzedniej podpisanej paczce (24 zamiast 29–30 kroków
w 480 ms przy wywołaniach co 10 ms).

Regresje dźwięków sprawdzają oba kierunki patrzenia, wspólną głośność gry,
poziomy 0,50/0,20 i brak zmian innych efektów. Nowa regresja tempa wchodzi
też do testu binarnego Ponga. Końcowe wyniki są poza repozytorium:
`diagnostics/pong-timing-231/SOURCE.json` oraz `PACKAGE.json`.

Przed zastąpieniem paczki zachować podpisaną 231 o SHA-256
a853859a80a2a8d61e94a77a465eaf78507bdf450fcbe611dcaf8c556aad2b49
jako `ELTEN-Game-Room-build-231-before-timing-fix-signed.eltsetup`.
Sam dokument nie potwierdza ukończenia pakowania. Po zbudowaniu sprawdzić
podpis autora, manifesty, zgodność wszystkich plików i binarne testy.
Bez pełnego runnera, instalacji, publikacji, GitHuba, zmian serwera lub
profili, nowego meczu na żywych kontach i wykonywania odzyskanego Pythona.

