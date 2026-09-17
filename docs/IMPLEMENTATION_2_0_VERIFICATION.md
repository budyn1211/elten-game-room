# Cztery plany — kontrola wdrożenia lokalnego

17 września 2026. Źródła bazowe: 1.1.10/build 226. Użytkownik polecił
dokończyć te cztery plany, ale wstrzymał wydanie do dodania kolejnych gier.
Nie zmieniono numerów, changelogu ani poprzedniej podpisanej paczki.
Nie instalowano ani nie publikowano nowych źródeł/paczki.

## Wyniki

48 celowanych skryptów: 15 dla nowych zasad/integracji, 23 dla wspólnych
mechanizmów i 10 dla widgetu/powiadomień/zaproszeń. Wszystkie przeszły.
Pełnego `tools/run-tests.rb` nie uruchamiano. Składnia 53 zmienionych lub
nowych plików Ruby oraz `git diff --check`: poprawne.

Wyniki, logi i jawna lista uruchomionych skryptów znajdują się poza repo,
w `diagnostics/implementation-2-0/` obok katalogu projektu:
`games.json`, `shared.json`, `invitations.json`, `syntax-and-scope.json`.
Te raporty opisują sprawdzone źródła, nie przyszły binarny build.

## Rummy — punkty projektu 1–17

| Punkt | Wdrożenie i kontrola |
|---|---|
| 1. Ustawienia | Jedna lista trybu stosu, pozostałe reguły jako pola wyboru/liczby; brak limitu rozdań i wszechwiedzy. Zmiana eliminacji podmienia domyślne 1000/500, nie nadpisuje własnego limitu. Test rzeczywistego formularza. |
| 2. Talie | 2–8 osób, 14 kart, 2/3/4 talie; identyczne karty wymuszają 4; dwa jokery na talię. Osobne fizyczne ID. |
| 3. Tura | Dobranie przed operacjami, jedna akcja dobierania, odrzut/koniec bez odrzutów, natychmiastowy koniec pustej ręki. |
| 4. Układy | Kolejność zaznaczenia jest kolejnością układu, bez naprawiania przez sortowanie. Sekwencje, zestawy, identyczne karty, as niski/wysoki bez zawijania. |
| 5. Pierwsze wyłożenie | Próg 15–90, kilka grup jednym zatwierdzeniem; wcześniej brak dokładania, manipulowania i zabierania odrzutów. |
| 6. Odrzuty | Cztery tryby, przy wielokrotnym pobraniu wybrana karta i wszystkie nowsze. Można je zatrzymać. Shift+D zawiera same nazwy. |
| 7. Joker | Pozycja ustala dopasowanie; jest jawnie czytany jako joker. Podmiana naturalną kartą, szczególny niejednoznaczny trzykartowy zestaw, brak zabierania całego układu z jokerem. |
| 8. Manipulacje | Legalne pojedyncze zabrania i resztki układu, zabranie całego, uporządkowane łączenie, zachowanie znaczenia jokera. Jednorazowe 300 za każdą nieodłożoną kartę, również jokera; potem karta zwykła. |
| 9. Wartości | Punktacja uproszczona/tradycyjna, pozycja asa, joker na stole/w ręce, dodatkowe punkty za identyczne karty. |
| 10. Wyniki | Zwykła punktacja i premie, eliminacja i mnożniki 2/3/4; kary nie są mnożone. Limit po rozdaniu, obsługa remisów i ostatnich eliminowanych. |
| 11. Czas/blokada | 50 kary i dobranie tylko przed wcześniejszym dobraniem; kary za zatrzymanie sumują się. Późna akcja odrzucona; blokada po dwóch obiegach bez postępu i źródła dobierania. |
| 12. Ręka/szkic | Enter proponuje dołożenie lub odrzut/anulowanie, Delete odrzuca. N/F/P/Shift+P tworzą, zatwierdzają i edytują uporządkowane grupy lokalne. |
| 13. Stół/skróty | C z uproszczonym menu, D/Shift+D, E/S/T i sortowanie. Z nie rozwiązuje za gracza układów ani nie wykonuje niejednoznacznej podmiany jokera. |
| 14. Kursor/dźwięki | Wspólna ręka, właściciel+rozdanie w hand_epoch, ostatnia dobrana karta, poprzednia po zagraniu, bez powtórki nagłówka. Dźwięki przez istniejące grupy głośności. |
| 15. Bot | Ograniczony planer własnej ręki; dobieranie/odrzut, próg pierwszego wyłożenia, sensowne oczekiwanie na rummy, manipulacja tylko z realnym zwrotem i korzyścią. Bez ukrytych rąk/stosu. |
| 16. Integracja | Standardowe action_for/replay/transport, zapis na początku tury bez lokalnego szkicu. Odtworzenie z mapowaniem botów i zatrzymanym zegarem. |
| 17. Weryfikacja | Pięć testów Rummy, ograniczone ślady integracyjne, tłumaczenia, formularz, ręka i pomoc. Wydanie świadomie odłożone. |

Główne testy: `rummy_test`, `rummy_variants_test`, `rummy_edges_test`,
`rummy_surface_test`, `rummy_save_strategy_test`,
`three_games_integration_2_test`, `game_option_form_test`.

## Wspólne poprawki — cztery punkty

| Punkt | Wdrożenie i kontrola |
|---|---|
| 1. Widget | Pobieranie przy rzeczywistym wejściu, R i co 5 sekund aktywności; strzałki nie wywołują pobierania. Jeden skończony odczyt w tle, aktualny kursor zachowany, brak cyklu poza kontrolką. Test 100 strzałek wywołujących focus, wolnego wyniku, R i błędów. |
| 2. Nowe stoły | Jeden mały rekord preferencji na konto, własne aktualizacje konkretnych pól, odczyt zainteresowanych + jedna lista online. Ogłoszenie tylko nowego publicznego stołu, nie własnego/prywatnego/wznowionego. Ograniczona kolejka, notice, deduplikacja i zwykłe dołączanie przez discovery. |
| 3. Opóźnienie | Jedna wspólna definicja 0–5 we wszystkich 20 zarejestrowanych grach; UNO/Makao domyślnie 1, inne 0. Bez ponownego rozpoczynania pauzy po odświeżeniu; krótsza przy terminie, wyjątek koloru UNO. Sprawdzone legalne reakcje ludzi podczas tury bota. |
| 4. Reversi | Oba przełączniki, cztery kombinacje, dowolnie wiele dobrowolnych pasów, sąsiedztwo ośmiokierunkowe bez obowiązku bicia, nadal wszystkie możliwe odwrócenia. Stare archiwa zachowują stare reguły; generator/symulacja/klucze/budżet planera zgodne. |

Testy powiadomień obejmują autorstwo, cudze rekordy, duplikaty, brak zapisu
niezmienionych preferencji, 429, niepewną odpowiedź, częściową wysyłkę,
zamknięcie kolejki, start/stop rozszerzenia, nową instancję dołączania,
wygaśnięcie podczas wolnego odczytu i brak usuwania po samym błędzie sieci.
Nowy typ wygasa lokalnie bez pustych pozycji; stary mechanizm wygasania
zaproszeń pozostaje poza zakresem.

Czas ogłoszeń pochodzi z ostatniej próbki serwera już odebranej przez
NotificationService, z monotonicznym odmierzaniem między próbkami. Zmiana
zegara komputera nie zatrzymuje znanego terminu. Nie dodaje to żądań HTTP.
Przed otrzymaniem pierwszej próbki hosta używany jest zastępczo lokalny czas;
to ograniczenie startu, nie gwarancja idealnego zegara w każdej awarii hosta.

Rzeczywistą, zaakceptowaną próbę na kontach papierek/papiertestowy opisuje
[TABLE_WATCH_2_VERIFICATION.md](TABLE_WATCH_2_VERIFICATION.md). Dane próbne
usunięte; docelowa pusta tabela preferencji pozostaje. Nie prowadzono
masowej wysyłki ani nie instalowano wdrażanych źródeł na klientach.

## Domino — punkty 1–11

| Punkty | Wdrożenie i kontrola |
|---|---|
| 1–3. Zestawy/ustawienia/rozdanie | Wszystkie 11 zestawów, po 7/10, maksima 4/5/8, unikalne kopie. Zakaz normalizuje i ukrywa zależne opcje; drużyny używają istniejącego przydziału. Starter wybierany najwyższym rozdanym dubletem, otwarcie dowolną kostką. |
| 4. Ruch/dobieranie/czas | Oba końce i orientacja, pojedyncze/seryjne dobranie, jedna akcja na turę. Stara legalna kostka pozostaje dostępna po dobrowolnym dobraniu. Timeout nie dobiera ponownie ani wbrew zakazowi. |
| 5. Punkty/koniec | Samotne 0–0 za 10, inne za sumę. Rzeczywista blokada także przy zakazie i niepustym stosie. Wyniki i eliminacje razem; najniższy wynik wśród ostatnich odpadających, wspólna wygrana przy remisie. |
| 6. Drużyny | Równe składy, przeplatanie także po ręcznym przydziale. Dodatek zwycięskiej drużyny dla każdej przeciwnej; opcjonalnie koniec całej drużyny i pomijanie pustych rąk. |
| 7–8. Interfejs | Jawna ręka kostek, Enter/G/D, Spacja, C/V/E/S/T i Z, wybór strony, podgląd łańcucha, kursor; krótkie komunikaty bez ujawnienia dobranych kostek. |
| 9. Bot | Własne połączenia, koszt ręki i samotnego 0–0, publiczne pasy/kopie, blokada, limit eliminacji i partnerzy. Własna ostatnia kostka w trybie całej drużyny nadal porównuje strony zamiast udawać wygraną. |
| 10–11. Integracja i wyjątki | Jeden zapis całej serii, ochrona powtórzeń, replay i archiwum. Przyjęte wcześniej jawne propozycje wykonawcze zapisano w IMPLEMENTATION_2_0.md, nie przypisując ich QC. |

Testy: `domino_test`, `tile_hand_test`, `three_games_integration_2_test`,
`team_assignment_test`, `game_option_form_test`. Największy zestaw ma
364 osobne kostki. W scenariuszu ponad 200 pobrań licznik rzeczywistego
GameRepository pokazuje **jedno wywołanie dopisania jednego zdarzenia**.
Zwykłe odczyty transportu nadal mogą wystąpić; nie jest to obietnica
jednego całkowitego żądania HTTP niezależnie od warunków sieciowych.

## Mexican Train — punkty 1–10

| Punkty | Wdrożenie i kontrola |
|---|---|
| 1–2. Zakres/rozdanie | Osobna gra 2–8, 91 kostek, stacja wyłączona z rozdania; po 15/12/10, cykl 12 do 0 i znowu 12. Tylko uzgodniona opcja dobrowolnego dobierania, próg i wspólne opóźnienie. |
| 3–4. Pociągi/tura | Własny, cudzy otwarty, publiczny; prawidłowe otwieranie i zamykanie. Jedno dobranie na decyzję, automatyczny pas bez ruchu i stosu; po dublecie nowa decyzja. |
| 5. Dublety | Stos obowiązków od ostatniego, wyjątek autora serii potwierdzony przez użytkownika w QC. Zamknięcie starszego/środkowego usuwa dokładnie ten wpis. Ostatni dublet od razu wygrywa. |
| 6. Koniec | Blokada sprawdza aktualną legalność po otwieraniu pociągów; 0–0 zawsze 10. Eliminacje, remis ostatnich, nowe pociągi tylko pozostających. |
| 7–8. Interfejs/komunikaty | Enter wybiera legalny pociąg, C pokazuje listę i jej szczegóły, Escape przywraca rękę/kursor. E/S/T/Z, oznaczenie i odczyt obowiązku; bez obcych kart w komunikatach. |
| 9. Bot | Para kostka–pociąg, własne połączenia, domykanie swojego, kontynuacja dubletu, puste ręce przeciwników, publiczne braki, eliminacja i ostrożna ocena blokady. Bez pełnych permutacji i wszechwiedzy. |
| 10. Integracja | Wspólna neutralna ręka kostek, krótki ruch z trwałym ID celu; zapis/wznowienie także z niezakończonymi dubletami i po dobraniu. |

Testy: `mexican_train_test`, `tile_hand_test`,
`three_games_integration_2_test`. Nie skopiowano z Domino punktacji
pustego dubletu, drużyn, limitu jednego dobrania na całą serię dubletów
ani pozostałych wariantów doboru kostek.

## Wspólna kontrola i granice wyniku

- Pięć ograniczonych śladów po maksymalnie 130 akcji sprawdza po każdym
  kroku zachowanie wszystkich fizycznych kart/kostek, brak duplikatów,
  zgodny replay, powtórzone dostarczenie i prawdziwy format lokalnego zapisu.
  To nie setki symulowanych partii ani statystyczny dowód siły botów.
- Największe przygotowane wyłożenie Rummy: 208 kart w 52 układach,
  12 fragmentów po najwyżej 64 znaki, jedno atomowe dopisanie.
  Limit 50 fragmentów i ograniczenie rozpakowanego payloadu pozostają.
- Polskie źródła: 203 wpisy, 194 teksty nowych gier/interfejsu; placeholdery,
  trzy formy liczby mnogiej i bajtowy odczyt skompilowanego katalogu poprawne.
  Pełny PL.mo zawiera 2514 wpisów. Test zasad obejmuje 19 gier niequizowych.
- Stare zachowanie kursora, edytowalny czat, F1/głośności, ustawienia,
  zaproszenia, reakcje UNO/Makao i zapis pozostałych gier sprawdzono
  odpowiednimi celowanymi regresjami. Cztery stare testy zaktualizowano
  o wspólne definicje i rzeczywisty kontrakt formularza, bez usuwania asercji.
- Nie sprawdzono jeszcze ręcznej rozgrywki trzech nowych gier na dwóch
  prawdziwych klientach, wygody odczytu w rzeczywistym czytniku ani instalacji
  z nowej paczki. Próba API powiadomień nie zastępuje tych kontroli.
- Budżety botów są ograniczone i scenariusze strategiczne przechodzą;
  nie jest to gwarancja optymalnego ruchu ani braku wszelkich błędów.
- Po dodaniu następnych gier trzeba sprawdzić ostateczne źródła i dopiero
  na osobne polecenie zmienić wersję, zbudować/podpisać, a następnie
  zweryfikować manifest, podpis i binarne wczytanie nowej paczki.
