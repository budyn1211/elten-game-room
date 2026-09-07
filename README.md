# ELTEN Game Room

ELTEN Game Room to dostępny zestaw gier wieloosobowych działający jako program
dla ELTEN-a. Repozytorium zaczyna historię od opublikowanej wersji **1.1.0,
build 176**. Kod aplikacji, tłumaczenie i dźwięki w tym pierwszym stanie są
bezpośrednią kopią tego buildu.

Szczegóły pochodzenia i sumę podpisanej paczki zapisano w
[BASELINE.md](docs/BASELINE.md).

## Gry

- Czwórki
- Kółko i krzyżyk
- Szachy
- Warcaby
- Reversi
- Chińczyk
- Spades
- Farkle
- Ninety-Nine
- Tysiąc
- Państwa-Miasta

Program zawiera wspólny szkielet stołów, historii, dostępnych plansz i innych
powierzchni gry, skrótów klawiszowych, reguł, botów, punktacji oraz komunikacji
przez LiveSessions. Nowa gra powinna wykorzystywać te elementy zamiast budować
osobny interfejs i własną pętlę zdarzeń.

## Wymagania

- ELTEN z API 3.0.2 lub nowszym;
- Ruby 4.0 do uruchamiania lokalnych testów;
- repozytorium ELTEN-a i jego środowisko budowania tylko wtedy, gdy chcesz
  utworzyć paczkę `.eltsetup`.

Sama aplikacja nie używa zewnętrznego pliku konfiguracyjnego ani prywatnych
kluczy. Łączy się z zadeklarowaną aplikacją serwerową ELTEN-a.

## Testy

W katalogu repozytorium uruchom:

```console
ruby tools/run-tests.rb
```

Każdy test jest również samodzielnym skryptem Ruby, więc można uruchomić tylko
wybrany plik, na przykład:

```console
ruby test/ninety_nine_test.rb
```

## Praca nad kodem

Najważniejsze punkty wejścia:

- `__app.rb` — manifest, tabele serwerowe, rejestr gier i główna klasa programu;
- `games/` — reguły i modele poszczególnych gier;
- `lib/game_surfaces/` — wspólne kontrolki dostępnego pola gry;
- `lib/game_screen.rb` — wspólny ekran partii;
- `lib/game_room_transport.rb` — komunikacja LiveSessions;
- `lib/game_repository.rb` — zapis i odtwarzanie zdarzeń partii;
- `lib/game_bots.rb` oraz pliki `*_strategy.rb` — boty i strategie;
- `test/` — testy modeli, transportu, interfejsu i regresji.

Dokładniejszy opis znajduje się w [architekturze](docs/ARCHITECTURE.md), a
instrukcja dodawania gry w [ADDING_A_GAME.md](docs/ADDING_A_GAME.md).

## Budowanie paczki

Instrukcja tworzenia niepodpisanej i podpisanej paczki znajduje się w
[BUILDING.md](docs/BUILDING.md). Certyfikat i klucz autora nigdy nie powinny
trafić do repozytorium.

## Zgłoszenia i pull requesty

Przed zmianą przeczytaj [CONTRIBUTING.md](CONTRIBUTING.md). Zgłoszenie błędu
powinno zawierać numer buildu, kroki odtworzenia, oczekiwany rezultat i — jeśli
to możliwe — krótki fragment logu bez danych prywatnych.

## Licencja i zasoby

Kod ELTEN Game Room jest udostępniany na licencji GNU General Public License
version 3. Pełny tekst znajduje się w pliku [LICENSE](LICENSE). Pochodzenie i
odrębne warunki dodatkowych składników opisuje
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
