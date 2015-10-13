
class Board
  # ゲームの状態を表わすクラスだ。コンポーネントとして、地形情報と全て
  # のモンスターの位置とアスカの状態（位置、向き）、持ち物一覧、床落ち
  # アイテムの一覧、及び階段の位置を持っている。

  COMPONENT_NAMES = [:inventory, :items, :characters, :kaidan, :traps]
  COMPONENT_TYPES = [Bag, Bag, Bag, Kaidan, Bag]

  def initialize(map, inventory, items, characters, kaidan, traps)
    # map は [[String]]、inventory は Multiset<Item>、items は
    # Set<Item>、characters は Set {[Fixnum,Fixnum]}、kaidan は
    # Kaidan。

    @map = map

    self.inventory  = inventory
    self.items      = items
    self.characters = characters
    self.kaidan     = kaidan
    self.traps      = traps
  end

  # → Board
  def deep_copy
    copy = Marshal.load(Marshal.dump(self))
    # h = copy.characters.instance_variable_get(:@hash)
    # h.rehash
    # characters.instance_variable_get(:@hash).rehash
    copy
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

  # → ?Character
  def character_at(pos)
    chara, = characters_at(pos)
    return chara
  end

  def top_object_at(pos)
    chara, = characters_at(pos)
    return chara if chara
    item = item_at(pos)
    return item if item
    return kaidan if kaidan.pos == pos
    return nil
  end

  def item_at(pos)
    items.find { |item| item.pos == pos }
  end

  def trap_at(pos)
    traps.find_by(:pos, pos)
  end

  # Hash に入れたいので hash メソッドと eql? メソッドを定義する。

  def hash
    @hash || _hash
  end

  def set_hash
    @hash = _hash
  end

  def _hash
    # 局面オブジェクトのハッシュ値はコンポーネントのハッシュ値の XOR。

    COMPONENT_NAMES.map(&method(:__send__)).map(&:hash).reduce(:^)
  end

  def eql?(other)
    return false if self.hash != other.hash
    COMPONENT_NAMES.all? { |prop|
      # p prop
      if prop == :characters
        a = self.__send__(prop)
        b = other.__send__(prop)
        # ha= a.instance_variable_get(:@hash)
        # hb= b.instance_variable_get(:@hash)
        #   p ha.class.object_id
        #   p hb.class.object_id
        #   #ha.rehash
        #   #hb.rehash
        #   p ha == hb
        #   p ha.eql? hb
        #   p [ha.frozen?, hb.frozen?]
        #   p [ha.tainted?, hb.tainted?]
        #   puts '--------'
        #   p ha.keys[0].eql?(hb.keys[0])
        # p [ha.keys[0].class.hash, hb.keys[0].class.hash]
        #   p ha.values == hb.values
        #   acopy = Marshal.load Marshal.dump(a)
        #   p acopy == a
        a.to_a.sort == b.to_a.sort
      else
        self.__send__(prop).eql?(other.__send__(prop))
      end
    }
  end

  alias == eql?

  # 簡単に状態が確認できるように、文字列化できるようにしよう。

  def to_s
    render_inventory +
      render_characters +
      render_items +
      render_traps +
      render_map
  end

  def render_traps
    "罠: " + traps.map { |trap| "#{trap.to_s}#{Vec::vec_to_s(trap.pos)}" }.join + "\n"
  end

  def render_characters
    "キャラ: \n" + characters.map { |character| "  #{character.to_s(&:to_s)}\n" }.join
  end

  def render_items
    "床落ち: " + items.map{ |item| "#{item.to_s}#{Vec::vec_to_s(item.pos)}" }.join(', ') + "\n"
  end

  def render_inventory
    "持ち物: " + inventory.to_a.map(&:to_s).join(', ') + "\n"
  end

  def render_map
    background = map.map(&:dup)
    Map::set!(background, kaidan.pos, '段')

    [*traps, *items, *characters].each do |actor|
      Map::set!(background, actor.pos, actor.symbol)
    end

    background.map(&:join).map { |s| s + "\n" }.join
  end

  def solved?
    asuka_on_kaidan?
  end

  def unsolvable?
    return true if asuka.hp < 1
    return false if solved? 
    return false
  end

  # アスカが階段の上に乗っている状態は、「解けている」のでこれを判定す
  # る述語を定義する。

  def asuka_on_kaidan?
    kaidan.pos == asuka.pos
  end

  def score
    @score || _score
  end

  def set_score
    @score = _score
  end

  def _score
    # 1
    dx = (kaidan.pos[0] - asuka.pos[0]).abs
    dy = (kaidan.pos[1] - asuka.pos[1]).abs
    s = [dx, dy].max

    if characters.to_a[0].dir == [-1,-1]
      s -= 5
    end
    if traps.empty?
      s -= 5
    end
    s
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
    return false if item_at(pos)
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

  # 階段が pos に存在する。
  #
  def kaidan_at?(pos)
    kaidan.pos == pos
  end

end

