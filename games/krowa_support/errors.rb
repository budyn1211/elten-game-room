# encoding: UTF-8

module GameRoomKrowa
  class StorageError < StandardError; end
  class ServerDateError < StandardError; end
  class DefinitionError < StandardError; end
  class DefinitionNotFoundError < DefinitionError; end
end
