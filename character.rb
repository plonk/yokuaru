# キャラクターを表わすクラスだ。名前と座標を指定してインスタンスを作成
# する。
#
class Character < Struct.new(:name, :pos, :dir, :hp, :mind_state)
  ASUKA = :'アスカ'
  USHIWAKAMARU = :'うしわか丸'
  DEBUUTON = :'デブートン'

  ATTRS = {
    USHIWAKAMARU => [10],
    ASUKA => [15],
    DEBUUTON => [130]
  }

  def initialize(name, pos, dir, mind_state)
    unless ATTRS.has_key?(name)
      raise ArgumentError, "unknown character #{name}"
    end

    hp = ATTRS[name][0]

    unless [:awake, :shallow_sleep, :deep_sleep, :paralyzed].include?(mind_state)
      raise 'format error' 
    end

    super(name, pos, dir, hp, mind_state)
  end

  def to_s
    "#{name}、HP#{hp}、位置#{Vec::vec_to_s(pos)}、#{Vec::dir_to_s(dir)}向き、#{mind_state}。"
  end

  def dead?
    hp < 1.0
  end

  def symbol
    name[0]
  end

  def reflective?
    name == USHIWAKAMARU
  end
    
  def hit_by_projectile(board, item, dir, actor)
    if reflective?
      # 物反射。
      # 投擲の行為者はアイテムが当たりそうになったキャラクターに変更される。

      self.dir = Vec::opposite_of(dir)
      item.pos = self.pos
      item.fukitobasareru(board, Vec::opposite_of(dir), self)
    else
      self.mind_state = :awake
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

  def generate_commands(board)
    raise 'no AI for ASUKA' if name == ASUKA

    if mind_state != :awake
      return [Command.create(:nothing)]
    else
      # わたしはデブートンです。
      return [Command.create(:skill)]
    end
  end

end
