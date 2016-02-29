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
  WAND_BASHOGAE    = :"場所替えの杖"
  WAND_FUKITOBASHI = :"ふきとばしの杖"
  WAND_HIKIYOSE    = :"引きよせの杖"
  HERB_ZASSOU      = :"雑草"

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

  # アイテムを actor が使う。
  def use(board, actor)
    case name
    when Item::WAND_HIKIYOSE
      use_hikiyose(board, actor)
    when Item::WAND_BASHOGAE
      use_bashogae(board, actor)
    when Item::WAND_FUKITOBASHI
      use_fukitobashi(board, actor)
    else
      # デフォルトのアイテム使用ルーチン。アイテムの効果は実装しない。
      # 無くなるだけ。
      board.inventory.delete(self)
    end
  end

  # 投擲が当たるときに起こることは、行為者と対象（及び到着時の対象の向
  # き）と行き先に依存する。
  # 
  # 例えば、行き先がモンスターで、投擲ダメージの結果、モンスターが死ん
  # だら行為者に経験値が入る。対象が移動系の杖だった場合は、当たった向
  # きが関係してくる。
  # 
  # 対象がワナだった場合は、対象の種類はあまり関係がない。地雷の上に落
  # ちればなんだって消えてなくなる。

  def hit_as_projectile(board, dest, dir, actor)
    raise TypeError unless dest.is_a?(Character) || dest.is_a?(Trap)

    case dest
    when Character
      dest.hit_by_projectile(board, self, dir, actor) # なんじゃこりゃ。  
    when Trap
      dest.land(board, self)
    end
    
  end

  # アイテムが dir 方向に吹き飛ばされる。Item, Character, Kaidan にこ
  # のメソッドを持たせて、それぞれの挙動を実装しよう。
  def fukitobasareru(board, dir, actor)
    traj = fukitobashi_trajectory(board, pos, dir)

    # 落下位置計算の為に、自分を削除しておく。
    board.items.delete(self)

    pos, dir = traj.last 

    if chara = board.character_at(pos)
      hit_as_projectile(board, chara, dir, actor)
    elsif trap = board.trap_at(pos)
      hit_as_projectile(board, trap, dir, actor)
    else
      # 何にも当たらず落ちた。
      newpos = board.item_drop(pos)

      if newpos == nil
        # puts "アイテムは消えた。"
      else
        self.pos = newpos
        board.items.add(self)
      end
    end
  end

  def hit_effect(board, dest, dir, actor)
    case name
    when WAND_BASHOGAE
      do_bashogae(board, actor, dest)
    when WAND_HIKIYOSE
      do_hikiyose(board, dest.pos, dir)
    when WAND_FUKITOBASHI
      dest.fukitobasareru(board, dir, actor)
    else
      raise 'unimplemented'
    end
    
  end

  private

  # ひきよせの杖を振る。
  #
  def use_hikiyose(board, actor)
    wand = board.inventory[self] || board.items[self]
    dir = actor.dir

    # 杖の回数が 0 の場合は何も起きない。
    if wand.number == 0
      # puts "杖の回数が無い"
      return
    else
      # 足元の杖を使った場合は、杖は inventory ではなく、items にある。
      wand.number -= 1
    end

    # まず魔法弾の軌道を計算し、何かのエンティティに着弾したかどうかを
    # 判定する。
    # 
    # 着弾しなかった場合は、局面は変化しない。した場合は、魔法弾の方向
    # と逆方向にエンティティをひきよせる。
    # 
    # ひきよせの効果は障害物に当たるまで、エンティティが移動するという
    # もの。（いろいろはしょる）
    # 
    # （アスカと敵をキャラクターとして統一的に扱えば、移動可能の判定を
    # 流用できるんだよなあ…）

    target, bullet_dir = mover_target_direction(board, dir)
    unless target
      # 何にも当たらなかったので、局面は変化しない。
      # puts "何にも当たらなかった"
      return
    end

    # 着弾の方向と逆向きにひきよせ効果を発動する。

    do_hikiyose(board, target, bullet_dir)
  end

  def do_hikiyose(board, target, bullet_dir)
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

      board.characters -= [chara]
      newpos = board.character_drop(newpos, chara.dir)
      chara.pos = newpos
      board.characters << chara
    elsif item = board.item_at(target)
      board.items.delete(item)
      # 引きよせるのはアイテム。実際に落ちる位置を調整する。
      if trap = board.trap_at(newpos)
        trap.land(board, item)
      else
        newpos = board.item_drop(newpos)

        item.pos = newpos
        board.items << item
      end
    else
      unless board.kaidan.pos == target
        raise 'uncovered case'
      end

      board.kaidan.pos = newpos
    end
  end

  # 場所替えの杖を振る処理だ。
  def use_bashogae(board, actor)
    return if number == 0

    wand = board.inventory[self] || board.items[self]

    # 杖の回数が１減る。
    wand.number -= 1

    # 場所替えの弾道を計算して、キャラクターに当たるかどうか判定する。
    # 当たらなかった場合は何も起こらないが、当たった場合はそのキャラク
    # ターと場所替える。
    # 
    # 場所替えた後、着地位置を計算し、着地する。着地位置にワナがあった
    # 場合はワナが発動する。

    traj = normal_bullet_trajectory(board, actor.dir).to_a
    if traj.size == 1
      return
    end

    target_chara_pos, _bullet_dir = traj.last

    target, = board.characters_at(target_chara_pos)

    if target == nil
      return
    end

    do_bashogae(board, actor, target)

  end

  def do_bashogae(board, actor, target)
    # 場所替えた時の、アスカと敵の落下位置ってどういう順番で決まるんだ
    # ろう？　問題になる場合はないのかな。敵が先に落下してアスカの落下
    # 位置が変わるとか。お互いに相手が存在できない地形に立っていないと
    # だめだから、ないか。
    #
    board.characters -= [actor]
    board.characters -= [target]
    new_target_pos   =  actor.pos
    new_actor_pos    =  target.pos
    target.pos       =  board.character_drop(new_target_pos, target.dir)
    actor.pos        =  board.character_drop(new_actor_pos, actor.dir)
    board.characters << actor
    board.characters << target

    asuka = [actor, target].find { |chara| chara.name == Character::ASUKA }
    trap = board.trap_at(asuka.pos)
    if trap
      trap.step(board, asuka)
    end
  end

  # ふきとばしの杖を振る処理だ。
  def use_fukitobashi(board, actor)
    # 杖の回数が無ければ振れない。あれば回数は１減る。（この辺はどの杖
    # でも同じだから統一したい）
    return if number == 0

    wand = board.inventory[self] || board.items[self]
    wand.number -= 1

    target_pos, bullet_dir = mover_target_direction(board, actor.dir)
    unless target_pos
      return
    end
    
    # 何かをふきとばした。何かにふきとんでもらう。
    obj = board.top_object_at(target_pos)
    obj.fukitobasareru(board, bullet_dir, actor)
  end

  # (Board, [Fixnum,Fixnum]) → [?[Fixnum,Fixnum], ?[Fixnum,Fixnum]]
  def mover_target_direction(board, dir)
    # ひきよせの魔法弾の弾道を計算して、エンティティに当たった場合はそ
    # のエンティティの座標と、当たった時の魔法弾の方向ベクトルを返し、
    # 何にも当たらなかった場合は [nil, nil] を返す。

    traj = mover_bullet_trajectory(board, dir).to_a
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

    obstacles = Set.new(board.characters.map(&:pos).to_a + positions('■', board.map) + positions('◆', board.map) + [board.asuka.pos])
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
