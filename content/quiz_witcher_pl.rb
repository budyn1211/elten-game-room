# encoding: UTF-8
# The three sets share one source database and one audited medium map. Their
# contents are materialized only when the selected set is opened.
require_relative "../lib/game_content"

witcher_sets = [
  {
    id: "quiz.witcher.pl",
    set_id: "quiz.witcher",
    title: "Wiedźmin",
    scope: :all,
    entry_count: 5137,
    checksum: "c104a75104dfda0ce20a61251041a83365146afdf6130ced473a5f169e7f74dc"
  },
  {
    id: "quiz.witcher.g.pl",
    set_id: "quiz.witcher.g",
    title: "Wiedźmin — gry",
    scope: :games,
    entry_count: 2670,
    checksum: "9be427e26ba5ffc48ebe658834b043195920235be40521ce4ff92fc4b0055ab6"
  },
  {
    id: "quiz.witcher.b.pl",
    set_id: "quiz.witcher.b",
    title: "Wiedźmin — książki i ekranizacje",
    scope: :books_screen,
    entry_count: 2467,
    checksum: "5156e03a11471a837cf9d8f760bc376fa79e732c9c7e620ee291666876883be8"
  }
].freeze

witcher_sets.each do |definition|
  scope = definition.fetch(:scope)
  GameRoomContent.registry.register_pack(GameRoomContent::Pack.new(
    id: definition.fetch(:id),
    set_id: definition.fetch(:set_id),
    kind: :quiz,
    language_id: "pl-PL",
    version: 4,
    title: definition.fetch(:title),
    game_ids: ["quiz"],
    license: "CC BY-SA 3.0 (Fandom, Wiedźmin Wiki)",
    author: "ELTEN Game Room",
    entry_count: definition.fetch(:entry_count),
    checksum: definition.fetch(:checksum),
    loader: lambda {
      require_relative "quiz_witcher_pl_sets"
      GameRoomContent::WitcherPolishSets.load(scope)
    }
  ))
end
