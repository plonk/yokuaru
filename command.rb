# Command は、行動を表わし、Board と演算して新たな Board を生ずる。
#
class Command
  class << self
    # 行動には move, throw, use, drop, pick の５種類がある。それぞれは最
    # 大で２個のパラメーターを取り、data, data2 として参照できる。
    # 
    # move: dir [Fixnum,Fixnum], pick true/false
    # throw, use: dir, item Item
    # drop: item
    # pick: パラメーターなし
    def create(type, *args)
      case type
      when :move  then CommandMove.new(*args)
      when :throw then CommandThrow.new(*args)
      when :drop  then CommandDrop.new(*args)
      when :pick  then CommandPick.new(*args)
      when :use   then CommandUse.new(*args)
      else
        raise ArgumentError, "unknown type #{type}"
      end
    end

  end

  def initialize
    if self.class == Command
      raise 'abstract class Command cannot be instantiated'
    end
  end
  
  # 移動コマンドなどの方向。i.e. [-1, 0, 1].product([-1, 0, 1]) - [[0, 0]]
  DIRS = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]] 

  # コマンドがある局面で実行可能かどうかを判定する必要は無いかも
  # しれない。そのコマンドの実行によって局面が変化しないことで判
  # 定できるから。行動の実行と行動可能性の判定の計算のコストによる。
  #
  def legal?(board)
    return true
  end

  # Board → Board
  def execute(board); raise 'abstract method' end

  # メッセージ表示に適した形にコマンドを文字列化する。
  def to_s; raise 'abstract method' end

end

class CommandPick < Command
  def execute(board)
    item = board.items.any? { |_item| _item.pos == board.asuka }
    if item
      board.items.delete(item)
      board.inventory.add(item)
    end
  end

  def to_s
    "足元から拾う"
  end

end

class CommandThrow < Command
  attr_reader :dir, :item

  def initialize(dir, item)
    @dir = dir
    @item = item
  end

  def execute(board)
    # アスカが遠投の腕輪を装備しているかどうかで、投擲の挙動を変更した
    # い場合は、ここに追加するべきだ。
    board.asuka.dir = @dir
    return execute_normal_throw(board)
  end

  def execute_normal_throw(board)
    @item = board.inventory[@item] || board.items[@item]

    # 着地処理や敵に当たって消える前にアイテムを削除しておく。
    board.destroy_item!(@item)

    # 遠投状態ではない時に物を投げる処理だ。壁の手前まで来たら止まって、
    # 落ちる処理が行なわれる（止まったマスのワナの発動、実際に移動する
    # マスの選択、あるいは消滅）。

    # pos から開始して、敵に当たらなかった場合、どのマスを通過するかを
    # 計算する。pos が先頭要素になるが、自分自身に投擲は当たらないこと
    # に注意。
    max_trajectory = -> (pos) {
      traj = []
      loop do
        traj << pos
        pos = Vec::plus(pos, dir)

        # 範囲チェックを最初にする。
        break if !Map::within_bounds?(board.map, pos)
        # pos は範囲内。投擲をとめるセルに当たる場合はループを抜ける。
        break if ['■', '◆'].include?(Map::at(board.map, pos))
      end
      traj
    }
    max_traj = max_trajectory.call(board.asuka.pos)

    # この弾道からそれに当たるキャラクターを計算する。自分自身には当た
    # らないので先頭要素は捨てる。
    max_traj.drop(1).each do |pos|
      chara, = board.characters_at(pos)

      # 何かアイテムが敵に当たった時の効果の処理は、アイテムと敵の属性
      # に依存する。あと、当たった方向（ふきとばしの杖とか）と、当てた
      # 行為者（店長カンカン）。どこに書くんだよ！ OOPは答えをくれない。
      # Item クラスか。
      #
      # まがりの腕輪使ったら軌道だけじゃなくて方向も計算しないといけな
      # いな。
      if chara
        chara.hit_by_projectile(board, item, dir, board.asuka)
        # item.hit_effect(board, chara, dir, board.asuka)
        return
      end
    end
    #
    # 何者にも当たらなかった場合、軌道の最後の座標に落ちる。（今の書き
    # かただといろんな事が起きるタイミングを制御できない。実際には現象
    # の種類によって処理の行なわれるフェーズがある）

    # 足元である場合もあることに注意。
    drop_candidate = max_traj.last
    if item.pos != drop_candidate
      item_land(board, item, drop_candidate)
      return
    end
  end

  def to_s
    "#{Vec::dir_to_s(dir)}へ#{item}を投げる"
  end

  private

  def item_land(board, item, drop_candidate)
    trap = board.trap_at(drop_candidate)
    if trap
      trap.land(board, item)
    else
      # アイテムの着地
      actual_pos = board.item_drop(drop_candidate)
      if actual_pos
        item.pos = actual_pos
      end
    end
  end

  def execute_ento_throw(board)
    # 遠投状態で物を投げる処理だ。まず、障害物を無視してマップの限界ま
    # で一直線にサーチして当たる敵を列挙する。それらの敵に近い順から投
    # げたアイテムの効果が発動する。（大砲の弾は遠投時と普通の時とで効
    # 果が違うけど、そもそも普通の投擲時も挙動が他のアイテムと違うな）

    pos = board.asuka.pos
    hits = []

    loop do
      pos = Vec::plus(pos, dir)
      break unless Map::within_bounds?(board.map, pos)

      hits << pos if board.characters.include?(pos)
    end

    hits.each do |src|
      hits.reduce(board.dup) { |acc, src|
        hikiyose_move(board, src, Vec::opposite_of(dir))
        board.characters_at(src).pos = dest
      }

      board.destroy_item!(item)
    end

  end
end

class CommandDrop    
  attr_reader :item

  def initialize(item)
    @item = item
  end

  def execute(board)
    if board.can_drop?(board.asuka.pos)
      item_ = board.inventory[@item]
      board.inventory.delete(item_)
      item_.pos = board.asuka.pos
      board.items << item_
    end
  end

  def to_s
    "#{item}を置く"
  end

end

class CommandMove < Command
  attr_reader :dir, :pick

  def initialize(dir, pick)
    @dir = dir
    @pick = pick
  end

  def execute(board)
    xoff, yoff = dir

    # アスカの移動は、二種類ある行動のうちでは簡単な方だ。アスカは盗賊
    # 番の居る座標や、壁、岩のある座標へは移動できない。

    if asuka_can_move_into?(board, Vec::plus(board.asuka.pos, dir))
      board.asuka.pos = Vec::plus(board.asuka.pos, dir)
      board.asuka.dir = dir
      item = board.item_at(board.asuka.pos)
      if pick && item
        board.items.delete(item)
        item.pos = nil
        board.inventory.add(item)
      end
    end

  end

  def to_s
    s_pick = pick ? "拾う" : "拾わない"
    "#{Vec::dir_to_s(dir)}へ移動する(#{s_pick})"
  end

  private

  # (x, y) から (x', y') に移動する時に (x, y') か (x', y) が壁の場合は
  # 移動できない。
  def asuka_can_move_into?(board, pos)
    no_obstacle = can_move_into?(board, pos)
    return false unless no_obstacle

    tx, ty = pos
    sx, sy = board.asuka.pos
    diagonal_move = dir.inject(:*) != 0

    if diagonal_move
      return board.map[sy][tx] != '■' && board.map[ty][sx] != '■'
    else
      return no_obstacle
    end
  end
  

  def can_move_into?(board, pos)
    x, y = pos
    return !board.characters.include?(pos) &&
           !['■', '◆', '水'].include?(board.map[y][x])

  end
end

class CommandUse < Command
  attr_reader :dir, :item

  def initialize(dir, item)
    @dir = dir
    @item = item
  end

  def execute(board)
    board.asuka.dir = @dir
    item.use(board, board.asuka)
  end

  def to_s
    "#{Vec::dir_to_s(dir)}を向いて#{item}を使う"
  end

end
