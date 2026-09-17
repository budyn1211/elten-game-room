# ELTEN's src/ri/__ri.rb replaces Array#shuffle and #shuffle! with methods
# taking no arguments. Mirror that API in isolated test processes. Also reject
# an unseeded fallback: peers and saved games must reproduce the same order.
module EltenArrayShuffleContract
  def shuffle
    raise "Game Room must not use the host's unseeded Array#shuffle"
  end

  def shuffle!
    raise "Game Room must not use the host's unseeded Array#shuffle!"
  end
end

Array.prepend(EltenArrayShuffleContract)
