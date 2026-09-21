# Pong: naprawa rewanżu w tym samym pokoju

21 września 2026. Zmiana źródeł po podpisanej 2.0.2/build 231; bez nowej paczki.

## Diagnoza przed zmianą

Zgłoszony przebieg: mecz do 7 punktów, zmiana ustawień przez gospodarza,
następnie mecz do 21 w tym samym pokoju. Nowa partia utkwiła na synchronizacji.

Odczyt pamięci działającego klienta pokazał aktywną nową partię z `rally=0`,
ale klienta Ponga ze starym identyfikatorem meczu, licznikiem ogłoszeń 10,
pakietem poprzedniej wymiany oraz zamkniętym kanałem i obiema kolejkami operacji.

`GameScreen#switch_to_new_session` zmieniał sesję i odtwarzany stan, lecz
pozostawiał klienta poprzedniej partii. Pong zamyka Communications na końcu
meczu. Zamknięty kanał celowo nie daje się ponownie uruchomić przez reconnect.
Nie był to więc brak nowej partii w LiveSessions ani opóźnione zaproszenie.

Przed edycją kodu produkcyjnego nowy `axel_pong_rematch_test.rb` odtworzył
ukończenie meczu 7:3, zamknięcie kanału i kolejek, a następnie zmianę celu na 21.
Test zakończył się błędem: `Alice: rematch reused the old client with its closed channel`.
Używa rzeczywistego przełączenia GameScreen, replaya Ponga, klienta i EventChannel;
zastępuje deterministycznymi atrapami zewnętrzną sieć, zegar, odczyt sesji i audio.
Prywatny zapis incydentu oraz wynik sprzed naprawy pozostają poza repozytorium.

Ta diagnoza wyjaśnia opisany rewanż, nie wszystkie wcześniejsze przerwy sieciowe.

## Poprawka we wspólnym szkielecie

- Pierwsze uruchomienie i potwierdzone przejście do innej sesji korzystają
  z tego samego `start_game_client`: utworzenie, opcjonalne `bind_screen`, `start`.
- Przed stworzeniem następnego klienta poprzedni zostaje zamknięty. Usuwa to
  jego timer, powiązania z widokiem, audio, kanał i lokalny stan starego meczu.
- Nowa partia otrzymuje nowy identyfikator kanału, liczniki ogłoszeń i stan gry.
  Opcje i gracze nadal pochodzą z jej zwykłego replaya.
- Nieudany odczyt nowej sesji nie niszczy starego klienta ani oczekującego celu.
  Pozostaje dotychczasowe odzyskiwanie odczytu.
- Powtórzone powiadomienie o tej samej sesji nie restartuje klienta.
  Kolejny punkt, zwykłe odświeżenie i odtworzenie widoku również tego nie robią.
- Jeśli nowy klient odmówi startu, obie ścieżki pętli ekranu wracają bezpiecznie
  przez standardowe sprzątanie, zamiast otwierać grę z nieaktywnym klientem.

Nie zmieniono protokołu Communications, LiveSessions, reguł Ponga, fizyki,
zegara, opóźnień, dźwięków ani tekstów. To obsługa cyklu życia opcjonalnego
klienta gry, a nie przebudowa transportu wszystkich gier. Gry zwracające
`nil` z `build_client` nie tworzą nowych zasobów ani dodatkowych żądań.

Następne gry zręcznościowe korzystające z `build_client` i `bind_screen`
otrzymują ten sam cykl życia. Ich klient powinien mieć bezpieczne `close`,
które odłącza timer/callbacki i zasoby; nie należy przenosić kanału ani
liczników między sesjami. Drugi istniejący klient, Krowy, został sprawdzony:
zapisany słownik i galeria pozostają, prywatne dane poprzedniej partii nie
przechodzą do nowego klienta.

## Kontrole

Nowa regresja Ponga obejmuje gospodarza, gościa i obserwatora, mecz 7→21,
serwis, ogłoszenie pierwszego punktu, wznowienie po bramce, rzeczywiste
zakończenie dopiero przy 21, kolejne mecze bez zmiany limitu, przejścia
człowiek→bot→człowiek i gospodarza-obserwatora. Obejmuje również nieudany
odczyt i ponowienie, powtórzone powiadomienie, spóźnione stare zaproszenie
oraz zakończenie starej operacji tworzenia endpointu już podczas nowej gry.

`game_client_lifecycle_test.rb` wykonuje obie rzeczywiste gałęzie `run`,
sprawdza niepowodzenie `start`, kolejność zamykania/bindowania, przekazywanie
usług, grę bez klienta (Czwórki, także `state=nil`) i prawdziwego klienta Krowy.
Test synchronizacji otrzymał brakujący obiekt Base w sztucznym ekranie,
który wcześniej nie musiał uruchamiać klienta; nie zmieniono jego asercji.
Regresja Ponga jest też dołączona do binarnego zestawu testów źródeł.

Weryfikacja: 14 z 15 wybranych skryptów przeszło, 6 kontroli składni
oraz `git diff --check` poprawne. Obejmuje binarne źródła Ponga, rzeczywiste
Tasks.run, UI/Krowę, synchronizację, transport i symulacje wielu klientów
LiveSessions. Pełnego runnera nie uruchamiano.

Pozostały `connection_recovery_test.rb` zgłasza istniejącą wcześniej asercję
Quiz Party: `expired committed question stranded the next automatic transition`.
Uruchomienie go z kodem produkcyjnym sprzed poprawki (`cb6719b`), załadowanym
w pamięci bez podmiany plików, kończy się identycznie. Nie oznaczamy tego
testu jako zaliczonego ani nie poprawiamy osobnego problemu quizu w tym zadaniu.
Raporty lokalne: `diagnostics/pong-rematch-231/{BEFORE_FIX,SOURCE,BASELINE}.json`
w katalogu roboczym nadrzędnym, poza repozytorium.

Nie wykonywano żywego meczu, odsłuchu, restartu lub przeładowania ELTEN-a,
zmian serwera/profili, pakowania, podpisywania ani wysyłania na GitHub.
Obecna podpisana paczka 231 nadal nie zawiera tej poprawki.
