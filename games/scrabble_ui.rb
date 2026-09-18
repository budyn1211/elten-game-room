# encoding: UTF-8
module GameRoomGames
  class Scrabble
    def surface_spec(replay, viewer)
      state = replay.state
      player = state[:players].find { |p| same_user?(p, viewer) }
      GameSurfaces::WordBoardSpec.new(board: state[:board], rack: state[:racks].fetch(player, []),
        tiles: tiles(state), alphabet: language(state).alphabet,
        epoch: [viewer.to_s.downcase, state[:revision]],
        editable: state[:phase] == :playing && same_user?(viewer, state[:current_player]),
        exchange: state[:bag].length >= 8, deadline: state[:turn_deadline],
        clock_offset: state[:clock_offset].to_i, frozen_at: state[:frozen_at],
        preview: ->(placements) { preview(state, placements) }, error_message: method(:move_error))
    end

    def custom_game_shortcuts(replay, viewer)
      state = replay.state
      commands = {
        "backspace" => [_("remove the draft tile here"), "remove"], "z" => [_("cancel the draft"), "cancel"],
        "f" => [_("submit the word"), "submit"], "g" => [_("exchange tiles"), "exchange"],
        "p" => [_("pass"), "pass"], "c" => [_("read your rack"), "rack"],
        "i" => [_("change rack order"), "sort"], "y" => [_("preview words and points without checking the dictionary"), "preview"]
      }
      result = commands.map { |key,(label,command)| surface_shortcut(key: key, label: label, command: "word_#{command}") }
      (1..7).each do |number|
        result << surface_shortcut(key: number.to_s, label: _("read rack position %{number}") % { number: number }, command: "word_read", payload: { "slot" => number-1 })
      end
      result << announcement_shortcut(key: "e", label: _("tiles in racks and bag"), message:
        state[:players].map { |p| "#{participant_name(p)}, #{state[:racks][p].length}" }.join("; ") + ". " + (_("Bag: %{count} tiles.") % { count: state[:bag].length }))
      choices = state[:words].map do |w|
        direction = w[:direction] == 1 ? _("horizontal") : _("vertical")
        ShortcutChoice.new(label: "#{w[:word]}, #{Rules.field(w[:start])}, #{direction}, #{w[:score]}", value: w[:start])
      end
      choices << ShortcutChoice.new(label: _("No words have been played."), value: 0) if choices.empty?
      result << browse_shortcut(key: "l", label: _("browse played words"), prompt: _("Played words"), choices: choices)
      result
    end

    def rule_sections
      # Generated from docs/rulebooks/scrabble.json; see tools/compile-rulebooks.rb.
      [
        rule_section(:crossword, GameRoomRules.translate("Build one crossword together"),
          GameRoomRules.translate("Two to four people play on a 15-by-15 board, using letter tiles to score words. There are no bots in this game. Everyone starts with seven tiles on a private rack and refills towards seven after playing, while tiles remain in the bag. The first word must cross the centre, H8. Later moves must connect to the existing crossword."),
          GameRoomRules.translate("In one move, place your new letters in a single row or column. Existing letters may fill the spaces between them, but the completed line cannot have empty gaps. Words read left to right or top to bottom, never diagonally. You may extend a word, cross it, or place letters beside it to make several shorter words. Every newly created word must be valid, not just the longest one. Accepted letters stay in place for the rest of the game.")),
        rule_section(:dictionary, GameRoomRules.translate("The chosen language decides which words count"),
          GameRoomRules.translate("Choose Polish or English for the tiles and dictionary, independently of your interface language. Polish uses the SJP data dated 2026-09-01; English uses Wordnik data dated 2021-07-29. These are the local word lists supplied with Game Room, not the official OSPS, NWL, Collins or QC lists. Words contain two to fifteen letters and are checked against the selected list when you submit the move."),
          GameRoomRules.translate("Each language has 100 tiles, including two blanks, but different letter quantities and values. A blank can represent a letter you choose when placing it. It always scores zero and keeps that chosen letter after the move is accepted. It cannot later be changed into another letter or recovered from the board.")),
        rule_section(:points, GameRoomRules.translate("How a move earns points"),
          GameRoomRules.translate("For each new word, add the values of all its letters, including letters already on the board. A newly covered letter bonus doubles or triples that tile's value. After letter bonuses, apply the word bonuses to the whole word. Several word multipliers multiply together. For example, two double-word fields make the word worth four times its letter total."),
          GameRoomRules.translate("A letter shared by two new words scores in both. Bonuses work only on the move that first covers them; extending a word later does not activate its old bonuses again. A blank still scores zero on a letter bonus, but can activate a word bonus. Using all seven rack tiles in one move adds 50 points after the word totals have been calculated.")),
        rule_section(:alternatives, GameRoomRules.translate("You may exchange or pass instead"),
          GameRoomRules.translate("Exchange one to seven tiles only when at least eight are left in the bag. Select the tiles to return and confirm the exchange; this uses your turn. In this version, returned tiles go back into the bag before it is shuffled and replacements are drawn, so you may get a returned tile again. You can also pass without exchanging. Neither choice places an unfinished draft on the board.")),
        rule_section(:invalid, GameRoomRules.translate("What happens to an unrecognised word"),
          GameRoomRules.translate("Invalid word offers six policies. Choose whether an invalid submission lets you correct the move or ends your turn, and whether it costs zero, 5 or 10 points. The default is correction without a penalty. One submitted attempt incurs at most one penalty, even if several words are invalid. The draft returns to the rack and does not use any board bonuses."),
          GameRoomRules.translate("Placement errors, such as a disconnected word or a gap, are not penalised as invalid words. Y previews the words and their points but deliberately does not consult the dictionary. A preview is therefore not a guarantee that a word will be accepted. Dictionary checking happens only when you submit.")),
        rule_section(:ending, GameRoomRules.translate("The last tiles and the final score"),
          GameRoomRules.translate("Thinking time is zero for no limit, or 20\u2013600 seconds per turn. Choosing a blank and correcting a word use the same turn time. Timeout cancels the unsubmitted draft and passes; it does not draw tiles or charge a separate point penalty."),
          GameRoomRules.translate("The game ends when someone empties their rack and the bag is empty. It also ends as blocked when exchanging is unavailable and three complete circuits pass without a tile being placed. A legal word worth zero still breaks this sequence. At the end, subtract each player's remaining tile values. If a player went out, they also gain the other players' remaining values; a blocked game has no such bonus. Blanks are worth zero. The highest adjusted score wins, with a shared result if tied.")),
        rule_section(:controls, GameRoomRules.translate("Place letters directly on the board"),
          GameRoomRules.translate("Arrows: move around A1\u2013O15. Enter on an empty field: choose a rack tile, then Enter to place it. A blank also asks for a letter. Escape cancels the choice. Backspace removes your unsubmitted tile under the cursor; Z clears the whole draft. F submits it."),
          GameRoomRules.translate("C: read the rack. 1\u20137: read individual rack positions without placing a tile. I: cycle receipt, alphabetic and vowel-first rack order after clearing a draft. Y: preview words and points. L: browse played words."),
          GameRoomRules.translate("G: exchange; arrows browse, Space selects, Enter confirms, Escape cancels. P: pass. Passing or exchanging asks before discarding a draft. E: tile counts. S: scores. T: turn. Submit or cancel your draft before saving the game."))
      ]
    end
  end
end
