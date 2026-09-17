# encoding: UTF-8
# Source and license: WORD_DICTIONARIES_NOTICE.md
require_relative '../lib/game_content'
module GameRoomContent::ScrabbleWordsEN; end
GameRoomContent.registry.register_pack(GameRoomContent::Pack.new(
  id: "scrabble.words.en.v1",
  set_id: "scrabble.words.en",
  kind: "word_dictionary",
  language_id: "en",
  version: 1,
  title: "English — Wordnik (2021-07-29)",
  game_ids: ["scrabble"],
  author: "Wordnik",
  license: "MIT",
  entry_count: 194152,
  checksum: "edb7561e4c68a59fe384d604727f5b11b4ae3aeff80604f7033e985be0619c4d",
  loader: lambda { require_relative 'scrabble_words_en_data'; GameRoomContent::ScrabbleWordsEN.load }
))
