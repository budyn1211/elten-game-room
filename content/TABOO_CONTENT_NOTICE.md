# Taboo — pochodzenie i redakcja talii 1

Data: 17 września 2026. Po 500 kart PL i EN, po pięć zakazanych określeń.
Źródłem gotowych danych jest `taboo_editorial.txt`; trwały numer wiersza
danych określa ID. Nie przestawiać ani nie usuwać wierszy bez migracji wersji.
`tools/build-taboo-cards.rb` odtwarza zasoby Ruby i sumy kontrolne.

To talie zredagowane dla Game Roomu, na licencji projektu GPL-3.0-or-later.
Nie są importem komercyjnego Taboo, talią QC ani kopią otwartej bazy.
Podczas opracowania porównano konstrukcję i jakość ograniczeń z przykładami
otwartego projektu [tabooo](https://github.com/pawelblaszczyk5/tabooo/blob/0ffb860bdb3753093f040b423bf1debb3cea1b1a/frontend/src/helpers/card.ts),
udostępnionego przez Pawła Błaszczyka na MIT. Materiał wzorcowy ma około
100 pozycji na język, nie stanowi źródła deklarowanych 500 pozycji.
Nie importowano Taboo-Data ani nie kopiowano kart z instrukcji Hasbro.

Każdy wiersz opracowano z kontrolą hasła i pięciu skojarzeń; warianty EN
nie zawsze tłumaczą dosłownie polskie ograniczenia. Zakres: dom, jedzenie,
zwierzęta, przyroda, podróże, miejsca, zawody, fantastyka, sport, muzyka,
technika, przedmioty szkolne, wydarzenia i pojęcia abstrakcyjne.
Przykłady świadomych różnic: Bison/plains wobec Żubr/Puszcza Białowieska,
Goose/honk wobec Gęś/gęgać, bez przenoszenia polskich kalamburów do EN.
Zrezygnowano z przykładów stygmatyzujących choroby, nazw żyjących polityków,
niejasnych potocznych haseł i niepowiązanych ograniczeń z materiału wzorcowego.

Kontrola redakcyjna obejmuje pisownię, naturalność, brak definicji fałszywych,
duplikatów haseł, pustych pól i powtórzeń zakazów. Zestawy nie są katalogiem
encyklopedycznych definicji: ograniczenie może być skojarzeniem lub kontrastem.
Właściwe rozstrzygnięcie wypowiedzi pozostaje przy ludziach.

Nie przeprowadzono jeszcze próbnych tur głosowych z ludźmi. Kontrola danych
i testy programu nie dowodzą jednakowego poziomu trudności wszystkich kart;
przed publicznym wydaniem wskazane są takie próby. Podczas partii nie powstają
nowe karty i nie ma zapytań do zewnętrznych usług generowania tekstu.
