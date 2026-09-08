module GameRoomChatCommands
  Submission = Struct.new(:kind, :text, :action, :message, keyword_init: true)

  module_function

  def interpret(text, surface)
    value = text.to_s.strip
    return Submission.new(kind: :empty, text: value) if value.empty?
    return Submission.new(kind: :chat, text: value) if !value.start_with?("/")
    return Submission.new(kind: :chat, text: value[1..]) if value.start_with?("//")

    if surface == nil || !surface.respond_to?(:movement_command)
      return Submission.new(
        kind: :error,
        text: value,
        message: _("Movement commands are not available in this game view.")
      )
    end

    result = surface.movement_command(value[1..].to_s.split)
    if result.action != nil
      Submission.new(kind: :movement, text: value, action: result.action)
    else
      Submission.new(kind: :error, text: value, message: result.message)
    end
  end
end
