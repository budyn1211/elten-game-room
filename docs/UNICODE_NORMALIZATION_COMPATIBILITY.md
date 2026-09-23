# Zgodność normalizacji Unicode — 23 września 2026

## Błąd i zakres poprawki

Instalacja mogła przerwać się podczas wczytywania Game Roomu z błędem
`NameError: uninitialized constant Encoding::UNICODE_VERSION`.
Dołączone do programu tabele Ruby wymagały tej stałej oraz dokładnie wersji
17.0.0. Inna wartość powodowała osobny `RuntimeError`. Nie znamy wersji Ruby
osoby zgłaszającej; potwierdzono natomiast brak tej stałej także w osobnym
Ruby 3.3.9. Nie jest to dowód, że zgłaszający używał właśnie tej wersji.

Sprawdzenie zachowanych instalatorów wykazało identyczne pliki normalizatora
już w buildach 176, 217, 229 i 230 oraz sprawdzonych paczkach 231, 232 i 236.
Nie ustalono, dlaczego niezgodność ujawniła się u zgłaszającego dopiero po
jednej z aktualizacji 2.0.2; nie przypisujemy tego odchudzaniu paczki.

Zmiany produkcyjne ograniczono do dwóch plików vendora:

- `tables.rb`: wersja 17.0.0 jest informacją o własnych, kompletnych tabelach,
  nie wymaganiem wobec `Encoding` hosta;
- `normalize.rb`: dwa niejawne parametry `it` zastąpiono jawnymi parametrami
  bloków. Zachowano algorytm, sortowanie akcentów i wszystkie dane.

Cały wygenerowany fragment tabel od `accents` do końca pliku pozostał
identyczny (po ujednoliceniu CRLF/LF): 228 938 bajtów, SHA-256
`f427d7c327265f1b7eedacac33cc66291213093329442a842ee7a87f152dd624`.
Pozostają NFC, NFD, NFKC i NFKD. Nie dodano globalnych stałych `Encoding`,
nie zamieniono błędu na ciche pomijanie normalizacji i nie zmieniono danych
słowników, pytań, protokołu, wersji ani changelogu.

## Regresja i dalsze aktualizacje vendora

`test/unicode_normalization_compatibility_test.rb` ładuje rzeczywiste źródła
jako dane binarne w osobnej przestrzeni aplikacji. Testuje brak stałej hosta,
wartość 15.0.0 oraz 17.0.0, pilnując niezmieniania hosta. Sprawdza polskie
litery złożone i rozłożone, kolejność akcentów, Hangul, mapowania nowsze niż
Unicode 15, idempotencję, kodowania UTF-16/32 i odrzucanie wadliwego wejścia.
Test najpierw odtworzył zgłoszony `NameError` na starym kodzie.

Opcjonalny pierwszy argument testu to oficjalny plik
[NormalizationTest 17.0.0](https://www.unicode.org/Public/17.0.0/ucd/NormalizationTest.txt).
Test sprawdza jego SHA-256 przed wykonaniem wszystkich 20 034 wierszy oraz
wszystkich 20 normalizacji na wiersz, także metodę `normalized?`. W trzech
konfiguracjach hosta daje to 2 404 080 asercji na interpreter. Nie oznacza to
osobnego przeglądu każdego nieujętego w tych wierszach punktu kodowego.
Plik testowy pozostaje poza repozytorium i instalatorem.

Te próby przeszły na Ruby 4.0.6 oraz przenośnym Ruby 3.3.9 pobranym z
[oficjalnego wydania RubyInstaller](https://github.com/oneclick/rubyinstaller2/releases/tag/RubyInstaller-3.3.9-1).
Nie instalowano go w systemie ani nie zmieniano Ruby działającego ELTEN-a.
Ponadto na obu interpreterach przeszły celowane testy danych, Scrabble,
Krowy, uruchomienia quizu i binarnego wczytania aplikacji. Kontrola natywnych
formularzy obejmuje języki PL/EN oraz brak tłumaczenia przy rosyjskim hoście.
Nie uruchamiano pełnego runnera.

Przy aktualizacji vendora nie kopiować wymagań konkretnego Ruby ani jego
wewnętrznych stałych bez sprawdzenia przenośności. Zachować licencje oraz
test na starszym interpreterze, nie tylko brak stałej symulowany na nowym.

To poprawka źródeł. Nie zbudowano ani nie podpisano nowej paczki, nie
zainstalowano jej, nie zmieniono serwera i niczego nie wysłano na GitHub.
Obecna podpisana paczka 237 nadal zawiera stary normalizator.
