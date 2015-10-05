
class Board
  # ゲームの状態を表わすクラスだ。コンポーネントとして、地形情報と全て
  # のモンスターの位置とアスカの状態（位置、向き）、持ち物一覧、床落ち
  # アイテムの一覧、及び階段の位置を持っている。

  COMPONENT_NAMES = [:inventory, :items, :characters, :kaidan, :traps]
  COMPONENT_TYPES = [Multiset, Set, Set, Array, Set]

  def initialize(map, inventory, items, characters, kaidan, traps)
    # map は [[String]]、inventory は Multiset<Item>、items は
    # Set<Item>、characters は Set {[Fixnum,Fixnum]}、kaidan は
    # [Fixnum,Fixnum] で、その座標を表わす。

    @map = map

    self.inventory  = inventory
    self.items      = items
    self.characters = characters
    self.kaidan     = kaidan
    self.traps      = traps
  end

  # → Board
  def deep_copy
    Marshal.load(Marshal.dump(self))
  end

  attr_reader :map

  # これらの情報が外部から見えるようにしよう。

  COMPONENT_NAMES.each do |attr|
    define_method(attr) { self.instance_variable_get("@#{attr}") }
    component_index = COMPONENT_NAMES.index(attr)
    type = COMPONENT_TYPES[component_index]
    define_method("#{attr}=") { |val|
      unless val.is_a? type
        raise TypeError, "'#{attr}=' expects #{type} but got #{val.class}"
      end
      self.instance_variable_set("@#{attr}", val)
    }
  end

  def asuka
    characters.find_by('name', "アスカ") || raise
  end

  def characters_at(pos)
    characters.select { |character|
      character.pos == pos
    }
  end

  def item_at(pos)
    items.find { |item| item.pos == pos }
  end

  def trap_at(pos)
    traps.find_by(:pos, pos)
  end

  # Hash に入れたいので hash メソッドと eql? メソッドを定義する。

  def hash
    _hash
  end

  def _hash
    # 局面オブジェクトのハッシュ値はコンポーネントのハッシュ値の XOR。

    COMPONENT_NAMES.map(&method(:__send__)).map(&:hash).reduce(:^)
  end

  def eql?(other)
    return false if self.hash != other.hash
    COMPONENT_NAMES.all? { |prop| self.__send__(prop).eql?(other.__send__(prop)) }
  end

  alias == eql?

  # 簡単に状態が確認できるように、文字列化できるようにしよう。

  def to_s
    render_inventory +
      render_characters +
      render_items +
      render_map
  end

  def render_characters
    "キャラ: \n" + characters.map(&:to_s).join("\n") + "\n"
  end

  def render_items
    "床落ち: " + items.map{ |item| "#{item.to_s}#{Vec::vec_to_s(item.pos)}" }.join(', ') + "\n"
  end

  def render_inventory
    "持ち物: " + inventory.to_a.map(&:to_s).join(', ') + "\n"
  end

  def render_map
    background = map.map(&:dup)
    Map::set!(background, kaidan, '段')

    [*traps, *items, *characters].each do |actor|
      Map::set!(background, actor.pos, actor.symbol)
    end

    background.map(&:join).map { |s| s + "\n" }.join
  end

  MAMMAL_SOLUTION = Set.new([[1, 3], [3, 1], [5, 3], [3, 5]])
  ZASSOU_SOLUTION = MAMMAL_SOLUTION
  def solved?
    zassou_positions = Set.new(items.select { |item| item.name == '雑草' }.map(&:pos))
    characters == MAMMAL_SOLUTION && (ZASSOU_SOLUTION - zassou_positions).empty?
  end

  def unsolvable?
    return false if solved? 
    return true if items.size + inventory.size != 5
    wand = inventory.find { |item| item.name == Item::WAND_HIKIYOSE }
    if wand && wand.number == 0 && (characters - MAMMAL_SOLUTION).size > 1
      return true
    end
    return false
  end

  # アスカが階段の上に乗っている状態は、「解けている」のでこれを判定す
  # る述語を定義する。

  def asuka_on_kaidan?
    kaidan == asuka.pos
  end

  def score
    @score || _score
  end

  def set_score
    @score = _score
  end

  def _score
    inventory_zassou = inventory.count { |item| item.name == '雑草' }
    zassou_positions = Set.new(items.select { |item| item.name == '雑草' }.map(&:pos))
    overlap = (zassou_positions & characters & MAMMAL_SOLUTION).size * -2
    # wand = get_wand
    # if wand
    #   magic_factor = (20 - wand.number) * 0.01
    # else
    #   magic_factor = 0
    # end
    (characters - MAMMAL_SOLUTION).size + overlap # + magic_factor - rand(0.05)
  end

  def get_wand
    inventory.find { |item| item.name == Item::WAND_HIKIYOSE }
  end

  def dimensions
    [map[0].size, map.size]
  end

  def destroy_item!(item)
    if item.pos
      self.items -= [item]
    else
      # 手持ちの item を１つ削除する。
      self.inventory = inventory.dup
      inventory.delete(item)
    end
    
  end

  def can_drop?(pos)
    return false if ['■', '◆'].include?(Map::at(map, pos))
    return false if items.any? { |item| item.pos == pos }
    return true
  end


  # アイテムの落下する場所を計算する。障害物の後ろには落ちないロジック
  # を実装していない。落ちられる場所が無く、消えてしまう場合は nil を
  # 返す。
  #
  # (Board, [Fixnum, Fixnum]) → ?[Fixnum, Fixnum]
  def item_drop(pos)
    ITEM_DROP_SEQ.each do |d|
      _pos = Vec::plus(pos, d)
      unless items.any? { |item| item.pos == _pos } ||
             ['■', '◆'].include?(Map::at(map, _pos)) ||
             trap_at(pos)
        return _pos
      end
    end
    return nil
  end

  # アイテム落下順
  # 

  ITEM_DROP_SEQ = generate_item_drop_sequence.freeze

  CHARA_RAKKA_TABLE = {
    # <方向> => [<原点>,
    #            <一周目>,
    #            <二周目>]
    [ 0,-1] => [[0,0],
                [1,0],[1,1],[0,1],[-1,1],[-1,0],[-1,-1],[0,-1],[1,-1],
                [2,0],[2,2],[0,2],[-2,2],[-2,0],[-2,-2],[0,-2],[2,-2]],
    [ 1,-1] => [[0,0],
                [1,1],[0,1],[-1,1],[-1,0],[-1,-1],[0,-1],[1,-1],[1,0],
                [2,2],[0,2],[-2,2],[-2,0],[-2,-2],[0,-2],[2,-2],[2,0]],
    [ 1, 0] => [[0,0],
                [0,1],[-1,1],[-1,0],[-1,-1],[0,-1],[1,-1],[1,0],[1,1],
                [0,2],[-2,2],[-2,0],[-2,-2],[0,-2],[2,-2],[2,0],[2,2]],
    [ 1, 1] => [[0,0],
                [-1,1],[-1,0],[-1,-1],[0,-1],[1,-1],[1,0],[1,1],[0,1],
                [-2,2],[-2,0],[-2,-2],[0,-2],[2,-2],[2,0],[2,2],[0,2]],
    [ 0, 1] => [[0,0],
                [-1,0],[-1,-1],[0,-1],[1,-1],[1,0],[1,1],[0,1],[-1,1],
                [-2,0],[-2,-2],[0,-2],[2,-2],[2,0],[2,2],[0,2],[-2,2]],
    [-1, 1] => [[0,0],
                [-1,-1],[0,-1],[1,-1],[1,0],[1,1],[0,1],[-1,1],[-1,0],
                [-2,-2],[0,-2],[2,-2],[2,0],[2,2],[0,2],[-2,2],[-2,0]],
    [-1, 0] => [[0,0],
                [0,-1],[1,-1],[1,0],[1,1],[0,1],[-1,1],[-1,0],[-1,-1],
                [0,-2],[2,-2],[2,0],[2,2],[0,2],[-2,2],[-2,0],[-2,-2]],
    [-1,-1] => [[0,0],
                [1,-1],[1,0],[1,1],[0,1],[-1,1],[-1,0],[-1,-1],[0,-1],
                [2,-2],[2,0],[2,2],[0,2],[-2,2],[-2,0],[-2,-2],[0,-2]]
  }

  # キャラクターの着地位置を決定するためのルーチン。
  # Board → [Fixnum,Fixnum] → ?[Fixnum,Fixnum]
  def character_drop(pos, dir)
    offsets = CHARA_RAKKA_TABLE[dir]

    newpos = offsets.map { |offset| Vec::plus(pos, offset) }
             .find { |point|
      characters_at(point).empty? &&
        !['■','◆','水'].include?(Map::at(map, point))
    }
    raise '落下できない場合の高とびは未実装' unless newpos
    return newpos
  end

end

