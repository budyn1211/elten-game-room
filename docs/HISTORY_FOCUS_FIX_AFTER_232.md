# Historia: odczyt po Tabie i odstępy

21 września 2026. Poprawka źródeł po podpisanej paczce 232.

Odtworzono oba zgłoszenia przed zmianą produkcyjnego kodu. Pusty wiersz
pochodził z łączenia wpisów przez dwa znaki końca wiersza. Natywne
EditBox#focus wywołuje read_text(0), niezależnie od aktualnego kursora.
Odczyt całego pola dodatkowo przesuwa kursor przez callbacki syntezy.

GameRoomHistory::View łączy teraz wpisy pojedynczym końcem wiersza
i odpowiednio wylicza ich pozycje. Zachowuje wielowierszową treść samego
wpisu. Podczas focus przechwytuje wyłącznie jego automatyczne read_text:
czyta nagłówek i bieżący wpis, bez zmiany kursora i zaznaczenia. Natywne
oznaczenie pola, dźwięk, Braille i mechanizm cichego odświeżania pozostają.
Ręczne polecenie odczytania całego tekstu nadal korzysta z normalnego
read_text; inne pola, czat i pomoc F1 nie zostały zmienione.

Regresja używa rzeczywistego EditBox ELTEN-a, zastępując wyłącznie urządzenia
mowy/Braille. Sprawdza środkowy, pierwszy, ostatni i pusty wpis, Unicode,
zaznaczenie, fokus bez odczytu, jawny Read all, niezmienioną pomoc oraz
nowe odstępy. Celowane testy obejmują też wspólną powierzchnię, pokój,
nawigację historii i cykl pomocy. Wyniki przed/po poza repozytorium:
`diagnostics/history-focus-232/BEFORE.json` i `SOURCE.json`.

Użytkownik skorygował numer NASTĘPNEJ paczki na 2.0.2.1. Nie zmieniono
historycznego changelogu 232 ani podpisanej paczki, nie zbudowano nowej.
Przy kolejnym poleceniu pakowania ustawić zgodnie wersję w manifestach,
runtime i nowym wpisie changelogu. Bez pełnego runnera, instalacji,
publikacji, GitHuba, serwera, restartów i zmian żywych profili.

## Późniejsze polecenie przebudowy

Użytkownik zatwierdził ponowne podpisanie, ale nakazał zachować build 232
i treść dotychczasowego changelogu. Nie dodawać wpisu ani nowego punktu;
zmienić tylko wersję bieżącego nagłówka, manifestów i runtime na 2.0.2.1.
Poprzednią paczkę zachować jako before-history-focus-signed.eltsetup.
Weryfikacja gotowego wydania: diagnostics/history-focus-release-232/
SOURCE.json oraz PACKAGE.json. Sam ten wpis nie oznacza końca pakowania.
