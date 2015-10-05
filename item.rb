# アイテムを表わすクラスを定義する。簡便の為に Struct クラスを継承し、
# name、number、pos の３つのフィールドを定義する。アイテムの種類によっ
# て内部構造やクラスを変化させることはしない。
#
# name は String でアイテムの名前。number は Fixnum で杖の残量などを意
# 味させる。回数が意味の無いアイテムでは nil に設定しよう。pos は
# [Fixnum,Fixnum] でマップ上での位置を示す。持ち物として持っている場合
# は nil を設定しよう。
#
# 祝福・呪いなどの追加の状態を持たせたかったら、このクラスにフィールド
# を追加すると良いだろう。
#
class Item < Struct.new(:name, :number, :pos)
  WAND_BASHOGAE    = "場所替えの杖"
  WAND_FUKITOBASHI = "ふきとばしの杖"
  WAND_HIKIYOSE    = "引きよせの杖"
  HERB_ZASSOU      = "雑草"

  # メッセージ表示に適した形に文字列化する。
  def to_s
    if number
      # 「引きよせの杖[20]」などと表示する。
      "#{name}[#{number}]"
    else
      name
    end
  end

  def <=>(other)
    [name, number, pos] <=> [other.name, other.number, other.pos]
  end

  # このアイテムをマップ上で表わす場合のシンボルとして使う全角一字。ア
  # イテムは総じて説明的な名前が付けられているので、最後の一字を用いる
  # と統辞形態的主要部に一致して都合が良い。
  def symbol
    name[-1]
  end

  # Board を返す。
  def use(board, actor)
    case name
    when Item::WAND_HIKIYOSE
      execute_hikiyose(board, actor)
    when Item::WAND_BASHOGAE
      execute_bashogae(board, actor)
    else
      # デフォルトのアイテム使用ルーチン。アイテムの効果は実装しない。
      # 無くなるだけ。
      inventory.delete(item)
    end
  end

  private

  # ひきよせの杖を振る。
  #
  def execute_hikiyose(board, actor)
    wand = self
    dir = actor.dir

    # 杖の回数が 0 の場合は何も起きない。
    if wand.number == 0
      puts "杖の回数が無い"
      return
    end

    # まず魔法弾の軌道を計算し、何かのエンティティ（今回は盗賊番だけを
    # 考慮する）に着弾したかどうかを判定する。
    # 
    # 着弾しなかった場合は、局面は変化しない。した場合は、魔法弾
    # の方向と逆方向にエンティティをひきよせる。
    # 
    # ひきよせの効果は障害物に当たるまで、エンティティが移動するという
    # もの。（いろいろはしょる）
    # 
    # （アスカと敵をキャラクターとして統一的に扱えば、移動可能の判定を
    # 流用できるんだよなあ…）

    target, bullet_dir = hikiyose_target_direction(board, dir)
    unless target
      # 何にも当たらなかったので、局面は変化しない。
      puts "何にも当たらなかった"
      return
    end

    newpos = hikiyose_move(board, target, Vec::opposite_of(bullet_dir))

    # 動かなかった。
    if target == newpos
      return
    end

    # 引きよせの杖で newpos に落下しようとする。キャラクターとアイテム
    # の場合で落下法則が異なる。
    if board.characters_at(target).any?
      # 引きよせるのはキャラクター。
      chara, = board.characters_at(target)

      board.characters.delete(chara)
      newpos = board.character_drop(newpos, chara.dir)
      chara.pos = newpos
      board.characters << chara
    elsif board.item_at(target) != nil
      # 引きよせるのはアイテム。

      # p "アイテム引きよせ"

      # 実際に落ちる位置を調整する。
      newpos = board.item_drop(newpos)

      board.item_at(target).pos = newpos
    else
      unless board.kaidan == target
        raise 'uncovered case'
      end

      board.kaidan = newpos
    end

    # 引きよせの杖の回数を減らす。あるいは減らさない。
    if true
      # 足元の杖を使った場合は、杖は inventory ではなく、items にある。
      wand.number -= 1
    end
  end

  # (Board, [Fixnum,Fixnum]) → [?[Fixnum,Fixnum], ?[Fixnum,Fixnum]]
  def hikiyose_target_direction(board, dir)
    # ひきよせの魔法弾の弾道を計算して、エンティティに当たった場合はそ
    # のエンティティの座標と、当たった時の魔法弾の方向ベクトルを返し、
    # 何にも当たらなかった場合は [nil, nil] を返す。

    traj = magic_bullet_trajectory(board, dir).to_a
    if traj.size == 1
      return [nil, nil]
    end
    pos, dir = traj.last
    
    if board.characters_at(pos).any? or board.items.any? { |item| item.pos == pos } or board.kaidan == pos
      return [pos, dir]
    else
      return [nil, nil]
    end
  end

  def hikiyose_move(board, mammal, dir)
    # ひきよせ効果によるキャラクターの移動。dir は魔法弾の方向。

    obstacles = board.characters + positions('■', board.map) + positions('◆', board.map) + [board.asuka.pos]
    x, y = mammal
    xoff, yoff = dir

    loop do
      if obstacles.include? [x + xoff, y + yoff] 
        break
      else
        x += xoff
        y += yoff
      end
    end

    return [x, y]
  end

end
