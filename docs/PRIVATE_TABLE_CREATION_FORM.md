# Prywatność w formularzu tworzenia stołu

Poprawka źródeł po podpisaniu 2.0.1/build 229, 18 września 2026.

## Zachowanie

Po wybraniu gry otwiera się jeden wspólny formularz. Pierwszym aktywnym
polem jest „Stół prywatny”, domyślnie odznaczone; dalej są dotychczasowe
opcje gry. „Utwórz stół” zatwierdza całość, bez kolejnego okna. „Anuluj”
lub Escape wychodzi przed utworzeniem stołu i zapisaniem wybranych opcji.
Prywatność pozostaje zaznaczona przy zmianie języka i zestawów oraz po
błędzie walidacji. Następne tworzenie zaczyna od stołu publicznego.

Wspólna obsługa obejmuje wszystkie 23 gry i przyszłe gry bez opcji.
Prywatność jest cechą tworzonego stołu, nie zasadą gry: jest przekazywana
oddzielnie do istniejącego `create_table`, nie trafia do JSON opcji ani
zapamiętanego profilu. Ctrl+X nadal edytuje wyłącznie ustawienia gry.
Nie zmieniono sposobu zapraszania, dostępu do prywatnych stołów ani
pomijania ich w ogłoszeniach publicznych.

## Weryfikacja

Nowy test najpierw odtworzył brak pola prywatności we właściwym formularzu,
przechodząc przez rzeczywiste `show_create_table`. Po poprawce testuje
jedno okno i jedno utworzenie, stoły publiczne/prywatne, anulowanie bez
żądania sieciowego, brak publicznego ogłoszenia stołu prywatnego,
wszystkie gry, Ctrl+X, zmiany języka (także awaryjną przebudowę formularza),
powtórną walidację oraz grę bez własnych opcji.

Test kodowania ładuje aktualne źródła binarnie. Sprawdza 69 formularzy
tworzenia w PL/EN i angielski fallback przy rosyjskim hoście oraz 138
stanów rzeczywistej kontrolki checkbox ELTEN-a. Dodatkowe regresje
obejmują prywatne zaproszenia, publiczne ogłoszenia, edycję i zakończenie
partii, pomoc, profile oraz changelog.

Wyniki: `diagnostics/private-table-form-229/RESULTS.json` w katalogu
roboczym poza repozytorium: 10/10 skryptów celowanych, składnia trzech
Ruby i kontrola diff poprawne. Bez pełnego runnera i rzeczywistych klientów.

## Stan wydania

Nie zmieniono numeru 2.0.1/229, changelogu ani PL.mo; etykieta miała już
tłumaczenie. Nie budowano ani nie podpisywano nowej paczki. Istniejący
podpisany artefakt 229 pozostaje niezmieniony, SHA-256:
`0ac855519fa89f27fbacea4d90c809d0b5b4699bbed751c81df6c0557a180e92`.
Nie zawiera tej poprawki. Niczego nie instalowano, nie publikowano,
nie wysyłano na GitHub ani nie zmieniano na serwerze. Przy następnym
pakowaniu uruchomić `private_table_creation_encoding_test.rb` również
z argumentem wskazującym gotową paczkę.
