# Communications: przyjęcie zaproszenia i wcześniejszy odbiór

22 września 2026. Wdrożenie na polecenie „to poprawiaj i testuj dalej”.
Zmiany lokalne; wersja 2.0.2.2/build 233/API 3.0.3, bez nowej paczki.

## Naprawiony błąd zaproszenia

ELTEN udostępnia to samo zaproszenie przez callback i next_invitation.
Poprzednio druga ścieżka mogła ponownie ustawić pending, kiedy pierwsze
przyjęcie trwało już w tle. Po poprawnym podłączeniu następowała druga
próba accept, kończąca się SessionClosed.

Channel pamięta obecnie zaproszenie przyjmowane oraz identyfikator ostatnio
przyjętego zaproszenia. Sprawdza również aktualny status przed uruchomieniem
zadania i przed RPC. Zamknięcie/zmiana generacji blokuje nieaktualną pracę,
a sesja zwrócona po zamknięciu jest zwalniana. Nie dodano nieograniczonej
historii identyfikatorów. Błąd pojedynczego przyjęcia nie blokuje nowego
zaproszenia. Nie jest to dowód, że ten błąd powodował każdy dawny zastój.

## Odbiór w tej samej klatce

Publiczne Session.receive(timeout: 0) pobiera tylko gotowy element lokalnej
kolejki ELTEN-a. Aktualne źródła Session/EventQueue i test natywnej klasy
potwierdzają: bez RPC, oczekiwania ani pompowania interfejsu.

Channel.tick odbiera najwyżej 128 elementów w klatce. Callbacki pozostają,
ale obie drogi przechodzą przez te same kontrole nadawcy, generacji, rodzaju
i numeru wiadomości. EventChannel nadal wykrywa lukę sekwencji, odrzuca
duplikaty i unieważnia starą kolejkę przy odzyskiwaniu. Sesja bez publicznego
receive zachowuje dotychczasową obsługę callbacków.

To nie osobny wątek silnika ani zmiana globalnej pętli ELTEN-a. Wiadomość
nie musi czekać na kolejną serię callbacków, lecz nadal potrzebuje klatki gry.
Pauzy głównego wątku, w tym niewyjaśnione wcześniejsze 485 ms, nie są przez
to uznane za naprawione. Właściciel kanału musi regularnie wywoływać tick;
native receive deklaruje aktywnego konsumenta kolejki, więc nie należy
włączać go w komponencie, który później przestaje ją obsługiwać.

## Potwierdzenie bramki

PeerPlay wysyła stan nowo rozpoznanej bramki od razu, zamiast czekać na
najbliższy okresowy komunikat pozycji (do 40 ms). Jednorazowy priorytet jest
związany z generacją, wymianą, numerem odbicia i wynikiem. Okresowe ponowienia
pozostają na wypadek utraty UDP. Sam status nie przyznaje punktu: wymagane
pozostają zgodne wyniki wszystkich uczestniczących graczy. Trwały zapis
należy nadal do GameScreen/GameRepository/LiveSessions.

Nie zmieniono silników, tolerancji obrony, zasad debla, punktacji, audio ani
formatu protokołu. Zmiany produkcyjne dotyczą tylko channel.rb,
event_channel.rb i peer_play.rb. Rename receive -> deliver_message w
test/support/pong_relay.rb rozdziela pomocnik atrapy od natywnego receive.

## Weryfikacja

30/30 celowanych skryptów, 8 kontroli składni i diff check poprawne.
Nowe regresje odtworzyły podwójne przyjęcie oraz zbędne czekanie odbioru
i stanu bramki przed poprawkami. Test rzeczywistego Session/EventQueue
obsłużył 18 000 wiadomości z naprzemienną kolejnością callback/poll, bez
narastania kolejki. Sprawdzono anulowanie, stare sesje, luki, autoryzację,
granice partii pracy, ponowny start i zachowanie po wolnym zapisie punktu.
Symulowane 32 wymiany obejmują single/debel, obie kolejności drużyn,
Arcade, gospodarza-obserwatora, jitter i pomijanie pozycji.

Dodatkowo dwie żywe kopie papierek/papiertestowy rozegrały na jednym
prywatnym stole dwa mecze próbne (limit 7 -> 21): łącznie 11 zakończonych
punktów, 13 serwów i 87 odbić. Wszystkie 100 serwów/odbić przyjął drugi
silnik; wszystkie wyniki zgodne. W drugiej próbie to samo zaproszenie
rzeczywiście rozpatrzono dwa razy, a przyjęto tylko raz. Brak błędu accept.

Kandydat był ładowany do odrębnych tymczasowych klas, bez instalacji i bez
zastępowania klas programu/globalnego ELTEN-a. Próba używała normalnego
wejścia klienta i realnych Communications/LiveSessions, bez ustawiania
piłki lub wyniku. Tymczasowa fabryka klienta, rozszerzenie, sondy i stół
zostały usunięte; oba programy wróciły do Scene_Main, zasoby: zero.

Raporty prywatnej diagnostyki poza repozytorium:
../diagnostics/pong-receive-invitation-233/{README.md,SOURCE.json,RESULT.json}.
Nie były to cztery osoby na osobnych komputerach. Nie przeprowadzono
odsłuchu, pełnego runnera, buildu, instalacji, publikacji ani wysyłki GitHub.
Dotychczasowy podpisany instalator NIE zawiera tych poprawek.
