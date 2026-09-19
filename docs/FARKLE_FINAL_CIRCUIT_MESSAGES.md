# Farkle — komunikat o końcowym obiegu, 19 września 2026

Zgłoszenie: komunikat o osiągnięciu limitu i dokończeniu obiegu jest
bezpośrednio poprzednikiem komunikatu o wygranej. Na późniejsze polecenie
„napraw farkle” wdrożono warunkowe ogłoszenie, bez zmiany zasad.

Odtworzono ten przypadek w wariancie bieżącym, gdy limit osiąga ostatnia
osoba w kolejności miejsc. `apply_bank` dodaje ogłoszenie końcowego obiegu,
a `finish_turn` od razu stwierdza, że obieg właśnie dobiegł końca.
W jednym zdarzeniu powstają trzy wpisy: zapis punktów, polecenie dokończenia
obiegu i zwycięstwo. Nie wymaga to opóźnionej sieci ani rozbieżności zegarów.

Obecna zatwierdzona zasada wymaga równej liczby tur, a nie nowej dodatkowej
tury dla każdej osoby po przekroczeniu progu. Osoby, które już zagrały
w bieżącym obiegu, nie dostają następnej tury. Sam koniec gry w odtworzonym
przypadku jest więc prawidłowy; mylące jest ogłoszenie dokończenia obiegu,
w którym nie został już żaden ruch.

Wdrożona poprawka: `apply_bank` emituje ogłoszenie tylko wtedy, gdy następny
gracz nie jest pierwszą osobą w kolejności miejsc, czyli pozostają tury
bieżącego obiegu. Nadal ustawia `final_round`; `finish_turn`, rozliczenie
wyniku, remisy i zgodność dawnych zapisów pozostają bez zmian. Przy ostatnim
graczu zdarzenie zapisu punktów zawiera tylko potwierdzenie punktów i wynik
końcowy. Nie zmieniono strategii botów, transportu ani dźwięków.

Przed naprawą nowa asercja `do not ask to finish a circuit when no turns
remain` odtworzyła błąd na rzeczywistym replayu Farkle. Po naprawie przeszły
trzy celowane skrypty: `farkle_final_round_test` (wczytuje też `farkle_test`),
`game_sounds_test` i `post_228_sounds_test`. Składnia obu zmienionych plików
Ruby oraz `git diff --check` poprawne.

Rozszerzone regresje sprawdzają komunikat przy pierwszym i środkowym graczu,
brak jego powtarzania po przejęciu prowadzenia, brak ogłoszenia przy ostatnim
graczu oraz pojedynczy wynik. Obejmują zakończenie przez zapis punktów poniżej
limitu i przez farkle, remis, stare zasady, ignorowanie późnych ruchów
i dotychczasową strategię bota na finiszu. Zachowano efekty zapisu i wygranej.
To testy offline, nie wgląd w zgłoszoną partię ani odsłuch klienta.

Nie uruchamiano pełnego runnera. Wersja, changelog i podpisana paczka 229
pozostają bez zmian; paczka nie zawiera poprawki. Bez instalacji, publikacji,
GitHuba i zmian serwera.
