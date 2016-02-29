require_relative 'board'

class BoardBuilder
  # Fei::Floor
  def initialize(floor)
    @board = convert(floor)
  end

  # () → Board
  def product
    return @board
  end

  private

  # 床, 壁, 不壊壁, 柱, 水路, 濡れ床
  CHIKEI_CELL = {
    0 => '　',
    1 => '■',
    2 => '■',
    3 => '◆',
    4 => '水',
    5 => '　'
  }
  # よくある杖と敵ソルバーが対応しているシンボルに変換する。
  def convert_chikei(fei_chikei)
    return fei_chikei.map { |row| row.map { |n| CHIKEI_CELL[n] } }
  end

  # 上 右上 右 右下 下 左下 左 左上
  DIR_TO_VEC = [
    [0, -1],
    [1, -1],
    [1, 0],
    [1, 1],
    [0, 1],
    [-1, 1],
    [-1, 0],
    [-1, -1]
  ]
  def convert_character(fei_character)
    name = Fei::CHARACTER_KIND[fei_character.kind][fei_character.level - 1].to_sym
    pos = [fei_character.x, fei_character.y] # x, y の順であってる？
    dir_vec = DIR_TO_VEC[fei_character.dir]
    return Character.new(name, pos, dir_vec)
  end

  def convert_characters(fei_characters)
    return fei_characters.map { |c| convert_character(c) }
  end

  def convert_items(fei_items)
    return fei_items.map { |item|
      pos = [item.x, item.y]
      name = Fei::ITEM_KIND[item.kind].to_sym
      Item.new(name, item.num, pos)
    }
  end

  def convert_traps(fei_traps)
    return fei_traps.map { |trap|
      pos = [trap.x, trap.y]
      name = Fei::TRAP_KIND[trap.kind].to_sym
      Trap.new(name, pos)
    }
  end

  def convert(floor)
    chikei = convert_chikei floor.chikei
    Board.map = chikei # 設計のミスを表わしている。

    mob = convert_characters floor.characters
    # アスカの向きはフェイ問ファイルにあるはずだけど、上向き[0, -1]にしておく。
    asuka = Character.new(Character::ASUKA, [floor.asuka_x, floor.asuka_y], [0, -1])
    characters = Bag[*mob, asuka]

    inventory = Bag.new
    items = Bag[*convert_items(floor.items)]
    traps = Bag[*convert_traps(floor.traps)]
    kaidan = Kaidan.new([floor.stairs_x, floor.stairs_y])

    return Board.new(inventory, items, characters, kaidan, traps)
  end

end

