# Tryb obserwatora i poprawki interfejsu — build 215

## Tryb obserwatora

Ctrl+Shift+O i wspólne menu kontekstowe przełączają własną rolę na następną
partię. Rola jest zapisana jako uporządkowane zdarzenie pokoju LiveSessions,
więc wszyscy uczestnicy widzą ten sam skład. Obserwator nadal należy do sesji,
widzi stół, czat i historię, lecz nie trafia na listę graczy nowej partii.
Zmiana podczas trwającej partii nie modyfikuje jej składu.

Właściciel LiveSession może obserwować i nadal zarządzać stołem. Automatyczne
przejścia gry są wtedy zapisywane przez właściciela w imieniu pierwszego
rzeczywistego gracza; transport jawnie oznacza i sprawdza taki zapis. Przed
startem transport ponownie odczytuje role i odrzuca próbę umieszczenia
obserwatora w składzie.

## Pozostałe poprawki

- Zaproszenia mają wspólny pięciominutowy czas ważności, również gdy natywne
  API zgłasza dłuższy termin.
- Skrót D Makao zwraca komunikat o pustej ręce przed rozdaniem i obserwatorom.
- Skróty UNO są rozdzielone: C podaje kartę, V aktualny kolor.
- Jedno zdarzenie może uruchomić kilka niezależnych dźwięków bez wzajemnego
  zastępowania.
