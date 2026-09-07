# Testowanie i budowanie

## Testy bez ELTEN-a

Testy są samodzielnymi skryptami i korzystają tylko z biblioteki standardowej
Ruby. Zalecana jest wersja Ruby 4.0, zgodna ze środowiskiem bieżącego ELTEN-a.

```console
ruby tools/run-tests.rb
```

Runner zatrzymuje się po pierwszym nieudanym teście i zwraca niezerowy kod.

## Uruchomienie ze źródeł

Do testu integracyjnego umieść katalog aplikacji tak, aby `__app.rb` znajdował
się w katalogu programu deweloperskiego ELTEN-a, na przykład
`dev_apps/game_platform/`. Uruchom ELTEN-a ze źródeł lub w trybie debugowania i
otwórz ELTEN Game Room z menu programów.

Używaj oddzielnego profilu testowego, jeśli test może zmieniać dane stołów.
Nie kopiuj profilu, logów ani ustawień MCP do repozytorium.

## Paczka niepodpisana

Paczki buduje narzędzie z repozytorium ELTEN-a. Przykład:

```console
ruby C:/src/elten3/tools/build-eltsetup.rb --unsigned C:/src/elten-game-room C:/build/ELTEN-Game-Room.eltsetup
```

Ruby używane do budowania musi mieć zależności wymagane przez narzędzie ELTEN-a,
w szczególności `zstd-ruby`. Najprościej użyć środowiska uruchomieniowego
przygotowanego razem ze źródłami ELTEN-a.

## Paczka podpisana

Podpisaną paczkę przygotowuje wyłącznie autor wydania:

```console
ruby C:/src/elten3/tools/build-eltsetup.rb --cert C:/private/author.crt.pem --key C:/private/author.key.pem C:/src/elten-game-room C:/build/ELTEN-Game-Room-signed.eltsetup
```

Certyfikat i klucz muszą pozostać poza repozytorium. Pliki `.eltsetup` również
nie są śledzone — dystrybucja odbywa się przez katalog programów ELTEN-a.

## Przygotowanie wydania

1. Uruchom wszystkie testy i test ręczny na co najmniej dwóch klientach, jeśli
   zmienia się komunikacja.
2. Zaktualizuj `version` i `build_id` równocześnie w `__app.rb` i
   `manifest.json`.
3. Uzupełnij `CHANGELOG.md`.
4. Zbuduj paczkę podpisaną i zweryfikuj jej manifest, podpis oraz zawartość.
5. Dopiero potem prześlij paczkę przez konto autora w ELTEN-ie.
