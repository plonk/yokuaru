=begin

50階『よくある杖と敵』を解くプログラム

2015年10月04日

『がんばれば余ります』を解くプログラムを流用して『よくある杖と敵』を解
くプログラムを作りたい。

この問題は数種の杖とかなしばり状態のうしわか丸を利用して、対岸の階段へ
行ければクリアできる問題。


                     地形     ワナ・階段    キャラ
                  ■■■■■　■■■■■　■■■■■
                  ■■　■■　■■段■■　■■段■■
                  ■■　■■　■■　■■　■■　■■
                  ■　水　■　■　水穴■　■う水穴■
                  ■　水■■　■　水■■　■　水■■
                  ■　　　■　■　　　■　■　ア　■
                  ■■■■■　■■■■■　■■■■■


開始直後の持ち物は、場所替えの杖[2]、ふきとばしの杖[1]、引きよせの杖[1]。

可能な行動は、移動（アイテムを拾う、拾わないの違いがある）、持っている
アイテムの投擲、足元にアイテムを置く、足元のアイテムを拾う、アイテムを
使う。さらに、アスカの向きを変更するが加わる。

----------------------------------------------------------------------

『がんばれば余ります』ソルバーから変更、追加しなければならないところ。
投擲は遠投ではなく普通。敵はうしわか丸なので、物反射を実装する（飛距離
は計算しなくてよいだろう）。落とし穴がある（これが発動するとクリア不可
能になるので、アスカの生存状態を持たなければならない）。

解では必要ないが、階段をワナ様のオブジェクトとして扱って引きよせが効く
ようにしたほうが良い。

そういえば、局面オブジェクトへのクエリが低レベルでぎこちないのをなんと
かしたい。足元アイテムの操作が持ち物と床落ちの中間で、むずかしい。

----------------------------------------------------------------------

全体の構成を見ると、ひとつひとつの局面をグラフのノードと考えてそこから、
取り得るコマンドでラベル付けされた単方向の矢印が出て、次の局面に遷移す
るようなグラフを、探索してひとつの解を見付けるようにしたい。

探索のアルゴリズムについては、最良優先探索を使う。検索停止の条件はアス
カが階段状に居る状態へ遷移することができたこと。検索の方向付けをする評
価関数はアスカと階段の距離 max(dx, dy) で良いように思う。

詰み判定について。アスカが死んでいるということ以外に、あまり明白な詰み
条件はないように思う。この問題に限って言えば、生の地形で階段まで歩いて
行けない状況で、手持ちや拾いに行けるアイテムが無ければ詰みとしても良い
ように思うが……。プログラムに答えを教えるに等しいような強い仮定は入れ
たくない。

一度訪れた局面には戻らないようにしたいから、局面同士が比較（==）できる
必要がある。あと、Set（Hash）に入れたいから hash 値が計算できると良い。
局面のコンポーネントの hash 値を XOR すればよい。

=end

# このプログラムは Set、Multiset クラスを使う。
#
# 手持ちのアイテムを保待するのに Multiset を使用するのは、配列を使用す
# るよりも遅くなるが、ソートし忘れによって等価なのに別個と判定されるよ
# うな状態が産まれたり、指定の値に等しい要素を１つだけ削除するメソッド
# が用意されているのは便利だ。一方、オリジナルを残したまま新たな値を計
# 算する機能は弱い。

require 'set'
require 'multiset'

require_relative 'item'

# キャラクターを表わすクラスだ。名前と座標を指定してインスタンスを作成
# する。
#
class Character < Struct.new(:name, :pos, :dir, :hp)
  ATTRS = {'うしわか丸' => [10, true],
           'アスカ' => [15, false]}

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

end

# ワナを表わすクラスだ。
#
class Trap < Struct.new(:name, :pos)

  def initialize(name, pos)
    raise "unknown trap type #{name}" unless name == '落とし穴'
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
    "落とし穴"
  end

end

module Enumerable
  def find_by(prop, val)
    find { |elt| elt.__send__(prop) == val }
  end
end

# 文字の２次元配列である地形マップを操作するための関数群だ。読み出し、
# 書き込み、添字の組の範囲チェック。
#
module Map
  def at(grid, point)
    raise TypeError unless grid.is_a?(Array) and point.is_a?(Array)
    raise RangeError unless within_bounds?(grid, point)

    x, y = point
    grid[y][x]
  end
  module_function :at

  def set!(grid, point, val)
    raise RangeError unless within_bounds?(grid, point)

    x, y = point
    grid[y][x] = val
  end
  module_function :set!

  def within_bounds?(map, point)
    x, y = point
    return x >= 0 && x < map[0].size && y >= 0 && y < map.size
  end
  module_function :within_bounds?

end

# ２次元ベクトルの操作だ。
module Vec
  # マップに魔法弾の弾道を描画するための。
  def dir_to_char(dir)
    case dir
    when [-1, -1], [1, 1]
      '＼'
    when [-1, 0], [1, 0]
      '―'
    when [-1, 1], [1, -1]
      '／'
    when [0, -1], [0, 1]
      '｜'
    else
      raise RangeError
    end
  end

  # 方向ベクトルをメッセージ表示に適した形に文字列化する。
  def dir_to_s(dir)
    # 上から時計回り。
    case dir
    when [0, -1]  then "上"
    when [1, -1]  then "右上"
    when [1, 0]   then "右"
    when [1, 1]   then "右下"
    when [0, 1]   then "下"
    when [-1, 1]  then "左下"
    when [-1, 0]  then "左"
    when [-1, -1] then "左上"
    else
      raise
    end    
  end
  module_function :dir_to_s

  def vec_to_s(vec)
    return vec.inspect.tr!('[]','()').sub!(' ', '')
  end
  module_function :vec_to_s

  def plus(a, b)
    [a[0] + b[0], a[1] + b[1]]
  end
  module_function :plus

  # 例えば「右上→左下」のように、方向を反転する。
  def opposite_of(v)
    [-v[0], -v[1]]
  end
  module_function :opposite_of

end

# Board クラスは次のような使いかたをする。

def build_demo_problem
  chikei_s = <<EOD
■■■■■
■■　■■
■■　■■
■　水　■
■　水■■
■　　　■
■■■■■
EOD
  chara_s = <<EOD
■■■■■
■■　■■
■■　■■
■う水　■
■　水■■
■　ア　■
■■■■■
EOD
  kaidan_s = <<EOD
■■■■■
■■段■■
■■　■■
■　水穴■
■　水■■
■　　　■
■■■■■
EOD
  chikei = map_from_s(chikei_s)
  ushiwaka = Character.new('うしわか丸', *positions('う', map_from_s(chara_s)), [0,1])
  asuka = Character.new('アスカ', *positions('ア', map_from_s(chara_s)), [0,1])
  characters = Set[ushiwaka, asuka]
  kaidan = positions('段', map_from_s(kaidan_s)).first
  inventory = Multiset[
    Item.new(Item::WAND_BASHOGAE, 2),
    Item.new(Item::WAND_FUKITOBASHI, 1),
    Item.new(Item::WAND_HIKIYOSE, 1),
  ]
  items = Set.new
  ana = Trap.new('落とし穴', *positions('穴', map_from_s(kaidan_s)))
  traps = Set[ana]

  return Board.new(chikei, inventory, items, characters, kaidan, traps)
end

# ここで使われた map_from_s と positions のユーティリティ関数は以下のよ
# うに定義される。

def map_from_s(str)
  # 複数行からなるテキストを受けとり、個々の要素として文字（String）を
  # 持つ２次元配列に変換する。
  
  lines = str.each_line.map(&:chomp)
  unless lines.map(&:size).all? { |len| len == lines[0].size }
    raise 'inconsistent line lengths'
  end
  return lines.map { |line| line.each_char.to_a }
end

def positions(char, map)
  # positions はエンティティを表わす文字と、２次元配列である map を受
  # けとり、エンティティが map 上でどの座標に存在するかを [x, y] の配
  # 列で返す。エンティティがマップ上で唯一の場合は要素数１の配列が返る。
  raise ArgumentError, 'character required' unless char.size == 1

  return map.flat_map.with_index { |row, y|
    row.flat_map.with_index { |ch, x|
      if ch == char then [[x, y]] else [] end
    }
  }
end

def generate_item_drop_sequence
  item_rakka = (<<ITEM_RAKKA).each_line.map { |l| l.chomp.chars }
kighj
d645c 
b312a
f978e 
pnlmo
ITEM_RAKKA
  (1..25).map { |i|
    pos = positions(i.to_s(26), item_rakka).first
    Vec::plus(pos, [-2, -2])
  }
end

require_relative 'board'

# メインプログラムを作って行く。初期状態の局面から、アスカが階段の上に
# 乗っているという終了状態へ遷移させ、その道筋を表示する。

class Program
  def build_problem
    # 初期状態を Board オブジェクトとして返すメソッド。
    #
    # 今回は問題は変化しない。外部のファイルなどから問題を受け取りたい場合は、
    # この関数を変更すれば良いだろう。

    return build_demo_problem
  end

  def commands(board)
    # 現在の局面で取れる行動を列挙する。

    cmds = []

    # 八方向への移動。今回ナナメに動ける場所は無いが、早すぎる最適化
    # 云々――。それぞれの方向について、アイテムを拾う場合と拾わない場
    # 合の二種類がある。
    unless board.items.any? { |item| item.pos == board.asuka && item.name == Item::WAND_HIKIYOSE }
      cmds += [[0, -1], [1, 0], [0, 1], [-1, 0]].flat_map { |d|
        # [Command.new(:move, d, true)]
        [Command.new(:move, d, true),
         Command.new(:move, d, false)]
      }
    end

    # アイテムに対して行なうコマンド。
    cmds += Command::DIRS.flat_map { |d|
      board.inventory.flat_map { |item|
        [Command.new(:throw, d, item) ] + 
          [Command.new(:use, d, item)]
      }
    }

    cmds += board.inventory.flat_map { |item|
      if item.name == Item::WAND_HIKIYOSE
        []
      else
        [Command.new(:drop, item)]
      end
    }

    # cmds += [Command.new(:pick)]

    return cmds.select { |cmd| cmd.legal?(board) }
  end

  # 優先度付きキューを実装した PQueue クラスを使用して探索を実装する。
  require 'pqueue'

  def search(init)
    # 局面 init を受けとり、それを初期ノードとして、全ての可能な行動に
    # よって広がってゆくグラフを solved? を満たす局面が見付かるまで最
    # 良優先探索で探索する。発見した解のノードと、歩いた辺の集合（キー
    # を到達ノード、値を直前のノードと遷移に使った Command とする Hash）
    # を返す。
    #
    # Board → { Board => [Board, Command] }

    dist = nil
    score = proc do |board|
      board.score
    end

    prev = {}
    queue = PQueue.new { |a, b| score.(a) < score.(b) }
    queue << init
    dist = Hash.new { 1.0/0 }
    dist[init] = 0
    
    until queue.empty?
      curr = queue.pop
      # puts curr
      p [:score, score.(curr)]
      STDERR.puts "#{queue.size} #{dist.size}"
      return [curr, prev] if curr.solved?

      commands(curr).each do |cmd|
        # p cmd.to_s
        node = cmd.execute(curr)

        # 自分自身に循環する辺は許容しない。
        next if node.eql? curr

        # 解に辿り着けない状態の場合、探索対象に入れない。
        next if node.unsolvable?

        if dist[node] == Float::INFINITY
          node.set_score
          # node.set_hash
          # p [:score, score(node)]
          dist[node] = dist[curr] + 1
          # p node.hash
          queue << node
          
          prev[node] = [curr, cmd]
        end
      end
    end

    # 見付からなかったらどうしよう
    raise 'solution not found'
  end

  # def score(board)
  #   x, y = board.asuka
  #   xx, yy = board.kaidan
  #   return [(x - xx).abs, (y - yy).abs].max
  # end

  def run
    init = build_problem

    # w = init.inventory.find { |item| item.name == Item::WAND_HIKIYOSE }
    # c = Command.new(:throw, [0, -1], w)
    # b = c.execute init
    # puts b
    # p b.solved?
    # p b.unsolvable?
    # p b.score
    # exit

    goal, prevs = search(init)

    path = reconstruct_path(prevs, init, goal)

    print_path(path)
  end

  # 終端を含む take_while ってどうやるんだろう？
  def reconstruct_path(prevs, init, goal)
    res = []
    iterate([goal, nil]) { |(board, cmd)| prevs[board] }
      .each do |(board, cmd)|
      res << [board, cmd]
      break if board == init
    end
    return res.reverse
  end

  def iterate(init)
    Enumerator.new do |yielder|
      v = init
      loop do
        yielder << v
        v = yield(v)
      end
    end
  end

  def print_path(path)
    puts "開始"
    puts
    path.each.with_index(1) do |(board, cmd), ord|
      puts board
      puts "#{ord}. #{cmd}" if cmd
      puts
    end
    puts "終了"
  end

end

def main
  return Program.new.run
end

require_relative 'command'

# ふきとばしの杖、ひきよせの杖の魔法弾の弾道を計算する。ベクトルの対の
# リストを返す。１つ目のベクトルは魔法弾の位置、２つ目のベクトルは向き
# を表わす。
#
# (Board, [Fixnum,Fixnum]) → [ [[Fixnum,Fixnum],[Fixnum,Fixnum]] ]
def mover_bullet_trajectory(board, dir)
  res = []
  max_bullet_trajectory(board, dir).each.with_index do |(pos, dir), index|
    res << [pos, dir]
    if index != 0 and (board.characters_at(pos).any? or
                      board.item_at(pos) != nil or
                      board.kaidan_at?(pos))
      break
    end
  end
  res
end

# 場所替えの杖など、通常の杖の魔法弾の弾道を計算する。
#
# (Board, [Fixnum,Fixnum]) → [ [[Fixnum,Fixnum],[Fixnum,Fixnum]] ]
def normal_bullet_trajectory(board, dir)
  res = []
  max_bullet_trajectory(board, dir).each.with_index do |(pos, dir), idx|
    res << [pos, dir]
    if idx != 0 and board.characters_at(pos).any?
      break
    end
  end
  res
end

def max_bullet_trajectory(board, dir)
  pos        = board.asuka.pos
  # この際、壁と岩を同一視する。
  walls      = positions('■', board.map) + positions('◆', board.map)
  reflected  = false

  Enumerator.new do |yielder|
    loop do
      yielder << [pos, dir]

      x, y = pos 
      xoff, yoff = dir

      # (x, y) から (x', y') に魔法弾が移動しようとして、(x', y') が壁
      # だった場合…
      # 
      # CASE A: (x', y) が壁で (x, y') は床 → (x, y') に進んで、
      #         方向は x 軸を反転。
      # CASE B: (x, y') が壁で (x', y) は床 → (x', y) に進んで、
      #         方向は y 軸を反転。
      # CASE C: (x', y) が壁で (x, y') も壁 → 消滅。
      # CASE D: (x', y) も (x, y') も壁でない場合 → 角反射。
      # 
      # CASE C は内角に向かってつっこんだ場合。CASE D は角反射になる。
      if walls.include? [x + xoff, y + yoff]
        if xoff * yoff == 0
          break
        else
          a = walls.include?([x + xoff, y])
          b = walls.include?([x, y + yoff])
          # p [a, b]
          case [a, b]
          when [true, false]
            if !reflected
              pos = [x, y + yoff]
              dir = [-xoff, yoff]
              reflected = true
            else
              break
            end
          when [false, true]
            if !reflected
              pos = [x + xoff, y]
              dir = [xoff, -yoff]
              reflected = true
            else
              break
            end
          when [true, true]
            break
          when [false, false]
            # p "角反射"
            break if reflected
            case xoff * yoff
            when 1
              pos = [x + xoff, y]
              dir = [xoff, -yoff]
            when -1
              pos = [x, y + yoff]
              dir = [-xoff, yoff]
            else
              raise 'おかしい'
            end
            reflected = true
          end
        end
      else
        # 何事もなく進んだ場合
        pos = [x + xoff, y + yoff]
        dir = [xoff, yoff]
      end

    end
  end
end

if __FILE__ == $0
  main
end
