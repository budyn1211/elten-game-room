# Drugi audyt pytań odrzuconych po buildzie 221

Po podpisaniu builda 221 ponownie rozpatrzono każde z 20 730 pytań odrzuconych
w audycie builda 220. Celem nie było masowe przywracanie pytań wyglądających
wiarygodnie, lecz wychwycenie fałszywych odrzuceń bez ponownego wpuszczenia
pytań niejednoznacznych.

## Wynik

| Zestaw | Przed drugim audytem | Przywrócono | Po drugim audycie | Nadal odrzucone |
|---|---:|---:|---:|---:|
| angielski ogólny | 13 836 | 67 | 13 903 | 14 672 |
| polski ogólny | 10 939 | 149 | 11 088 | 4 340 |
| Wiedźmin | 5 069 | 68 | 5 137 | 1 434 |

W Wiedźminie po przywróceniu jest 2 670 pytań o gry oraz 2 467 pytań o
książki i ekranizacje. Zestawy szczegółowe nadal są rozłączne i razem tworzą
pełny zestaw.

## Kryteria

Każde wcześniejsze odrzucenie otrzymało nową decyzję. Pytanie przywracano tylko
wtedy, gdy dowód potwierdzał dokładną relację podaną w pytaniu, odpowiedź była
jedyna spośród wszystkich wariantów, a treść nie zależała od brakującego
kontekstu. W pytaniach wiedźmińskich wymagano również dowodu pochodzącego z
właściwego medium.

Odpowiedzi oceniano łącznie, a nie osobno. Szczególnie sprawdzano pułapki typu
część–całość: „brat” wobec „brat i siostra”, nazwę kraju wobec szerszego
państwa, klasę chemiczną wobec ogólnego „związek chemiczny” oraz pojedynczą
wartość wobec zakresu. Samo zawieranie się tekstu nie oznacza automatycznie
błędu; decyduje treść pytania i to, czy źródło potwierdza pełny wymagany zestaw.

W polskiej chemii przywrócono tylko bezpośrednio potwierdzone wzory, konkretne
klasy, zastosowania opisane jako jedno z możliwych oraz wartości twardości,
dla których żadna odpowiedź błędna nie mieściła się w podanym zakresie.
Pytania ogólne, nakładające się klasy i niepewne relacje osobowe pozostały
odrzucone.

W angielskim zestawie szerokie automatyczne wysłanie wszystkich 14 739 pytań
do zewnętrznej wyszukiwarki nie zostało wykonane. Przywrócono wyłącznie
kandydatów potwierdzonych dokładnym, zapisanym dowodem; brak nowego dowodu nie
był traktowany jako dowód poprawności. Wśród dodatkowych źródeł były oficjalne
strony U.S. Census Bureau, National Archives, ONZ, instytucji stanowych,
Komisji Europejskiej, Eurovision i The Beatles.

## Rejestry

- `diagnostics/quiz-recovery-audit-after-221/ALL_RECHECK_DECISIONS.json` — jedna
  decyzja i dowody dla każdego z 20 730 wcześniej odrzuconych ID;
- `diagnostics/quiz-recovery-audit-after-221/RESTORED.json` — tylko 284 pytania
  zakwalifikowane do przywrócenia;
- `diagnostics/quiz-recovery-audit-after-221/APPLIED.json` — końcowe liczby,
  wersje danych i sumy kontrolne;
- `diagnostics/quiz-recovery-audit-after-221/REPORT.md` — skrócony raport.

Wersje danych podniesiono do 4. Zmiany powstały już po zbudowaniu i podpisaniu
builda 221, więc wymagają osobnego przyszłego builda, jeżeli mają trafić do
paczki instalacyjnej.
