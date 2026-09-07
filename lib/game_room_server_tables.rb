class GameRoomServerTables
  def initialize(program, client: nil)
    @server_app_uuid = program.server_app_uuid.to_s
    raise ArgumentError, "ELTEN Game Room server application is not declared" if @server_app_uuid.empty?

    # Repository calls run inside Tasks.run workers. A context-free client waits
    # without trying to drive the ELTEN UI loop from that worker thread.
    @client = client || EltenLink::Client.new
    @tables = {}
  end

  def fetch(name)
    key = name.to_s
    raise ArgumentError, "a server table requires a name" if key.empty?

    @tables[key] ||= EltenLink::Apps.table(@client, @server_app_uuid, key)
  end
end
