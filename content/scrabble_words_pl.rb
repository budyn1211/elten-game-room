# encoding: UTF-8
# Source and license: WORD_DICTIONARIES_NOTICE.md
require_relative '../lib/game_content'
module GameRoomContent::ScrabbleWordsPL; end
GameRoomContent.registry.register_pack(GameRoomContent::Pack.new(
  id: "scrabble.words.pl-pl.v1",
  set_id: "scrabble.words.pl-pl",
  kind: "word_dictionary",
  language_id: "pl-PL",
  version: 1,
  title: "Polski — SJP (2026-09-01)",
  game_ids: ["scrabble"],
  author: "SJP.PL contributors",
  license: "CC-BY-4.0",
  entry_count: 3244813,
  checksum: "1ac159436e9fe346639fef3a3523f61dcc6a5a7d52bb362dd2565cd4ae238ffe",
  loader: lambda { require_relative 'scrabble_words_pl_data'; GameRoomContent::ScrabbleWordsPL.load }
))
