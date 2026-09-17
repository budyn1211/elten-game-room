# Scrabble, Mexican Train i Biblios — wykonanie w źródłach

17 września 2026. Wykonano zakres `POST_227_GAME_CHANGES_PLAN.md`.
Nowsze polecenie użytkownika wstrzymało budowanie i podpisywanie:
czekamy na dodatkową poprawkę. Wersja nadal **2.0/build 227**.

## Scrabble

Enter na pustym polu otwiera dostępną rękę; drugi Enter kładzie wybraną
płytkę. Blank wymaga wyboru litery. Kursor pozostaje na wybranym polu.
Backspace usuwa własną niezatwierdzoną płytkę pod kursorem, nie ostatnią
położoną. Z usuwa szkic. Cyfry 1–7 tylko czytają rękę. Usunięto H/V/N,
Shift+litery/cyfry, kombinacje AltGr oraz osobne Delete. Nie dodano
formularza słowa ani menu kontekstowego. Pomoc i zasady PL/EN opisują
obecną obsługę. Reguły, słowniki i punktacja nie zostały zmienione.

Testy używają faktycznej ścieżki Enter/lista/Enter, także dla blanku,
identycznych fizycznych płytek, anulowania, zmiany tury podczas wyboru,
wymiany, pasa, usuwania pod kursorem i odczytu cyfr. Wybranie płytki
w nieaktualnym oknie nie zmienia nowego szkicu ani nowej ręki.

## Mexican Train

Przy kostce z legalnym ruchem lista pokazuje własny pociąg, meksykański
i pozostałe, również zamknięte lub niepasujące. Enter na niedozwolonym
celu wyjaśnia odmowę bez wysłania ruchu i bez zamknięcia listy.
Obowiązek dubletu ma pierwszeństwo w komunikacie, z numerem i wskazaniem
pociągu. Brak legalnego celu kostki daje wyjaśnienie bez otwierania listy.
Z/Shift+Z tylko wskazuje legalne kostki, nigdy ich nie zagrywa.
Pozostają krótkie etykiety, stabilne ID i powrót Escape do tej samej kostki.

Sprawdzono zamknięte pociągi, brak dopasowania, aktualizację wyboru,
obserwatora/innego gracza, obowiązki dubletów oraz zachowany wyjątek
autora własnej serii. Domino nadal używa zapamiętanej strony G/D;
Mexican Train nie przejmuje tego zachowania.

## Biblios z PR #7

Zintegrowano kod z [PR dawidpiepera „Dodaj grę Biblios”](https://github.com/papierek1997/elten-game-room/pull/7),
head `eee45867b29b9926026499159301cc3e4e038d88`, bez scalania PR na serwerze.
Zachowano inne lokalne gry i poprawki zamiast zastępować pliki wspólne
starszymi wersjami z PR. Rejestr ma obecnie 23 gry.

Na wyraźne polecenie użytkownika **pozostawiono wariant oraz talię PR**:
87 kart, w tym 45 kategorii, 18 złota i 24 kościelne; wartości kategorii,
przygotowanie talii i dwa warianty kar pozostają. Nie przedstawiamy tego
jako zweryfikowanej kopii każdej pudełkowej edycji.
Do przeglądu reguł wykorzystano [instrukcję Biblios](https://playheavenlygames.com/wp-content/uploads/2023/05/ed90b-biblios_rules.pdf).
Porównanie z [fotografią talii w omówieniu egzemplarza gry](https://sidayanqi.wordpress.com/2016/03/13/biblios-a-game-that-surprised-me/comment-page-1/)
wskazało różnicę składu talii; decyzja użytkownika rozstrzyga ją na korzyść
zachowania PR, nie samodzielnej zmiany edycji.

Naprawy i integracja:

- Wielokrotna dostawa tego samego zdarzenia nie wykonuje go ponownie;
  sprawdzani są gracze, autor rozpoczęcia i ziarno losowania.
- Duża płatność mieści się w jednym zdarzeniu: krótka maska identyfikatorów
  zamiast pełnej listy. Test obejmuje 62 karty i limit 64 znaków.
  Odczyt wcześniejszego formatu pozostaje dostępny.
- Uszkodzona lista płatności nie jest traktowana jak świadoma odmowa
  zapłaty i nie uruchamia kary. Powtórzone karty i błędne kwoty są odrzucane.
- Kara rozdzielana między przeciwników zaczyna się od następnego gracza,
  co ma znaczenie, gdy kart nie wystarcza dla wszystkich.
- Odczyty zdarzeń działają w wspólnym ekranie, bez powtarzania wyniku;
  prywatne dobrania są tylko dla odpowiedniego gracza.
- Bot uwzględnia własną rękę i jawne karty, nie faktyczne ukryte ręce ani
  przyszłe dobrania. Ocena kategorii, zmiany kości, aukcji i płatności
  korzysta z tej samej granicy informacji. Tajna płatność nie zdradza,
  które wcześniej znane karty zniknęły.
- Przy płatności bot przelicza koszt kolejnych oddawanych kart, uwzględnia
  utratę wartości kategorii i nadpłatę. Nie zachowuje już pierwszej słabej
  karty tylko dlatego, że zobaczył ją jako pierwszą.
- Z/Shift+Z wskazuje wszystkie fizyczne karty mogące wejść w legalną
  płatność, ale nie wybiera za gracza paczki ani nie płaci automatycznie.
- Dodano dźwięki, polskie komunikaty, zasady, opcje i pomoc. Sprawdzono
  obecność 117 tekstów Biblios w skompilowanym katalogu tłumaczeń.

Testy obejmują obie kary, 2/3/4 graczy, zakończenie partii, replay,
odtwarzanie zapisów, publiczne i prywatne informacje, płatności,
wszystkie fazy bota oraz niezmienność jego decyzji po podmianie informacji,
których nie powinien znać. To kontrola legalności i wybranych heurystyk,
nie dowód optymalnej strategii.

## Weryfikacja i granice

- 25/25 jawnie wybranych skryptów. Nie uruchamiano pełnego runnera.
- Składnia 37 plików Ruby i `git diff --check` poprawne.
- Binarne wczytanie bieżących źródeł z symulacją bezargumentowego
  `Array#shuffle` ELTEN-a; sprawdzone ekrany/ruchy sześciu nowych gier.
  Nie jest to test nowej paczki ani rzeczywistego interfejsu klienta.
- Celowane regresje Rummy, wspólnej ręki, pakietów, F1, skrótów,
  komunikatów i dźwięków przeszły. Wcześniejsze zmiany zachowane.
- Sprawdzono numery 2.0/227 i spójność nowej wzmianki o Biblios w
  changelogu, źródle tłumaczeń i skompilowanym PL.mo.

Logi oraz listy wykonanych kontroli:
`../diagnostics/post-227-plan/TESTS.json` i `SOURCE.json` względem repo.
Skrypty odtwarzające kontrole są w tym samym katalogu.

Nie testowano ręcznie na dwóch rzeczywistych klientach. Nie wykonano
nowego builda, podpisu, instalacji, publikacji, zmian na GitHubie ani
zmian serwera. Obecna paczka 227 zachowuje SHA-256
`c8dd0b8c7ef8f8884b8656e815414fec940a1f161dec3113fca8c5b00d07b92d`
i **nie zawiera** tych zmian. Budowanie czeka na nowe polecenie.
