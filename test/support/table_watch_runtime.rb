require_relative "settings_widget"

Notice2 = Struct.new(:id, :app_uuid, :type, :sender, :metadata, keyword_init: true)
EltenGameRoom.define_singleton_method(:server_app_uuid) { "468f59c5-c9d7-47cd-80f1-1a6fbfd1aa80" }
