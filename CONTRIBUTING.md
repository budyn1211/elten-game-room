# Współtworzenie ELTEN Game Room

Dziękuję za chęć pomocy. Projekt jest przede wszystkim interfejsem dźwiękowym i
klawiaturowym, dlatego poprawność działania z czytnikiem ekranu jest tak samo
ważna jak poprawność reguł gry.

## Zasady pracy

1. Utwórz gałąź od aktualnego `main`.
2. Jedna gałąź i jeden pull request powinny rozwiązywać jeden spójny problem.
3. Dodawaj lub aktualizuj test odtwarzający zmieniane zachowanie.
4. Uruchom `ruby tools/run-tests.rb`.
5. W opisie pull requesta podaj przyczynę, zakres zmiany i sposób ręcznego
   sprawdzenia w ELTEN-ie.

## Ważne ograniczenia projektu

- Korzystaj z event-driven UI ELTEN-a oraz wspólnych klas w `lib/`.
- Nie dodawaj ręcznej pętli zdarzeń ani okresowego odświeżania, jeśli istnieje
  zdarzeniowy mechanizm aktualizacji.
- Nie omijaj `GameRepository`, walidacji gry ani `GameRoomTransport` przy
  zapisywaniu ruchu.
- Publiczne stoły wyszukuj przez discovery LiveSessions, a ich stan zapisuj w
  stosie sesji. Nie dodawaj pomocniczych tabel ani Signals do dołączania,
  synchronizacji pokoju lub ruchów.
- Komunikaty powinny być krótkie, jednoznaczne i możliwe do przejrzenia w
  historii. Unikaj niepotrzebnego odbudowywania formularza i przesuwania fokusu.
- Nie zmieniaj numeru wersji ani buildu w zwykłym pull requeście. Robi to autor
  podczas przygotowania wydania.

## Bezpieczeństwo i prywatność

Nigdy nie dodawaj do repozytorium:

- tokenów MCP lub nagłówków autoryzacyjnych;
- certyfikatu albo prywatnego klucza podpisującego;
- profilu ELTEN-a, logów zawierających prywatne rozmowy lub danych kont;
- gotowych podpisanych paczek `.eltsetup`.

Przed dołączeniem logu usuń nazwy użytkowników, tokeny i treści prywatne, jeśli
nie są niezbędne do odtworzenia problemu.

## Tłumaczenia interfejsu

Jedynym edytowalnym źródłem tłumaczeń danego języka jest jego plik
`locale/<LANG>.po`, np. `PL.po`. Używamy standardu GetText jak ELTEN.
Po zmianach angielskich napisów uruchom `ruby tools/translations.rb update`;
po tłumaczeniu `ruby tools/translations.rb compile PL` i `check PL`.
Dawne `*-pl.json`, polskie pola zasad i polskie listy zmian są generowane
z PO i nie mogą nadpisywać pracy tłumacza. Słowniki Scrabble/Krowy, pytania
quizu i karty Taboo pozostają osobnymi danymi rozgrywki.
Zależności i dokładny przebieg: `locale/README.md`.

## Nowe gry

Nowa gra powinna mieć stabilne reguły, deterministyczne odtwarzanie z listy
zdarzeń, testy legalnych i nielegalnych ruchów oraz dostępny interfejs oparty na
wspólnych powierzchniach. Szczegółowa lista kontrolna jest w
`docs/ADDING_A_GAME.md`.
