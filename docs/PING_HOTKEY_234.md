# Ctrl+F4 po aktualizacji — 2.0.2.3/build 234

## Przyczyna odtworzona w kodzie

Stara obsługa klawiszy pozostaje na wspólnym obiekcie QuickActions ELTEN-a
po przeładowaniu aplikacji. Rozpoznaje tylko F1, F2/F3 i Shift+F2/F3.
Flaga „już zainstalowano” blokowała jej wymianę na wersję z Ctrl+F4.
W tym scenariuszu naciśnięcie skrótu nie uruchamiało pomiaru.
Dotychczasowy test sprawdzał wyłącznie świeżo zainstalowaną obsługę.

Nie odczytywano stanu działającego klienta użytkownika: odtworzenie
potwierdza ten błąd, nie dowodzi, że wyjaśnia każdy przypadek braku reakcji.

## Zmiana

- Jednorazowe uaktualnienie starej obsługi bez restartowania ELTEN-a.
- Wspólny most pyta bieżącą kontrolkę o obsługiwane klawisze. Nie utrwala
  ich listy w obiekcie hosta, który przeżywa kolejne aktualizacje aplikacji.
- Formularz przechwytuje wyłącznie własne klawisze. Pozostałe skróty
  oraz wszystkie skróty poza Game Roomem zachowują zachowanie ELTEN-a.
- Pomiar pozostaje pojedynczym żądaniem HTTP w tle. Komunikat PL:
  „HTTP: 42 ms.” lub „HTTP: pomiar niedostępny.”.
- Na dodatkowe polecenie użytkownika aktywny klient Ponga udostępnia
  wspólnemu odczytowi również swój kanał Communications. Wynik zawiera
  wtedy osobną informację, np. „Communications UDP, serwer pośredniczący:
  13 ms.”. Działa to też w czacie, pomocy i ustawieniach lokalnych Ponga.
- Communications korzysta z ostatniego natywnego pomiaru UDP RTT do relay,
  który ELTEN już okresowo odświeża. Sprawdzenie `fast_path?` odrzuca
  przeterminowany wynik. Bez pomiaru UDP (np. przy zastępczym TCP) odczyt
  mówi, że pomiar Communications UDP jest niedostępny; nie udaje pomiaru
  TCP ani pełnej drogi do drugiego gracza. Zamknięty kanał nie jest czytany.
- Bez nowych sond Communications, zmian sposobu wysyłania i odbioru
  pakietów, fizyki ani dźwięków. Zamknięcie starego meczu nie usuwa
  referencji do kanału, który zdążył już zarejestrować jego następca.

## Regresja

`test/ping_hotkey_reload_test.rb` najpierw instaluje rzeczywisty wzorzec
starego mostu, a potem ładuje aktualną aplikację i uruchamia test pomiaru.
Przed poprawką test odtwarza brak wyniku. Po poprawce przechodzi również
przez natywną obsługę Ctrl+F4 (kod 16), sprawdza modyfikatory, brak zmian
w tekście/zaznaczeniu czatu, natywne skróty i wielokrotną instalację.
`post_233_ping_test.rb` zachowuje test świeżego startu, formularzy, widgetu,
timeoutu, błędów, pojedynczego pracownika i prawdziwej ścieżki API z atrapą
klienta. Test słownika sprawdza binarnie wczytane teksty PL/EN/fallback.
`ping_communications_test.rb` sprawdza rozdzielone pomiary, jednostki,
brak dodatkowych operacji sieciowych, aktywność kanału, ważność danych UDP,
zastępczy TCP, błędne wartości, błąd HTTP i odpinanie zamkniętego klienta.

Wydanie 234 obejmuje też wcześniej sprawdzone poprawki opisane w
`PONG_RELAY_DELIVERY_233.md`, `PONG_IMMEDIATE_DISPATCH_233.md`
i `PONG_RECEIVE_INVITATION_233.md`. Nie zmienia zasad ani tolerancji obrony.
