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
    entry_count: 6571,
    checksum: "dc5c73b141a2c58b482214d365e764475e8ac2fce944efeca08c4a20df51d1ab"
  },
  {
    id: "quiz.witcher.g.pl",
    set_id: "quiz.witcher.g",
    title: "Wiedźmin — gry",
    scope: :games,
    entry_count: 3292,
    checksum: "edfea37897aa97716812e26637958ff925a79a69aa81259d48b485e7ab4880ff"
  },
  {
    id: "quiz.witcher.b.pl",
    set_id: "quiz.witcher.b",
    title: "Wiedźmin — książki i ekranizacje",
    scope: :books_screen,
    entry_count: 3279,
    checksum: "578f560d4d5cffe75292ca10fb97433560e8b6cb747806bea064a1f8e7765a87"
  }
].freeze

witcher_sets.each do |definition|
  scope = definition.fetch(:scope)
  GameRoomContent.registry.register_pack(GameRoomContent::Pack.new(
    id: definition.fetch(:id),
    set_id: definition.fetch(:set_id),
    kind: :quiz,
    language_id: "pl-PL",
    version: 2,
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
