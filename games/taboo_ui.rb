# encoding: UTF-8
module GameRoomGames
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
        payload: { "deadline" => state[:deadline], "offset" => state[:clock_offset].to_i, "frozen" => state[:frozen_at] }),
        announcement_shortcut(key: "s", label: _("team scores"), message: _("Team 1: %{first}; team 2: %{second}.") % { first: state[:scores][0], second: state[:scores][1] })]
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
      [rule_section(:voice, _("Talking, teams and roles"),
        _("Taboo is played by four, six or eight humans in two equal teams, without bots. Connect through a conference, another voice application, or talk in person with headphones. Game Room does not record, transmit or judge speech. Do not share the sound or screen that reads the card."),
        _("One person describes while their teammates guess aloud. Opponents monitor the description. Only the describing player and opponents see the target and its five forbidden words. Observers and guessing teammates cannot read the active card. Teams alternate, and every team member takes a turn describing.")),
       rule_section(:describe, _("Describing and resolving a card"),
        _("Do not say the target, forbidden words, their grammatical forms or meaningful parts. Do not spell, translate, rhyme, gesture, imitate sounds or use abbreviations to bypass the restriction. This does not prohibit an unrelated word merely containing the same letters. Incorrect guesses are not penalized. People judge speech and decide whether an inflected or equivalent answer is acceptable."),
        _("The describing player presses Enter when everyone is ready. After three seconds, a sound starts the turn and reveals the card. Enter marks a correct guess; P skips. An opponent presses B for a violation. The next card appears immediately without restarting the clock. Guessers do not press anything. The deck is shuffled; no card repeats until exhaustion, and reshuffling avoids an immediate repeat.")),
       rule_section(:points, _("Points, disputes and the end"),
        _("A correct guess earns one point for the describing team. A skip or accepted violation earns one point for the other team, without subtracting another point. An unfinished card at timeout scores zero. Late or simultaneous submissions cannot score the next card; the first accepted decision applies provisionally."),
        _("After each turn, everyone may inspect the used cards. The table master can change a card to guessed, skipped, violation or no points, after discussing disputes. Corrections remain in the history. The master must approve the review before the next turn. Approved scores cannot be edited. A technical restart cancels the whole turn's points and repeats the same describing player with new cards; previously revealed cards stay used."),
        _("Choose Polish or English cards, 30–300 seconds per turn (default 60), and 1–10 describing turns per person (default 2). After everyone has had the same number of turns, the higher team score wins. A tie adds a pair of turns, one per team, and repeats pairs until resolved. Reading cards uses turn time. Save only between turns after review approval.")),
       rule_section(:controls, _("Keyboard shortcuts"),
        _("Arrows browse the target and five forbidden words. Enter starts the turn or confirms a guess for the describing player; P skips, B buzzes for opponents. C reads the card; 1 reads the target and 2–6 the forbidden words. R reads remaining time, S team scores, T the describing player and team. Guessers and observers cannot use card-reading shortcuts. In review, Enter on a card lets the master correct its result; a separate button approves the turn. These keys do not act in chat."))]
    end
  end
end
