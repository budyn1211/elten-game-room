require_relative "game_rules_ui"

def read_live_shortcuts(screen, replay, close_with: :enter)
  visits = 0
  result = nil
  Form.driver = lambda do |form|
    visible = form.fields - form.hidden_controls
    assert(visible.length == 1 && visible.first.is_a?(ListBox), "shortcuts gained extra focus stops")
    list = visible.first
    case visits
    when 0
      assert(list.options == ["Rules", "In-game keyboard shortcuts", "Current table options"], "table rules lost their document picker")
      list.index = 1
      visits += 1
      form.accept_button.trigger(:press)
    when 1
      result = list.options.dup
      assert(form.accept_button.equal?(form.cancel_button), "Enter does not close the shortcut list")
      visits += 1
      (close_with == :enter ? form.accept_button : form.cancel_button).trigger(:press)
    else
      assert(list.index == 1, "return did not preserve the selected rules document")
      form.cancel_button.trigger(:press)
    end
  end
  screen.send(:show_game_rules, replay)
  result
ensure
  Form.driver = nil
end
