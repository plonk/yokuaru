# ワナを表わすクラスだ。
#
class Trap < Struct.new(:name, :pos)
  OTOSHIANA = :'落し穴'

  def initialize(name, pos)
    raise "unknown trap type #{name}" unless name == OTOSHIANA
    super(name, pos)
  end

  def land(board, item)
    # 落とし穴のロジックを実装する。item は board から削除されているは
    # ず。
    board.traps.delete(self)
  end
  
  # 落とし穴のワナが踏まれた時の処理。
  def step(board, character)
    character.hp = 0
    board.traps.delete(self)
  end

  def symbol
    name[-1]
  end

  def to_s
    name.to_s
  end

end
