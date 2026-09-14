module GameRoomWidget
  class TableList < ListBox
    attr_reader :snapshots

    def initialize(loader:, opener:, labeler:, id_for:)
      @loader = loader
      @opener = opener
      @labeler = labeler
      @id_for = id_for
      @snapshots = []
      @last_focus_refresh = nil
      super(
        [],
        header: _("Game Room tables"),
        index: 0,
        quiet: true,
        empty_label: _("No matching Game Room tables")
      )
      on(:select) { open_selected }
    end

    def focus(*arguments)
      now = monotonic_time
      refresh if @last_focus_refresh == nil || now - @last_focus_refresh >= 0.5
      @last_focus_refresh = now
      super
    end

    def update
      if key_pressed?(0x52)
        refresh(announce: true)
        return
      end
      super
    end

    def refresh(announce: false)
      selected_id = selected_snapshot == nil ? nil : @id_for.call(selected_snapshot)
      loaded = @loader.call
      return false if loaded == nil

      @snapshots = loaded.to_a
      self.options = @snapshots.map { |snapshot| @labeler.call(snapshot) }
      restored = @snapshots.index { |snapshot| @id_for.call(snapshot).to_s == selected_id.to_s } if selected_id != nil
      self.index = restored || [[index.to_i, options.length - 1].min, 0].max
      sayoption if announce
      true
    rescue StandardError => error
      Log.warning("ELTEN Game Room main tab refresh failed: #{error.class}: #{error.message}") if defined?(Log)
      false
    end

    private

    def open_selected
      snapshot = selected_snapshot
      return if snapshot == nil

      @opener.call(snapshot)
      refresh
    rescue StandardError => error
      Log.warning("ELTEN Game Room main tab open failed: #{error.class}: #{error.message}") if defined?(Log)
      alert(_("The table could not be opened. Please try again."))
    end

    def selected_snapshot
      @snapshots[index.to_i]
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    rescue Exception
      Time.now.to_f
    end
  end
end
