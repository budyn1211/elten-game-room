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
      [
        rule_section(:words, _("Building the crossword"),
          _("Scrabble is for two to four people, without bots. Each rack holds seven tiles. The first word covers H8; later words connect to the crossword, including parallel words. Place new tiles in one row or column without empty gaps. Every newly formed word, including crosswords, must be in the selected local dictionary. Words contain two to fifteen letters. Committed tiles never move.")),
        rule_section(:letters, _("Languages, blanks and bonuses"),
          _("Choose Polish (SJP, 2026-09-01) or English (Wordnik, 2021-07-29), independently of the interface language. These are not OSPS, NWL, Collins or QC dictionaries. Each language has its own 100-tile distribution with two blanks. A blank represents a chosen letter permanently and always scores zero."),
          _("Score every word formed in the move. New letter bonuses apply first, then word multipliers; multiple word multipliers multiply. A shared letter scores in each word. Covered bonuses never apply again. A blank can activate a word bonus. Using seven rack tiles in one move adds 50 points after the other calculations.")),
        rule_section(:choices, _("Passing, exchange and rejected words"),
          _("Exchange one to seven tiles only when at least eight remain in the bag. Returned tiles go into the bag before shuffling and drawing replacements, so the same tile may return. Exchanging or passing ends the turn. Neither action commits a draft."),
          _("The invalid-word setting offers six policies: correct or end the turn, each with no penalty, minus 5 or minus 10 points. The default is correction without penalty. One submitted attempt incurs at most one penalty, regardless of the number of invalid words. Invalid words return all draft tiles to the rack and do not consume bonuses. Geometry errors have no penalty. Preview calculates points but never checks the dictionary.")),
        rule_section(:end, _("Time and final scores"),
          _("Thinking time is zero (unlimited) or 20–600 seconds per turn. Choosing a blank or correcting a word does not restart the clock. Timeout discards the local draft and passes without drawing or a point penalty. The game ends when the bag and one rack are empty, or exchange is unavailable and three complete table circuits pass without placing tiles. A legal zero-point word still resets that counter."),
          _("At the end, subtract each player's unused tile values. If someone emptied their rack with an empty bag, add the others' unused values to that player's score. With a blocked board there is no such bonus. Blanks cost zero. The highest adjusted score wins; equal highest scores share the result. Save only after submitting or cancelling the local draft.")),
        rule_section(:controls, _("Keyboard shortcuts"),
          _("Arrows browse A1–O15. Enter on an empty field opens your available tiles; choose one with arrows and press Enter to place it. A blank asks for its letter. Escape closes the choice without changing the draft. The cursor stays on the chosen field. Keys 1–7 only read individual rack positions; C reads the whole rack."),
          _("Backspace removes your unsubmitted tile under the cursor; Z clears the whole draft; F submits it. Y previews words and points without checking the dictionary. I cycles free, alphabetic and vowel-first rack order, after clearing the draft. G opens tile exchange: arrows browse, Space selects, Enter confirms and Escape cancels. P passes. Exchange and pass ask before discarding a draft. L lists played words; E reads tile counts; S reads scores; T reads whose turn it is. These shortcuts do not act in chat."))
      ]
    end
  end
end
