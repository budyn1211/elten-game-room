# encoding: UTF-8
require_relative "../lib/game_room_localization"

module GameRoomGames
  using GameRoomLocalization::Translations
  class Taboo
    def surface_spec(replay, viewer)
      state = replay.state
      master = master?(state,viewer)
      lines = card_lines(state,viewer)
      action = if state[:phase] == :ready && same_user?(viewer,state[:current_player])
        "start"
      elsif state[:phase] == :describing && same_user?(viewer,state[:current_player])
        "correct"
      end
      review = state[:phase] == :review ? state[:review].map do |entry|
        card = cards(state)[entry[:card]]
        { word: card["word"], forbidden: card["forbidden"], result: entry[:result], label: result_label(entry[:result]) }
      end : []
      GameSurfaces::TabooSpec.new(token: token(state), phase: state[:phase], lines: lines,
        status: role_text(state,viewer), action: action, master: master, review: review,
        results: RESULTS.map { |r| [r,result_label(r)] },
        opponent: card_visible?(state,viewer) && !same_user?(viewer,state[:current_player]))
    end
    def custom_game_shortcuts(replay, viewer)
      state = replay.state
      result = [surface_shortcut(key: "r", label: _("remaining time"), command: "taboo_time",
        payload: { "deadline" => state[:deadline], "offset" => state[:clock_offset].to_i, "frozen" => state[:frozen_at], "epoch" => state[:clock_epoch_offset].to_i }),
        announcement_shortcut(key: "s", label: _("team scores"), message: score_announcement_order([0, 1], state[:scores]).map { |team| _("Team %{number}: %{score}") % { number: team + 1, score: state[:scores][team] } }.join("; "))]
      if card_visible?(state,viewer)
        result << announcement_shortcut(key: "c", label: _("read the entire card"), message: card_lines(state,viewer).join(", "))
        card_lines(state,viewer).each_with_index do |text, i|
          result << announcement_shortcut(key: (i+1).to_s, label: i == 0 ? _("read the target") : _("read forbidden word %{number}") % { number: i }, message: text)
        end
        if same_user?(viewer,state[:current_player])
          result << surface_shortcut(key: "p", label: _("skip this card"), command: "taboo_skipped")
        else
          result << surface_shortcut(key: "b", label: _("buzz this card"), command: "taboo_buzzed")
        end
      end
      result
    end
    def turn_announcement(replay, viewer); role_text(replay.state,viewer); end
    def result_text(replay)
      return nil unless replay.winner
      _("Team %{team} wins Taboo.") % { team: replay.winner.delete_prefix("team:").to_i + 1 }
    end
    def turn_marker(replay)
      [replay.state[:turn], replay.state[:phase]]
    end
    def result_label(result)
      { "correct" => _("Guessed"), "skipped" => _("Skipped"), "buzzed" => _("Rule violation"), "neutral" => _("No points") }.fetch(result)
    end
    def role_text(state,viewer)
      return _("Preparing Taboo.") if state[:phase] == :awaiting_deal
      return _("Taboo is finished.") if state[:phase] == :finished
      text = _("%{player} describes for team %{team}.") % { player: participant_name(state[:current_player]), team: state[:team]+1 }
      suffix = case state[:phase]
      when :ready then same_user?(viewer,state[:current_player]) ? _("Press Enter when everyone is ready.") : _("Waiting for the describing player.")
      when :preparing then _("Three-second preparation.")
      when :review then _("Review this turn. The table master must approve it.")
      else
        if same_user?(viewer,state[:current_player])
          _("Describe the target without the forbidden words.")
        elsif team_of(state,viewer) == state[:team]
          _("Guess aloud. The card is hidden.")
        elsif team_of(state,viewer)
          _("Monitor the description. Press B for a violation.")
        else
          _("You are observing. The card is hidden.")
        end
      end
      text + " " + suffix
    end
    def rule_sections
      # Generated from docs/rulebooks/taboo.json; see tools/compile-rulebooks.rb.
      [
        rule_section(:voice, GameRoomRules.translate("Describe a word without giving it away"),
          GameRoomRules.translate("In Taboo, your team guesses a word from your spoken clues. The difficulty is that you may not say the word itself or any of the five forbidden words printed with it. Game Room handles cards, time and points, but does not transmit, record or judge speech. Connect through an ELTEN conference or another voice application, or play in person with headphones. Do not share the sound or screen reading the secret card."),
          GameRoomRules.translate("Four, six or eight people form two equal teams. There are no bots. Teams take turns, and each member gets a turn describing. Only the current describer and the opposing team can see the active card. Guessing teammates and observers cannot inspect it. Opponents listen for a broken rule while your teammates call out guesses; guessers do not need to press a key.")),
        rule_section(:clues, GameRoomRules.translate("Give clues, not shortcuts around the forbidden words"),
          GameRoomRules.translate("Do not use the target, a forbidden word, a grammatical form of either or a meaningful part of it. Nor may you spell it, translate it, give initials or abbreviations, point, imitate its sound or say what it rhymes with. This is not a ban on every unrelated word that happens to share some letters. Judge the meaning of the clue, not an accidental sequence of characters."),
          GameRoomRules.translate("A wrong guess is harmless: teammates may keep trying. People decide whether an answer is close enough or a different grammatical form should count. Before playing, agree on a consistent approach to such answers. The app does not recognise spoken words and cannot decide a disputed clue for you.")),
        rule_section(:turn, GameRoomRules.translate("One clock for several cards"),
          GameRoomRules.translate("The describer presses Enter when everyone is ready. After three seconds of preparation, a sound starts the clock and the card appears. Enter marks a correct guess; P skips the card. An opponent presses B to report a violation. Each decision immediately brings the next card, but never restarts the clock. Reading and thinking use the same time as speaking."),
          GameRoomRules.translate("A correct guess gives your team one point. A skipped card or accepted violation gives the other team one point; it does not also subtract a point from yours. An unfinished card at timeout gives neither team a point. If decisions arrive together, the first accepted one applies provisionally to that card. A late key press cannot score a different, newly displayed card.")),
        rule_section(:review, GameRoomRules.translate("Settle disputes before the next turn"),
          GameRoomRules.translate("After time expires, everyone may inspect the cards used in that turn. Discuss disputed decisions, then the table master can change a result to guessed, skipped, violation or no points. Changes appear in the history. The master must approve the review before play continues; approved turns cannot be edited later."),
          GameRoomRules.translate("A technical restart is for a disrupted turn, not for correcting just one card. It cancels all points from that turn and gives the same describer a new turn with new cards. Cards already exposed remain used. The shuffled deck avoids repeats until it runs out and avoids an immediate repeat when reshuffling. You may save between turns after the review has been approved.")),
        rule_section(:options, GameRoomRules.translate("Language, turn length and the winning team"),
          GameRoomRules.translate("Choose the card language and a set available in that language. Polish and English sets are supplied. This does not change the interface or the language of these rules. Moving through languages leaves the cursor on the language choice; move to the updated set list with Tab when ready."),
          GameRoomRules.translate("Time for describing defaults to 60 seconds and accepts 30\u2013300. Describing turns per person defaults to two and accepts one to ten. When everyone has completed the chosen number of turns, the team with more points wins. A tie adds one turn for each team, repeating pairs until the tie breaks. Both teams therefore get the same number of opportunities.")),
        rule_section(:controls, GameRoomRules.translate("Game keyboard shortcuts"),
          GameRoomRules.translate("Arrows: browse the card or review list when visible to you."),
          GameRoomRules.translate("Enter: start describing or mark a correct guess; during review, edit the selected result."),
          GameRoomRules.translate("P: as the describer, skip the card."),
          GameRoomRules.translate("B: as an opponent, report a violation."),
          GameRoomRules.translate("C: read the card if your role may see it."),
          GameRoomRules.translate("R: read the remaining time."),
          GameRoomRules.translate("S: read team scores."),
          GameRoomRules.translate("T: read the current describer and team."),
          GameRoomRules.translate("1: read the target, if your role may see the card."),
          GameRoomRules.translate("2: read forbidden word 1, if your role may see the card."),
          GameRoomRules.translate("3: read forbidden word 2, if your role may see the card."),
          GameRoomRules.translate("4: read forbidden word 3, if your role may see the card."),
          GameRoomRules.translate("5: read forbidden word 4, if your role may see the card."),
          GameRoomRules.translate("6: read forbidden word 5, if your role may see the card."))
      ]
    end
  end
end
