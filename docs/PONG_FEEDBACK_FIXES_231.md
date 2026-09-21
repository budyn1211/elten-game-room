# Pong — poprawki po ręcznym teście buildu 231

To historyczny etap zawarty w paczce 7281d98a…. Kolejna seria zmian,
w tym lokalny silnik gościa, nowy czas serwisu i kolejka nagrań według
oryginału, jest opisana w [PONG_ORIGINAL_PARITY_231.md](PONG_ORIGINAL_PARITY_231.md).

20 września 2026. Zmiany w źródłach, jeszcze nie w podpisanej paczce.
Nie zmieniono wersji, changelogu, reguł punktowania ani protokołu.

## Przejście do następnej wymiany

Gość nie ma lokalnego silnika. Punkt w LiveSessions może dotrzeć przed
pierwszym obrazem następnej wymiany w Communications. Świeży obraz poprzedniej
wymiany nie wystarcza więc do wznowienia gry. Klient czeka na zweryfikowany
obraz właściwej wymiany; nie odczytuje serwującego z nieistniejącego silnika.
Regresja odtworzyła zgłoszony `nil.server` przed poprawką.

Naciśnięcia Up/Spacji są odbierane także podczas pauzy, ale nie są zachowywane
do późniejszego serwisu. Przytrzymany klawisz wymaga zwolnienia, zanim może
zaserwować. Pozostaje obsługa krótkiego rzeczywistego naciśnięcia już podczas
gry, nawet jeżeli klawisz został zwolniony przed najbliższą klatką.
Regresja przed poprawką odtworzyła samoczynny serwis po przerwie.

Samo przytrzymanie podczas trwającej wymiany nadal może odbić piłkę blisko
bramki. Potwierdzono tę regułę w kodzie oryginału i użytkownik sprawdził ją
ręcznie. Nie jest traktowana jako błąd ani usuwana. Nowe naciśnięcie może
odbić wcześniej; przytrzymanie nie daje takiego wcześniejszego odbicia.

## Bramka i nagrany wynik

Dźwięk bramki i lektor uruchamiają się po zaakceptowanym zdarzeniu punktu,
nie na podstawie nietrwałej listy efektów w pakiecie położenia piłki.
Ponowiony punkt nie odtwarza nagrań drugi raz. Przy nadrabianiu kilku punktów
prezentowany jest aktualny wynik, bez kolejki nieaktualnych nagrań.

Dodano osiem oryginalnych efektów Goal1–8, cztery nagrania score1–4, wstęp
scores oraz liczby 0–21. Efekt i komentarz bramki mogą grać równocześnie.
Po trzech sekundach i zakończeniu komentarza lektor odczytuje wynik:
najpierw własny, potem przeciwnika; obserwator słyszy kolejność miejsc.
Poszczególne części wyniku czekają na zakończenie poprzedniej, z ograniczonym
czasem awaryjnym. Kolejka korzysta z istniejących wywołań zegara; nie ma
usypiania, ręcznego pompowania UI ani dodatkowych żądań sieciowych.

Odłączenie widoku przy aktualizacji wyniku zatrzymuje odgłosy pola, nie
komentarz bramki. Nagrany wynik działa także po ostatnim punkcie meczu.
Zamknięcie gry lub wyciszenie usuwa również oczekujące nagrania. Zwykła
mowa i historia wyniku pozostają bez zmian. Przy przewadze prowadzącej do
wyniku powyżej 21 pozostaje dokładny wynik tekstowy i mówiony przez ELTEN:
źródłowe nagrania nie zawierają większych liczb. Nie odczytujemy częściowego
ani nieprawidłowego wyniku nagranym głosem.

Nie zmieniono trzysekundowej gotowości do następnego serwisu. Nagrania nie
sterują synchronizacją ani nie uzależniają tempa gry od lokalnej głośności.
Dłuższy efekt może wybrzmieć również po zakończeniu przerwy.

## Paletki i głośność

Ton ruchu obu paletek jest symetryczny: mnożnik częstotliwości 0,7 przy
brzegach, 1,3 w środku. Ruch własnej i cudzej paletki ma bazowy poziom 0,25,
odpowiadający 50% poziomu efektu pomnożonemu przez referencyjne ustawienie
50% dla kroków. Następnie stosowane są istniejące suwaki Game Roomu.
Nie nakładamy dodatkowego tłumienia odległości na ruch przeciwnika;
pozostaje jego położenie stereo. Piłka nadal zmienia głośność z odległością.
Bramki i lektor również mają poziom bazowy 0,25.

Małe przesunięcia bota sumują się do progu odgłosu kroku. Wcześniej każde
przesunięcie mogło być mniejsze od progu, przez co nawet długi ruch był cichy.
Na normalnym poziomie przed serwisem krok wynosi 0,495, poniżej progu 0,5.
Potwierdzono przesuwanie paletki przed serwisem na wszystkich sześciu
poziomach. Zmiana dotyczy generowania efektu, nie położenia, strategii ani
szybkości bota. Zgodnie z doprecyzowaniem użytkownika nie oznacza to, że
wszystkie odgłosy ruchu bota były wcześniej nieobecne.

## Weryfikacja i ograniczenia

Nowe regresje: `axel_pong_rally_sync_test`, `axel_pong_serve_input_test`,
`axel_pong_audio_feedback_test`, `axel_pong_point_audio_test`. Obejmują gościa,
obserwatora, właściciela-obserwatora, opóźniony obraz, zmianę serwującego,
krótkie i przytrzymane klawisze, cykl widoku, ostatni punkt, kolejkę nagrań,
wyciszenie, suwaki, brak opcjonalnego nagrania i sprzątanie zasobów.
Włączono je do testu binarnego Ponga. Szczegółowe wyniki testów źródeł:
`../diagnostics/pong-feedback-231/SOURCE.json` w katalogu roboczym.

Testy audio używają kontrolowanych uchwytów. Nie stanowią odsłuchu urządzenia
ani nowego meczu na dwóch kontach. Poprzedni test rzeczywistego kanału
dotyczył wcześniejszego snapshotu, nie jest dowodem przetestowania tych zmian.
Nowe nagrania są zgodne bajtowo z dostarczonym źródłem; nie uruchamiano
odzyskanego Pythona. Przed publiczną dystrybucją nadal należy ustalić prawa
do oryginalnych nagrań. Bez instalacji, publikacji, GitHuba i zmian serwera.
