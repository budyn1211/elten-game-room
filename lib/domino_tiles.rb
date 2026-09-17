# encoding: UTF-8
module GameRoomDominoTiles
  module_function

  # The third digit is a physical copy, never the tile's orientation.
  def tile(a, b, copy = 0)
    [*[a, b].sort.map { |v| v.to_s(36) }, copy.to_s(36)].join
  end

  def deck(maximum, copies = 1)
    copies.times.flat_map do |copy|
      (0..maximum).flat_map { |a| (a..maximum).map { |b| tile(a, b, copy) } }
    end
  end

  def faces(id); [id[0].to_i(36), id[1].to_i(36)]; end
  def double?(id); id[0] == id[1]; end
  def label(id); faces(id).join("–"); end
  def pips(id); faces(id).sum; end
  def fits?(id, value); faces(id).include?(value); end
  def other(id, value); a, b = faces(id); a == value ? b : a; end

  def shuffle(deck, seed)
    random = Random.new(seed.to_i(16))
    result = deck.dup
    (result.length - 1).downto(1) do |i|
      j = random.rand(i + 1)
      result[i], result[j] = result[j], result[i]
    end
    result
  end
end
