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
require_relative 'bag'

require_relative 'kaidan'
require_relative 'item'
require_relative 'character'
require_relative 'trap'

module Enumerable
  def find_by(prop, val)
    find { |elt| elt.__send__(prop) == val }
  end

  def frequencies
    group_by { |it| it }.map { |k,v| [k,v.size] }.to_h
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

require_relative 'fei'
require_relative 'board_builder'

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
  # () → Board
  def build_problem
    # 初期状態を Board オブジェクトとして返すメソッド。

    path = './第7回ひざくさフェイ問+難.fei2'
    floor = nil
    File.open(path, 'r:ASCII-8BIT') do |f|
      floor = Fei::read_fei2_book(f).floors[49]
    end

    board = BoardBuilder.new(floor).product
    return board
  end

  def commands(board)
    # 現在の局面で取れる行動を列挙する。

    cmds = []

    # 八方向への移動。今回ナナメに動ける場所は無いが、早すぎる最適化
    # 云々――。それぞれの方向について、アイテムを拾う場合と拾わない場
    # 合の二種類がある。
    cmds += Command::DIRS.flat_map { |d|
      [CommandMove.new(d, true),
       CommandMove.new(d, false)]
    }

    # アイテムに対して行なうコマンド。
    cmds += Command::DIRS.flat_map { |d|
      board.inventory.flat_map { |item|
        [CommandThrow.new(d, item) ] + 
          [CommandUse.new(d, item)]
      }
    }

    cmds += board.inventory.to_a.uniq.map { |item|
      CommandDrop.new(item)
    }

    cmds += [ CommandPick.new ]

    return cmds
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

    prev = {}
    queue = PQueue.new { |a, b| a.score < b.score }
    queue << init
    prev[init] = nil
    # visited = Hash.new { false }
    # visited[init] = true
    
    until queue.empty?
      curr = queue.pop
      # puts curr
      puts
      p [:score, curr.score]
      STDERR.puts "#{queue.size} #{prev.size}"
      if curr.solved?
        # p visited.keys.map { |b| b.hash % 65536 }.frequencies.values.frequencies
        return [curr, prev]
      end

      commands(curr).each do |cmd|
        # puts cmd
        node = curr.deep_copy
        cmd.execute(node)
        node.asuka.dir = [0,1]

        node.set_score
        node.set_hash

        # 自分自身に循環する辺は許容しない。
        if node.eql? curr
          # puts 'no change'
          next 
        end

        # 解に辿り着けない状態の場合、探索対象に入れない。
        if node.unsolvable?
          # puts 'unsolvable'
          next 
        end

        if !prev.has_key?(node)
          # puts node
          # p [:score, score(node)]
          # visited[node] = true
          # p node.hash
          queue << node
          
          prev[node] = [curr, cmd]
          print '*'
        else
          # puts node
          print '.'
        end
        # STDOUT.flush
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

# ふきとばしの杖、ひきよせの杖の魔法弾の弾道を計算する。キャラクター、
# アイテム、階段に当たる。同じマスに複数の種類のオブジェクトがあった場
# 合も、この順番で選択される。
#
# ベクトルの対のリストを返す。１つ目のベクトルは魔法弾の位置、２つ目の
# ベクトルは向きを表わす。
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

# アイテムのふきとばしは,キャラクターにしか当たらず、角抜け可能。
def fukitobashi_trajectory(board, pos, dir)
  throw_trajectory(board, pos, dir)
end

# 一直線に飛んでいって、キャラクターに当たるような弾道の計算。
def throw_trajectory(board, pos, dir)
  res = []
  charas = (board.characters.map(&:pos) + [board.asuka.pos]).to_set
  walls = (positions('■', board.map) + positions('◆', board.map)).to_set
  xoff, yoff = dir

  loop do
    res << [pos, dir]
    if res.size > 1 && charas.include?(pos)
      break
    elsif walls.include?(Vec::plus(pos, dir))
      break
    else
      pos = Vec::plus(pos, dir)
    end
  end

  return res
end

# 場所替えの杖など、通常の杖の魔法弾の弾道を計算する。キャラクターにし
# か当たらない。
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

def max_trajectory(board, pos, dir)
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

def max_bullet_trajectory(board, dir)
  max_trajectory(board, board.asuka.pos, dir)
end

if __FILE__ == $0
  main
end
