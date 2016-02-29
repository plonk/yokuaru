# キャラクターを表わすクラスだ。名前と座標を指定してインスタンスを作成
# する。
#
class Character < Struct.new(:name, :pos, :dir, :hp)
  ASUKA = :'アスカ'
  USHIWAKAMARU = :'うしわか丸'

  ATTRS = {USHIWAKAMARU => [10, true],
           ASUKA => [15, false]}

  def initialize(name, pos, dir)
    unless ATTRS.has_key?(name)
      raise ArgumentError, "unknown character #{name}"
    end

    hp = ATTRS[name][0]

    super(name, pos, dir, hp)
  end

  def to_s
    "#{name}、HP#{hp}、位置#{Vec::vec_to_s(pos)}、#{Vec::dir_to_s(dir)}向き。"
  end

  def dead?
    hp < 1.0
  end

  def symbol
    name[0]
  end

  def hit_by_projectile(board, item, dir, actor)
    if name == USHIWAKAMARU
      # 物反射を実装する。

      # 投擲の行為者はうしわか丸に変更される。
      self.dir = Vec::opposite_of(dir)
      item.pos = self.pos
      item.fukitobasareru(board, Vec::opposite_of(dir), self)
    else
      item.hit_effect(board, self, dir, actor)
    end

  end

  # 敵がふきとぶ処理。
  def fukitobasareru(board, dir, actor)
    # 実装しないぞ。
  end

  def <=>(other)
    [name, pos, dir, hp] <=> other.instance_eval { [name, pos, dir, hp] }
  end

end
