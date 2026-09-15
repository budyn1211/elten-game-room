# Uzgodnione zmiany po buildzie 225

Zakres bieżącego polecenia: zaproszenia publiczne i prywatne stoły,
Ctrl+R, strategiczna wycena wymian Monopoly, zapis i wznowienie partii
oraz zatwierdzony później licznik S w Reversi, Warcabach i Szachach.

## Liczniki i odczyt ustawień

S działa wyłącznie jako literowy skrót pola gry. Reversi liczy krążki
obu graczy. Warcaby liczą osobno piony i damki, również na większych
planszach i w trakcie serii bić. Szachy liczą każdy rodzaj figury.
Wszyscy, także obserwator, otrzymują tę samą informację. Odczyt nie
zmienia replaya, kursora ani formularza i nie pyta serwera.

Przyszła gra planszowa może zwrócić `remaining_piece_counts(replay)`:
tablicę opisów w kolejności `replay.players`. Domyślnie zwraca nil,
więc nie dodaje S do gier karcianych ani innych nieobsługiwanych gier.
Gra nadpisująca `shortcut_features` w całości musi dodać `:material`.

Ctrl+R w globalnym menu pokoju i partii oraz na liście stołów odczytuje
ustawienia z tej samej definicji co dokument zasad danego stołu.
Nie kończy oczekiwania formularza ani obliczeń bota. Nie zgaduje
ustawień, jeśli nie ma ich w zaznaczonym rekordzie.

## Zaproszenia i prywatność

Publiczne zaproszenie jest trwałym powiadomieniem aplikacji ważnym pięć
minut. Zawiera również natywny UUID sesji, nie tylko lokalny numer stołu.
Nowa instancja programu korzysta z aktualnego serwerowego discovery, nie
z kolejki zaproszeń starego endpointu. Udane wejście dowolną ścieżką rozlicza
powiadomienia tylko tego stołu. Brak miejsc i błąd sieci nie wycofują ważnego
zaproszenia. Odpowiedź odbiorcy odblokowuje ponowienie u nadawcy.

Otwarcie powiadomienia na głównym ekranie ELTEN-a oznacza je jako przeczytane
jeszcze przed wykonaniem sceny aplikacji. Dlatego `notification_action`
zachowuje konkretny przekazany obiekt przez `InvitationNotifications.with_opened`
podczas wyboru i obu kontroli zaproszenia. Nie wymaga jego ponownej obecności
w aktywnych powiadomieniach. Kontekst kończy się przed zwykłym interfejsem gry,
również przy anulowaniu, odrzuceniu lub wyjątku. Inne przeczytane powiadomienia
nie są przywracane. Nadal sprawdzane są termin, UUID sesji, discovery, miejsca
i natywne prywatne uprawnienie. Błąd sieci nie jest odpowiedzią na zaproszenie;
sam host może już oznaczyć powiadomienie jako przeczytane przy otwarciu.
Poprawkę dołączono do przebudowanego 1.1.10/build 226 z niezmienionym changelogiem.

Każda gra otrzymuje wspólny wybór „Stół prywatny” przy tworzeniu, domyślnie
odznaczony. Prywatność jest natywna, nie jest lokalnym filtrem publicznej
sesji. Takie stoły i ich aktywność nie trafiają na publiczne listy, do widgetu
ani globalnej historii lobby. Zaproszenie prywatne udziela uprawnienia
LiveSessions; nowy endpoint przyjmuje lub odrzuca je przez aktualne discovery
źródła invited. Nie dodano przełącznika Ctrl+H ani migracji sesji.

API nie ma potwierdzonego parametru pięciominutowej ważności natywnego
zaproszenia. Prywatne powiadomienie respektuje termin zwrócony przez serwer
(nie dłużej niż pięć minut); brak takiego terminu jest obsłużonym błędem,
a nie podstawą do wymyślenia ważności. Test modeluje również 120 sekund.

## Wymiany Monopoly

Bot uwzględnia utraconą możliwość zebrania swojej grupy, ostatnią blokadę
grupy przeciwnika, korzyść konkretnego kupującego oraz rezerwę gotówki.
Ocenia zmianę wartości całego portfela przed i po wymianie, nie tylko samą
cenę sprzedawanego pola. Legalność wymian i zasady człowieka nie zmieniły się.
Nie dodano setek symulacji. Celowane przykłady obejmują samotne pole,
oddanie ostatniej blokady, rozbicie własnej grupy i rzeczywiście opłacalną
sprzedaż, która nadal jest akceptowana.

### Automatyczna odmowa zakupu przy braku gotówki — 16 września 2026

Zakup wolnej ulicy, stacji lub zakładu jest automatycznie odrzucany, jeśli
bieżący gracz nie ma pełnej ceny. Mechanizm obejmuje także człowieka, który
nie jest założycielem: jego klient wykonuje zwykłe `decline` przez
`action_for` i wspólny stos, bez podszywania się za niego przez założyciela
i bez nowego typu zdarzenia. Bot nadal korzysta z legalnych ruchów tego
samego silnika. Aukcje pozostają zgodne z ustawieniami, z dotychczasowym
terminem decyzji; dokładnie wystarczająca gotówka nie wywołuje automatu.
Nie zmieniono wymian, bankructwa ani innych gier.

Nowy `monopoly_unaffordable_purchase_test.rb` najpierw odtworzył brak
automatycznej odmowy, następnie przeszedł dla trzech typów nieruchomości,
aukcji włączonej/wyłączonej, gracza niebędącego założycielem, granicy ceny,
duplikatu i wielokrotnego odtworzenia tego samego stosu. Przeszły również
testy aukcji/bankructwa i strategicznej wyceny wymian po buildzie 225,
kontrola składni i `git diff --check`. Nie uruchamiano pełnego runnera.
Poprawkę przygotowano po buildzie 225 i włączono do zakresu wydania 226.
Nie zmieniono sposobu rozliczania majątku bankruta.

## Zapis i wznowienie

Ctrl+S założyciela zapisuje potwierdzoną partię lokalnie i zamyka stół.
Menu „Zapisane gry” zastępuje rankingi i oferuje wznowienie, informację
o ustawieniach oraz usunięcie zapisu. Zapis należy do danego konta.
Quiz i Państwa-miasta nie udostępniają zapisu. UNO wymaga zakończenia wyboru
koloru, Monopoly zakończenia aukcji; zakończonej partii nie zapisuje się.

Najpierw stos otrzymuje granicę pauzy. Zdarzenia już w drodze, zapisane
po tej granicy, nie wchodzą do replaya. Potem odczytywany jest potwierdzony
stos i zapisany JSON z sumą kontrolną. Dopiero po sprawdzeniu odczytu z dysku
zamykana jest sesja. Błąd zapisu nie zamyka stołu i zwalnia pauzę. Nieudane
zamknięcie zachowuje zweryfikowane archiwum i próbuje zwolnić pauzę nadal
otwartego stołu. Ruch kolidujący z pauzą nie powoduje błędu aplikacji ani
sztucznego trzydziestosekundowego opóźnienia sieciowego.

Wznowienie tworzy nowy stół z pierwotnymi ustawieniami i prywatnością,
zaprasza tych samych ludzi, odtwarza boty i czeka na wszystkich uczestników.
Nie zastępuje nieobecnych graczy komputerami. Zachowane są kolejność miejsc,
identyfikatory zdarzeń, losowania i pozostały czas na ruch. Boty otrzymują ID
nowego stołu; Tysiąc mapuje również nazwy adresatów przekazanych kart.
Przerwa, oczekiwanie na uczestników i przesyłanie archiwum nie zużywają
czasu gry. Anulowanie/wznowienie nie usuwa jedynego lokalnego zapisu.

Archiwum ma format JSON 1 i wersję schematu konkretnej gry. Odtworzenie
weryfikuje wszystkie zdarzenia tym samym silnikiem reguł co zwykła gra.
Nie wczytuje Marshal ani kodu z zapisu. Import jest dzielony na małe porcje;
czytelnicy nie otrzymują niekompletnej partii. Limit 40 880 zdarzeń jest
sprawdzany przed zamknięciem, zgodnie z pojemnością natywnego stosu.

## Zgodność i weryfikacja

Prywatne stoły oraz stoły wznowienia ogłaszają protokół discovery 3, aby
starsze klienty nie wchodziły do nieobsługiwanego archiwum ani nie ujawniały
prywatnej aktywności. Zwykły stół publiczny zachowuje protokół 2. Format
zwykłych pakietów ruchów nie został zastąpiony. Dla nowych funkcji uczestnicy
powinni używać aktualnego Game Roomu.

Celowane testy obejmują zapis i wznowienie wszystkich 15 obsługiwanych gier,
dwie niezależne instancje/endpointy, prywatne uprawnienia, awarie dysku i sieci,
przesyłanie archiwum, liczniki, dynamiczne F1 i polskie tłumaczenia.
To testy automatyczne z modelem rzeczywistego API, nie próba na serwerze ani
rzeczywistych klientach. Przeszło 27/27 celowanych skryptów, kontrola składni
59 zmienionych/nowych Ruby i `git diff --check`. Nie uruchamiano pełnego runnera.
Raport: `../diagnostics/changes-after-225/TESTS.json`.

Zmiany przygotowano dla wersji 1.1.10/build 226. Changelog ma jeden nagłówek
wersji i buildu oraz osiem zmian, po angielsku i polsku. Przed pakowaniem
przeszło 15 celowanych skryptów, w tym zapis i wznowienie 15 gier.
Weryfikacja wydania obejmuje podpis autora, zgodność źródeł oraz binarne
wczytanie gotowej paczki. Raporty wydania: `../diagnostics/build-226/`.
Instalowanie i publikowanie wymagają osobnego polecenia użytkownika.
