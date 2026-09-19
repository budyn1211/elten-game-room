# Game Room 2.0.1.1 — build 230

## Polski

- Dodano Tysiąca dla dwóch osób, z dwoma musikami po dwie lub trzy karty. Pole wyboru pozwala zdecydować, czy niewybrany musik i odłożone karty otrzyma zwycięzca ostatniej lewy. Dostosowano boty i opis zasad. Do nowego wariantu obaj gracze potrzebują tej aktualizacji.
- W Tysiącu pojawia się komunikat o wejściu gracza na beczkę. Punktacja pod S informuje również, kto jest na beczce — zarówno w grze dwuosobowej, jak i trzyosobowej.
- Game Room korzysta z czasu serwera przy sprawdzaniu ważności zaproszeń i wspólnych terminów. Historia gry i czatu zachowuje kolejność zdarzeń z serwera, dzięki czemu różnie ustawione zegary komputerów nie zmieniają kolejności wpisów.
- Ujednolicono odmierzanie czasu w grach, zapisanych i wznawianych partiach oraz dziennej Krowie. Opóźnienia interfejsu i botów nadal działają lokalnie, bez dodatkowych zapytań sieciowych.
- Naprawiono błąd opóźnienia bota, który mógł przerywać między innymi grę w Czwórki i Kółko i krzyżyk.
- Statki odczytują na początku pytanie o sposób rozstawienia floty, potwierdzają rozstawienie automatyczne i ogłaszają pierwszą turę po przygotowaniu obu flot.
- W Monopoly lista planszy pod Shift+D podaje grupy nieruchomości. Skrócono informację o liczbie posiadłości w grupie, komunikaty budowania podają numer domu, a Enter na nieruchomości pod V lub Shift+V pokazuje aktualny czynsz.
- Skrócono nazwy ustawień Krowy i uaktualniono jej sterowanie. Opisy pod F1 i w skrótach zasad są krótsze — bez słów „Naciśnij” i „aby”.
- W Farkle usunięto zbędną zapowiedź dokończenia obiegu, gdy limit osiąga ostatni gracz i partia od razu się kończy.

## English

- Tysiac can now be played by two people, with two talons of two or three cards each. A checkbox decides whether the unchosen talon and set-aside cards count for the winner of the last trick. Bots and the rules support both options. Both players need this update for the new variant.
- Tysiac announces when a player goes onto the barrel. Score announcements under S also identify everyone currently on the barrel, in both player-count variants.
- Game Room uses server time for invitation validity and shared deadlines. Game and chat history follows the server's event order, so different computer clocks no longer put those entries in a different order.
- Turn clocks, saved and resumed games, and the daily Krowa puzzle now use a shared time reference. Local interface and bot delays still run without extra network requests.
- Fixed a bot-delay error that could stop games such as Connect Four and Tic-tac-toe.
- Battleship reads the fleet-placement question at the start, confirms automatic placement and announces the first turn after both fleets are ready.
- Monopoly's board list under Shift+D includes property groups. Property lists use shorter group counts, building announcements say which house is being built, and Enter under V or Shift+V shows the current rent.
- Krowa has shorter setting names and updated keyboard help. F1 and the shortcuts in game rules use shorter descriptions without Press and to.
- Farkle no longer asks players to finish the table circuit when the last player has already reached the target and the game ends immediately.

