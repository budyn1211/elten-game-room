# Pong, nazwy kart i dźwięki — 2.0.2.2 / build 233

## Własne kroki gościa w meczu z botami

Gdy wszyscy uczestnicy są ludźmi, każdy używa lokalnego PeerEngine.
Jeśli jest choć jeden bot, autorytatywny Engine działa tylko u właściciela.
Gość obliczał pozycję swojej myszy lokalnie, ale dźwięk kroków czekał na
wysłanie wejścia i powrót snapshotu. Jitter potrafił skleić kilka kroków.
Lokalna diagnoza dwóch ludzi i dwóch botów: gospodarz miał 10 równych
sygnałów, gość 5 opóźnionych. To odtworzenie, nie pomiar żywego zgłoszenia.

PaddleFeedback korzysta z już obliczonego wejścia myszy/klawiatury i daje
lokalny dźwięk tylko własnych kroków oraz dojścia do bandy. Nie symuluje
piłki, odbić, bramek ani botów i nie zmienia wysyłanych pakietów. Opóźnione
własne step/edge są pomijane przy odczycie snapshotu, ale ich numer nadal
jest konsumowany. Inne efekty pozostają autorytatywne. Prezentacja kopiuje
tylko własną pozycję, bez mutowania stanu otrzymanego od właściciela.

Przy braku natywnej myszy klawiatura zachowuje dotychczasowy rytm; lokalna
pozycja jest cicho uzgadniana ze stanem właściciela po zwolnieniu klawisza.
Zmiana rundy, opuszczenie pola, ustawienia, utrata aktywności lub duża luka
czasowa wygaszają predykcję. Gość nie steruje z czatu ani okna sieciowego.
Ścieżka PeerPlay dla samych ludzi i silnik gospodarza pozostają niezmienione.

## Dźwięki debla i UNO

- Pierwsza osoba w każdej drużynie (A/C przy składzie AB przeciw CD) używa
  `pong_move_double`. Druga zachowuje poprzednie kroki. Wysokość kroków
  nadal zależy od pozycji, ale nie ma dodatkowego przesunięcia o półtony.
- Serwisy/odbicia A/C, także tarczą, są niższe o cztery półtony.
- Osobne głosy graczy zachowują niezależny odczyt, reset i panoramę.
  Poziom kroków to nadal 50% dla własnej strony i 20% dla przeciwnej,
  przemnożone przez właściwe lokalne ustawienia głośności.
- Karta brzęczyka UNO daje jednocześnie zwykły dźwięk zagrania i `buzzer`.
  Potwierdzenie B nie powtarza go; powiedzenie UNO/Makao nadal używa buzzer2.
- Oba nowe pliki to Opus 144 kb/s VBR, mono 48 kHz, ramki 20 ms, bez filtrów
  głośności i przycinania. Oryginały pozostają w katalogach użytkownika.

## Nazwy i tłumaczenia

Polskie UNO używa m.in. „pomiń”, „zmiana kierunku”, „zmiana koloru”,
„zmiana koloru i dobierz cztery”, „odrzuć wszystkie”, „ruletka kolorów”,
„odwróć karty” i „brzęczyk”. Kolor i wartość nie są rozdzielane przecinkiem.
Poprawiono też „pomarańczony” na „pomarańczowy”. Nazwy obejmują Classic,
No Mercy i obie strony Flip. Sortowanie i identyfikatory pozostają bez zmian.

Rummy wyświetla się po polsku jako Remik; nazwa jest też w zasadach.
ID `rummy`, klasa, opcje, zapisy i nazwa angielska pozostają bez zmian.
Debel ma polskie nazwy wariantów, poziomów trudności, drużyn, wyników,
ograniczeń konfiguracji i zapowiedź serwującego/odbierającego.

## Kontrole i wydanie

Regresje: lokalny rytm obu graczy, jitter, dwie osoby z dwoma botami,
czterech ludzi, obserwujący gospodarz, myszy i klawiatura awaryjna,
powrót z czatu, granice, koniec punktu, brak echa zdarzeń, niezależne głosy
wszystkich ustawień drużyn, mute/głośność/reset. Słownik jest sprawdzany
na rzeczywistym Dictionary ELTEN-a przy binarnym wczytywaniu źródeł,
po polsku, po angielsku oraz przy brakującym tłumaczeniu.

Wyniki wydania: `../diagnostics/pong-feedback-release-233/` poza repo.
Nowy krótki changelog ma cztery punkty PL/EN; historyczne wpisy zachowane.
Bez pełnego runnera, odsłuchu urządzenia, żywego meczu, instalacji,
publikacji, GitHuba i zmian serwera/profili. Testy symulacyjne oraz
dekodowanie audio nie zastępują odsłuchu użytkownika.

## Dodatkowe ściszenie po wydaniu 233 — jeszcze bez paczki

Po odsłuchu użytkownik zatwierdził dodatkowe -3 dB dla samego
`pong_move_double`. Kod mnoży jego poziom przez 10^(-3/20), około 0,707946,
przed ograniczeniem kanałów. Własna strona ma przy domyślnych suwakach
poziom około 0,353973, przeciwna około 0,141589. Bazowe 50%/20%, ustawienia
użytkownika, panorama, częstotliwość i wszystkie inne efekty są zachowane.
Plik Opus nie jest zmieniany ani ponownie kodowany.

Regresja najpierw wykazała brak tych 3 dB, potem przeszło pięć celowanych
skryptów: doubles_audio, movement_voices, local_feedback, audio_reference
i audio_feedback. Sprawdzono wszystkie składy/perspektywy, ścieżkę kroków
lokalnych i zdalnych, zmianę głośności oraz brak kumulowania ściszenia
przy kolejnych odświeżeniach. To testy bez urządzenia wyjściowego.
Podpisana paczka 233 pozostaje bez zmian; nie zawiera tej korekty.
