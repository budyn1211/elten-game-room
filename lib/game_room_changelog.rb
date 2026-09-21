module GameRoomChangelog
  STORAGE_FILE = "changelog.json".freeze
  LAST_SEEN_BUILD_KEY = "last_seen_build".freeze
  ENTRY_TEMPLATE = "Version %{version}, build %{build}".freeze

  Entry = Struct.new(:version, :build, :changes, keyword_init: true)

  ENTRIES = [
    Entry.new(
      version: "1.1.8",
      build: 221,
      changes: [
        "Quiz Party no longer stops while preparing the next question when clients receive slightly different timestamps for the same LiveSessions entry."
      ].freeze
    ).freeze,
    Entry.new(
      version: "1.1.8",
      build: 222,
      changes: [
        "Game and room updates are received even while a key is held or text is being typed. This should prevent games from occasionally getting stuck. Chat text, cursor position and selection remain unchanged.",
        "Makao draw penalties no longer return to their author when the next player is already waiting one or more turns.",
        "After a second review, 284 well-supported Quiz Party questions were restored without bringing back ambiguous questions.",
        "A What's new list is shown once after an update and remains available from the main menu.",
        "Game Room notifications use their own notice sound. Joining a table also clears invitations and notifications for that table.",
        "After playing Wild or Wild Draw Four in UNO, colours are offered in the order yellow, red, blue, green."
      ].freeze
    ).freeze,
    Entry.new(
      version: "1.1.8",
      build: 223,
      changes: [
        "The What's new list is remembered correctly after closing it and groups all changes under a single version and build heading."
      ].freeze
    ).freeze,
    Entry.new(
      version: "1.1.9",
      build: 224,
      changes: [
        "F2 and F3 adjust Game Room sound volume; Shift+F2 and Shift+F3 select a sound group. Sound settings now use separate volume levels, including a master level, without affecting speech or other ELTEN sounds.",
        "F1 opens an arrow-key shortcuts list: current game actions first, room and screen actions next, and general controls last. Enter or Escape closes the list. Native ELTEN help remains unchanged outside Game Room.",
        "In card games, Z and Shift+Z move to the next or previous playable card. A single unambiguous card may be played automatically. UNO disables this aid when Straights, Interceptions, Super interceptions by value or Buzzer cards are enabled.",
        "Makao can be announced or caught while a local bot is thinking. Bot moves now include missing joker declarations and strategically distinct card packages, and catching an unannounced Makao takes priority. The table-card shortcut before dealing now gives a clear message."
      ].freeze
    ).freeze,
    Entry.new(
      version: "1.1.9",
      build: 225,
      changes: [
        "F2 and F3 adjust Game Room sound volume; Shift+F2 and Shift+F3 select a sound group. Sound settings now use separate volume levels, including a master level, without affecting speech or other ELTEN sounds.",
        "F1 opens an arrow-key shortcuts list: current game actions first, room and screen actions next, and general controls last. Enter or Escape closes the list. Native ELTEN help remains unchanged outside Game Room.",
        "In card games, Z and Shift+Z move to the next or previous playable card. A single unambiguous card may be played automatically. UNO disables this aid when Straights, Interceptions, Super interceptions by value or Buzzer cards are enabled.",
        "Makao can now also be announced during a bot's turn, including while waiting for its move. Catching an unannounced Makao also works during that time. Bot moves now include missing joker declarations and strategically distinct card packages, and catching an unannounced Makao takes priority. The table-card shortcut before dealing now gives a clear message."
      ].freeze
    ).freeze,
    Entry.new(
      version: "1.1.10",
      build: 226,
      changes: [
        "Invitations can now be accepted from notifications after reopening Game Room. Joining a table clears its invitations; a temporary network error does not invalidate an invitation.",
        "Private tables can be selected when creating any game. They are available by invitation and do not appear in public table lists, the widget or lobby announcements.",
        "Ctrl+R reads the variant and active settings of the selected or current table without opening the rules or moving the cursor.",
        "The table creator can save an ongoing game locally with Ctrl+S, closing the table. Saved games replaces rankings in the main menu.",
        "Resuming preserves the game, settings, bots and remaining turn time, and waits for the original players. Quiz Party and Categories cannot be saved; UNO requires finishing the colour choice and Monopoly requires finishing the auction. Private and resumed tables require an up-to-date Game Room for all players.",
        "S counts discs in Reversi, men and kings in Checkers, and pieces in Chess.",
        "Monopoly bots evaluate trades using colour-group prospects and blocking opponents, rather than selling properties too easily for their purchase price.",
        "Monopoly automatically declines an unowned property purchase when the player cannot afford it, without requiring Enter. Auctions still follow the table settings.",
        "Sending and declining invitations is recorded in the room history. Declining no longer creates a separate notification or an empty notification entry."
      ].freeze
    ).freeze,
    Entry.new(
      version: "2.0",
      build: 227,
      changes: [
        "Five new games: Rummy, Domino, Mexican Train, Scrabble and Taboo. Each has detailed rules and keyboard help in Polish and English.",
        "Also added Biblios by dawidpieper (Pajper): a card game of building a library and bidding at auctions, for two to four players, with bots and Polish translation.",
        "Computer players now receive randomly selected names from Polish or English lists.",
        "Rummy includes ordinary and elimination scoring, several discard-pile modes, jokers and optional manipulation of table combinations. Play against people or regular bots.",
        "Domino offers eleven tile sets, individual or team play, drawing variants and an optional turn clock. Mexican Train adds personal and public trains, opening trains and completing doubles.",
        "Scrabble is for two to four people, with Polish and English word lists, a keyboard-operated board, a private move draft and configurable invalid-word penalties. Polish uses SJP and English uses Wordnik; these are not the official tournament word lists. There are no bots.",
        "Taboo is a voice game for four, six or eight people in two teams, with 500 cards in each language. Use an external conference or voice conversation. The table master reviews and approves every turn; the game does not recognize speech and has no bots.",
        "Ctrl+X lets the table master change settings for the next game without creating another table. Ctrl+Q ends the current game after confirmation, keeping the room, participants, bots and chat, without declaring a winner.",
        "The active-tables widget no longer reloads when you press the arrows. It refreshes when you enter it, with R, and every five seconds while it has focus, preserving the selected table.",
        "You can subscribe to notifications about new public tables for selected games. Notifications are sent to online subscribers; no games are selected by default. Private and resumed tables are not announced this way.",
        "Games with bots share a move-delay setting from zero to five seconds. Zero disables the deliberate pause; UNO and Makao still default to one second. The delay cannot exceed an enabled thinking-time limit.",
        "Reversi adds optional passing even when a move exists and optional play without capturing. A non-capturing move must still touch an existing disc. P passes; voluntary passes alone do not end the game. Bots follow the selected rules.",
        "D reads rolled dice in Yahtzee and Ludo, as it already does in Farkle. Monopoly keeps its existing D shortcut. In Yahtzee, V opens your scorecard and Shift+V opens an opponent's.",
        "Farkle now finishes the current table circuit after someone reaches the score limit. The highest score wins, with shared wins on a tie. Bots take the leader and remaining turns into account; older saved games keep their original finishing rule. Based on dawidpieper's contribution.",
        "Game lists are sorted alphabetically using names in the interface language. Ninety-nine is now displayed as 99.",
        "New tables require Game Room 2.0 for all participants, so everyone uses the same game rules and table controls. Existing local saved games are retained."
      ].freeze
    ).freeze,
    Entry.new(
      version: "2.0",
      build: 228,
      changes: [
        "Five new games: Rummy, Domino, Mexican Train, Scrabble and Taboo. Each has detailed rules and keyboard help in Polish and English.",
        "Also added Biblios by dawidpieper (Pajper): a card game of building a library and bidding at auctions, for two to four players, with bots and Polish translation.",
        "Computer players now receive randomly selected names from Polish or English lists.",
        "Rummy includes ordinary and elimination scoring, several discard-pile modes, jokers and optional manipulation of table combinations. Play against people or regular bots.",
        "Domino offers eleven tile sets, individual or team play, drawing variants and an optional turn clock. Mexican Train adds personal and public trains, opening trains and completing doubles.",
        "Scrabble is for two to four people, with Polish and English word lists, a keyboard-operated board, a private move draft and configurable invalid-word penalties. Polish uses SJP and English uses Wordnik; these are not the official tournament word lists. There are no bots.",
        "Taboo is a voice game for four, six or eight people in two teams, with 500 cards in each language. Use an external conference or voice conversation. The table master reviews and approves every turn; the game does not recognize speech and has no bots.",
        "Ctrl+X lets the table master change settings for the next game without creating another table. Ctrl+Q ends the current game after confirmation, keeping the room, participants, bots and chat, without declaring a winner.",
        "The active-tables widget no longer reloads when you press the arrows. It refreshes when you enter it, with R, and every five seconds while it has focus, preserving the selected table.",
        "You can subscribe to notifications about new public tables for selected games. Notifications are sent to online subscribers; no games are selected by default. Private and resumed tables are not announced this way.",
        "Games with bots share a move-delay setting from zero to five seconds. Zero disables the deliberate pause; UNO and Makao still default to one second. The delay cannot exceed an enabled thinking-time limit.",
        "Reversi adds optional passing even when a move exists and optional play without capturing. A non-capturing move must still touch an existing disc. P passes; voluntary passes alone do not end the game. Bots follow the selected rules.",
        "D reads rolled dice in Yahtzee and Ludo, as it already does in Farkle. Monopoly keeps its existing D shortcut. In Yahtzee, V opens your scorecard and Shift+V opens an opponent's.",
        "Farkle now finishes the current table circuit after someone reaches the score limit. The highest score wins, with shared wins on a tie. Bots take the leader and remaining turns into account; older saved games keep their original finishing rule. Based on dawidpieper's contribution.",
        "Game lists are sorted alphabetically using names in the interface language. Ninety-nine is now displayed as 99.",
        "New tables require Game Room 2.0 for all participants, so everyone uses the same game rules and table controls. Existing local saved games are retained.",
        "Fixed text encoding in game settings, including a Reversi checkbox crash when Game Room and ELTEN use different interface languages."
      ].freeze
    ).freeze,
    Entry.new(
      version: "2.0.1",
      build: 229,
      changes: [
        "Rewritten the rules of all 23 games in Polish and English, with clearer explanations, examples and descriptions of the variants and settings available in Game Room.",
        "In-game keyboard shortcuts are now an arrow-key list. During a game, it uses the same current game-field help as F1. Enter or Escape closes the list; rules remain one document with headings.",
        "Receiving new-table notifications no longer waits for disk writes, removing one source of temporary interface stalls. The occasional record of a handled table is saved in the background.",
        "New-table notifications give the owner, game and notification type without repeating New table twice.",
        "Changing the question or card language in Quiz Party and Taboo keeps focus on the language. Sets update without moving the cursor; use Tab to reach them.",
        "Card hands support Shift+C to sort by suit or colour, Shift+H by rank, and Shift+M by receipt order. Pressing C or H with Shift again reverses that sorting direction. This covers UNO, Makao, Rummy, Spades, Tysiac, 99 and Poker's exchange hand, preserving each game's default order, the selected card and card packages.",
        "Makao's F1 help now includes Shift+Enter for adding a card to or removing it from a package.",
        "Fixed mixed Polish and English text in Taboo's rules and keyboard help. Help follows the interface language, independently of the card language.",
        "Independent sound effects can play together, including the jack effect and a threshold effect caused by the same move in 99.",
        "Added sounds for banking points in Farkle, reaching exactly 33 or 66 in 99, and declaring a marriage in Tysiac.",
        "Replaced the sounds for winning and losing a whole game. A player or team now hears the defeat sound when permanently eliminated, without hearing it again at the end of that game. Round-result sounds are unchanged.",
        "The Private table checkbox is now part of the table creation form, alongside the game settings, instead of a separate window.",
        "New games are selected in the widget by default, while saved manual deselections are remembered. Older settings also enable Rummy, Domino, Mexican Train, Scrabble, Taboo and Biblios once.",
        "Domino and Mexican Train now have distinct sounds for dealing tiles, playing a tile and drawing from the boneyard.",
        "You can limit the active-tables widget and new-table notifications to your contacts. Both filters are off by default. Invitations restricted to contacts now use the same background-updated contact list.",
        "Turn-time settings are now consistent across UNO, Makao, Domino, Mexican Train, Rummy, Scrabble, 99 and Poker. The limit is off by default. Timeouts follow each game's rules and never choose and play a card for you.",
        "In 99, exceeding the turn-time limit costs one token and passes the turn to the next player.",
        "In both Poker variants, exceeding the time limit folds your hand. During the draw, an all-in player instead keeps their cards and remains in the showdown. Side pots are also settled correctly when players fold during the draw.",
        "Ctrl+R gives shorter table settings, omitting disabled clocks and delays. Domino set names are also translated in the table creation form.",
        "Keyboard help in the rules lists each game-field shortcut separately, without chat controls or global shortcuts.",
        "Reshuffling an exhausted deck during a deal now has a short announcement and its own sound in UNO, Makao, 99, Rummy and draw Poker.",
        "Score announcements under S are ordered from highest to lowest, with eliminated players or teams last. Their actual scores are preserved.",
        "Added Battleship by Dawid Pieper: two fleets, manual placement, a computer opponent, spectator boards and a final fleet check. Saving this game for later is not yet available.",
        "Added Mancala by Dawid Pieper, with Oware, Ayoayo and Kalah variants and three computer strengths. Both new games include clear Polish and English rules, keyboard help and move sounds.",
        "At the start of Battleship, each player can choose random or manual fleet placement. Random placement follows the selected fleet and ship-spacing rules.",
        "Battleship has new rocket-launch, hit and miss sounds. The next event waits for the current sound to finish, while chat and receiving moves remain available. Other games keep overlapping sound effects.",
        "After selecting a game to create a table, focus starts on the opening instructions again. Tab then moves to Private table and the game settings.",
        "Fixed the empty in-game shortcuts list opened through Ctrl+F1, including in Scrabble. It now retains the current game-field help when opening the rules.",
        "Added Krowa by paulinux: guess Polish words in the daily puzzle, solo play, Race or cooperative Word Tower, with a personal gallery and optional leaderboards."
      ].freeze
    ).freeze,
    Entry.new(
      version: "2.0.1.1",
      build: 230,
      changes: [
        "Tysiac can now be played by two people, with two talons of two or three cards each. A checkbox decides whether the unchosen talon and set-aside cards count for the winner of the last trick. Bots and the rules support both options. Both players need this update for the new variant.",
        "Tysiac announces when a player goes onto the barrel. Score announcements under S also identify everyone currently on the barrel, in both player-count variants.",
        "Game Room uses server time for invitation validity and shared deadlines. Game and chat history follows the server's event order, so different computer clocks no longer put those entries in a different order.",
        "Turn clocks, saved and resumed games, and the daily Krowa puzzle now use a shared time reference. Local interface and bot delays still run without extra network requests.",
        "Fixed a bot-delay error that could stop games such as Connect Four and Tic-tac-toe.",
        "Battleship reads the fleet-placement question at the start, confirms automatic placement and announces the first turn after both fleets are ready.",
        "Monopoly's board list under Shift+D includes property groups. Property lists use shorter group counts, building announcements say which house is being built, and Enter under V or Shift+V shows the current rent.",
        "Krowa has shorter setting names and updated keyboard help. F1 and the shortcuts in game rules use shorter descriptions without Press and to.",
        "Farkle no longer asks players to finish the table circuit when the last player has already reached the target and the game ends immediately."
      ].freeze
    ).freeze,
    Entry.new(
      version: "2.0.2",
      build: 231,
      changes: [
        "Axel Pong is not an original project by papierek. The game was originally called Dragon-Pong, was later improved by Axel and balteam, and has now been ported to ELTEN with their permission.",
        "Added Axel Pong, an audio ping-pong game for two people or a player and a bot, with Classic and Arcade Classic modes and six difficulty levels. Play with the keyboard or mouse. Ctrl+P at the table opens personal settings for automatic return and sound volumes, also available in Settings > Axel Pong.",
        "On the Game Room widget, Ctrl+N opens the game list for creating a new table.",
        "Assign ten table presets to Ctrl+1 through Ctrl+0 in Game Room > Settings > Widget. Tab to the Table shortcuts list at the end of that section. Select a shortcut with the arrows, press Enter, choose a game and confirm its options and table privacy. The assignment is saved immediately; Cancel in Settings does not undo it. The shortcuts work only on the widget and create a table without starting the match. Assignments are saved locally.",
        "In Ludo, 1 reads your pawns and 2, 3 and 4 read the other players' pawns. D says who rolled last and the number. Shift+V lists pawns in board-position order instead of grouping them by player.",
        "In Yahtzee, D reads only the dice values. Clarified the rules and the bonus for Ones through Sixes; Misery now has a Polish name.",
        "Makao allows drawing even with a playable card in all three ready-made profiles; custom rules can disable it. After drawing a playable card, Space lets you pass without drawing again. If the drawn card cannot be played, the turn ends automatically.",
        "Mexican Train no longer repeats the same required-double announcement after every turn. T still lets you check it.",
        "Added a Draw another word button to Krowa's Random word variant. It reveals the previous word and resets attempts without recording a win.",
        "Games added since version 2.0 are now selected for lobby messages, and future games will be selected automatically. Later manual deselections are remembered. This does not enable main-screen notifications."
      ].freeze
    ).freeze
  ].freeze

  module_function

  def available_entries(current_build, entries: ENTRIES)
    entries.select { |entry| entry.build.to_i <= current_build.to_i }
      .sort_by { |entry| -entry.build.to_i }
  end

  def pending_entries(last_seen_build, current_build, entries: ENTRIES)
    available = available_entries(current_build, entries: entries)
    if last_seen_build == nil
      current = available.find { |entry| entry.build.to_i == current_build.to_i }
      return current == nil ? [] : [current]
    end
    return [] if last_seen_build.to_i >= current_build.to_i

    available.select { |entry| entry.build.to_i > last_seen_build.to_i }
  end

  def list_items(entries, translator: nil)
    translate = translator || ->(text) { text }
    entries.flat_map do |entry|
      heading = translate.call(ENTRY_TEMPLATE) % {
        version: entry.version,
        build: entry.build
      }
      [heading] + entry.changes.map { |change| translate.call(change) }
    end
  end
end
