require_relative 'bag'
require_relative 'kaidan'
require_relative 'main' # ぐおお。
require_relative 'fei'

class Board
  class << Board
    # 地形情報。添字は [y][x] の順。
    #
    # [[String]]
    attr_accessor :map
  end

  # ゲームの状態を表わすクラスだ。コンポーネントとして、地形情報と全て
  # のモンスターの位置とアスカの状態（位置、向き）、持ち物一覧、床落ち
  # アイテムの一覧、及び階段の位置を持っている。

  COMPONENT_NAMES = [:inventory, :items, :characters, :kaidan, :traps, :rooms]
  COMPONENT_TYPES = [Bag, Bag, Bag, Kaidan, Bag, Array]

  def initialize(inventory, items, characters, kaidan, traps, rooms)
    # inventory は Multiset<Item>、items はSet<Item>、characters は
    # Set {[Fixnum,Fixnum]}、kaidan はKaidan、rooms は Fei::Room の
    # Array。

    self.inventory  = inventory
    self.items      = items
    self.characters = characters
    self.kaidan     = kaidan
    self.traps      = traps
    self.rooms      = rooms
  end

  def map
    Board.map
  end

  # → Board
  def deep_copy
    return Marshal.load(Marshal.dump(self))
  end

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
    characters.find_by('name', Character::ASUKA) or raise 'asuka not found'
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

    drop_margins(simplify_chikei(background)).map { |s| s.join + "\n" }.join
  end

  # ----------- マップ描画 -------------
  def drop_init_blanks(rows)
    rows.drop_while { |row| row.all? { |elt| elt == '　' } }
  end

  def drop_margins(chikei)
    tmp = drop_init_blanks(chikei)
    tmp = drop_init_blanks(tmp.reverse).reverse
    tmp = drop_init_blanks(tmp.transpose)
    tmp = drop_init_blanks(tmp.reverse).reverse
    tmp.transpose
  end

  def simplify_chikei(chikei)
    y_dim = chikei.size
    x_dim = chikei[0].size

    wall = '■'

    offs = [-1, 0, +1].product([-1, 0, +1]) - [[0,0]]
    (0...y_dim).map do |y|
      (0...x_dim).map do |x|
        neighbours = offs.map { |yoff, xoff| [yoff+y, xoff+x] }
                     .select { |yy, xx| yy.between?(0, y_dim-1) && xx.between?(0, x_dim-1) }

        if chikei[y][x] == wall
          if neighbours.any? { |yy, xx| chikei[yy][xx] != wall}
            wall
          else
            '　'
          end
        else
          chikei[y][x]
        end

      end
    end
  end
  # ----------- マップ描画ココマデ -------------

  def solved?
    asuka_on_kaidan?
  end

  def unsolvable?
    if query_room_number(asuka.pos) == 0 &&
       (items.none? { |i| i.name == :"高とび草" } && inventory.none? { |i| i.name == :"高とび草" })
      # print "移動手段なし"
      return true 
    end
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

  # 評価関数

  # def _score # よくある杖と敵用
  #   dx = (kaidan.pos[0] - asuka.pos[0]).abs
  #   dy = (kaidan.pos[1] - asuka.pos[1]).abs
  #   s = [dx, dy].max
  #   if traps.size == 0
  #     s -= 10
  #   end
  #   return s
  # end

  def _score # 二豚方位用
    dx = (kaidan.pos[0] - asuka.pos[0]).abs
    dy = (kaidan.pos[1] - asuka.pos[1]).abs
    s = [dx, dy].max
    # s = 0

    # s -= inventory.reduce(0) { |acc, elt| acc + 1 + elt.number }
    # if query_room_number(asuka.pos) == 0 && 
    #    items.none? { |i| i.name == :"高とび草" } &&
    #    inventory.none? { |i| i.name == :"高とび草" }
    #   s += 10000
    # end
    if character_at([7,4])
      s -= 3 
      s -= 3 if character_at([11, 8])
    end
    return s
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

  # 状態が爆発するから何もしないことにしよう
  def increase_turn
  end

  # ちゃんと実装してないけど、とりあえず。
  def monster_phase
    monsters = characters - [asuka]
    monsters.each do |mon|
      cmd, = mon.generate_commands(self)
      cmd.execute(self)
    end
  end

  # pos がどの部屋にあたるかを調べる。pos がフロアのいずれかの部屋に入っ
  # ている場合は、.rooms のインデックスを返す。そうでなければ、nil を
  # 返す。
  #
  # Fei::Room のインスタンスは .x1 .y1 .x2 .y2 の属性を持つ。これは部
  # 屋の矩形の左上と右下の座標を表わす。(右下の座標も部屋に含まれる)
  def query_room_number(pos)
    x, y = pos
    return rooms.index { |r| x.between?(r.x1, r.x2) && y.between?(r.y1, r.y2) }
  end

  # アスカの足元にあるアイテムを返す。
  def item_at_feet
    return item_at(asuka.pos)
  end

  # characterをたかとびさせる。非決定性計算あきらめようか…
  def jump(character)
    # 実際の参照であるようにする。
    character = characters.find { |c| c == character }
    raise "character not found" unless character
    return if rooms.empty? # 部屋がない

    candidates = rooms.dup

    index = query_room_number(character.pos)
    if index
      candidates -= [ rooms[index] ]
    end

    candidates.shuffle!
    candidates.each do |room|
      # なんか、めんどくさいから最初に見つけたマスに移動しよう

      (room.y1).upto(room.y2) do |y|
        (room.x1).upto(room.x2) do |x|
          if map[y][x] == '　' and character_at([x, y]) == nil and [x, y] != kaidan.pos
            character.pos = [x, y]
            return
          end
        end
      end
    end

    # どこにも飛べるマスがなかった。
    return
  end

  def gomen_nasutte(asuka, partner)
    raise '位置関係がおかしい' unless Vec::distance(asuka.pos, partner.pos) == 1

    # これって、渡されたオブジェクトの状態を変えるだけでよいのだろうか？
    partner.pos, asuka.pos = [asuka.pos, partner.pos]
    partner.dir = Vec::opposite_of(asuka.dir)
  end

  def get_cell(pos)
    x, y = pos
    return map[y][x]
  end

end

