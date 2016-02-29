# .fei2 ファイルリーダーライブラリ

module Fei
  module Util
    # NUL終端されたShift_JISの文字列をUTF8に変換する
    def to_utf8(str)
      str.sub(/\0.*/, '').force_encoding('CP932').encode('UTF-8')
    end
    module_function :to_utf8
  end

  # IO → Book
  def read_fei2_book(io)
    book = Book.new(io)
  end
  module_function :read_fei2_book

  class Book < Struct.new(:name, :floors)
    def initialize(io)
      header = io.read(36)
      read_book_info(header)
      self.floors = []

      1.upto(Float::INFINITY) do |floor_num|
        break if io.eof?
        floors << Floor.new(io)
      end
    end

    def inspect
      "#<Book: #{name.inspect} #{floors.size} floors>"
    end

    private

    def read_book_info(header)
      magic_number, version_number, num_floors, book_name  = header.unpack("a3 n N a27")
      self.name = Util::to_utf8(book_name)
    end

  end

  class Floor < Struct.new(:difficulty_level,
                           :rooms,
                           :chikei,
                           :characters,
                           :items,
                           :traps,
                           :name,
                           :asuka_y,
                           :asuka_x,
                           :stairs_y,
                           :stairs_x)
    def initialize(io)
      block = io.read(2716)
      if block.bytesize != 2716
        raise 'premature end of block'
      end

      rooms, chikei, charas, items, traps, floor_info, floor_name, three_byte = block.unpack("a60 a1386 a320 a512 a384 a19 a32 a3")
      self.name = Util::to_utf8(floor_name)

      read_floor_info(floor_info)

      read_chikei(chikei)

      read_rooms(rooms)
      read_charas(charas)

      read_items(items)
      read_traps(traps)

    end

    def inspect
      "#<Floor: #{name.inspect}>"
    end

    private

    def read_floor_info(floor_info)
      self.asuka_y, self.asuka_x      = floor_info.unpack("CC")
      _, self.stairs_y, self.stairs_x = floor_info.unpack("a6CC")
      _, self.difficulty_level        = floor_info.unpack('a18C')
    end

    def read_rooms(rooms)
      self.rooms = []
      rooms.scan(/.{4}/m).each do |room|
        x1, y1, x2, y2 = room.unpack('CCCC')
        break if y1 == 0xff

        self.rooms << Room.new(x1, y1, x2, y2)
      end
    end

    def read_charas(charas)
      raise ArgumentError unless charas.bytesize == 320

      self.characters = []

      charas.scan(/.{10}/m).each do |chara|
        y, x, dir, kind, level, status = chara.unpack('CCvvvv')
        break if kind == 0

        self.characters << Character.new(y, x, dir, kind, level, status)
      end
    end

    def read_items(items)
      self.items = []
      items.scan(/.{8}/m).each do |item|
        y, x, kind, num, flags = item.unpack('CCvsv')
        break if y == kind
        self.items << Item.new(y, x, kind, num, flags)
      end
    end

    def read_traps(traps)
      self.traps = []
      traps.scan(/.{6}/m).map do |trap|
        y, x, kind, flags = trap.unpack('CCvv')
        break if kind == 0

        self.traps << Trap.new(y, x, kind, flags)
      end
    end

    # マップは66×42。
    def read_chikei(chikei)
      self.chikei = chikei.unpack("C1386").flat_map { |byte|
        [byte & 0x0f, (byte & 0xf0) >> 4]
      }.each_slice(66).to_a
    end

  end

  class Room < Struct.new(:x1, :y1, :x2, :y2)
  end

  class Character < Struct.new(:y, :x, :dir, :kind, :level, :status)
    def name
      if CHARACTER_KIND.has_key?(kind)
        if level - 1 < CHARACTER_KIND[kind].size
          return CHARACTER_KIND[kind][level - 1]
        else
          raise "unregistered level (#{level}) for character kind (#{kind})"
        end
      else
        raise "unregistered character kind (#{kind})"
      end
    end
  end

  class Item < Struct.new(:y, :x, :kind, :num, :flags)
    def name
      ITEM_KIND[kind] or raise "unregistered item (#{kind})"
    end
  end

  class Trap < Struct.new(:y, :x, :kind, :flags)
    def name
      raise "unregistered trap #{kind}" unless TRAP_KIND.has_key?(kind)

      return TRAP_KIND[kind]
    end

    def visible?
      flags & 0x1 == 1
    end
  end

  TRAP_KIND = {
    35 => '丸太のワナ',
    6 => '落石のワナ',
    27 => '毒矢のワナ',
    30 => '地雷',
    25 => '木の矢のワナ',
    28 => '落し穴',
    12 => '一方通行のワナ(左)',
    13 => '一方通行のワナ(右)',
    14 => '一方通行のワナ(下)',
    15 => '一方通行のワナ(上)',
    7 => '大落石のワナ',
    34 => '水滴ポットン',
    19 => '警報スイッチ',
    32 => 'デロデロの湯',
    39 => 'いかずちのワナ',
    18 => 'モンスターのワナ',
    31 => '大型地雷'
  }

  ITEM_KIND = {
    214 => '聖域の巻物',
    368 => 'トンネルの杖',
    170 => '超不幸の種',
    566 => 'ギタン',
    157 => '薬草',
    173 => '毒草',
    8 => 'ドラゴン草',
    160 => 'つるはし',
    352 => 'ふきとばしの杖',
    142 => 'デブータの石',
    364 => '引きよせの杖',
    176 => '高とび草',
    356 => '場所替えの杖',
    283 => '軟投の秘技書',
    25 => 'モーニングスター',
    9 => 'サトリのつるはし',
    145 => '大砲の弾',
    309 => '岩石割りの秘技書',
    569 => 'ンドゥバ',
    108 => '身代わりの腕輪',
    374 => 'クォーターの杖',
    361 => '鈍足の杖',
    357 => 'かなしばりの杖',
    567 => '風魔石',
    4 => 'ドラゴンキラー',
    372 => 'ばくだんの杖',
    209 => 'ゾワゾワの巻物',
    445 => 'マムルの箱',
    365 => '火ばしらの杖',
    219 => '落石の巻物',
    94 => 'まがりの腕輪',
    102 => 'ワナ師の腕輪',
    376 => 'イカリの杖',
    168 => 'くねくね草',
    166 => 'しあわせ草',
    277 => '鬼月の秘技書',
    26 => '如意棒',
    62 => 'サトリの盾',
    177 => 'すばやさの種',
    301 => '四股の秘技書',
    358 => '一時しのぎの杖',
    129 => '木の矢',
    274 => '交錯の秘技書',
  }

  CHARACTER_KIND = {
    75 => ['盗賊番'],
    107 => ['ひまガッパ', 'いやすぎガッパ', 'たまらんガッパ'],
    88 => ['マムル', 'あなぐらマムル', '洞窟マムル'],
    83 => ['トド'],
    80 => ['タウロス', 'ミノタウロス', 'メガタウロス'],
    122 => ['うしわか丸', 'クロウ丸', 'ヨシツネ丸'],
    116 => ['プチフェニックス'],
    66 => ['怪盗ペリカンのエレキ', '怪盗ペリカン2世のエレキ', '怪盗ペリカン3世のエレキ', '怪盗ペリカン4世のエレキ'],
    92 => %w[エーテルデビル ファントムデビル ミラージュデビル アストラルデビル],
    89 => %w[しろがねマムル おうごんマムル],
    95 => ['キグニ族'],
    105 => %w[ダイキライ エレーキライ チョーキライ],
    73 => %w[店主 店長 大店長],
    74 => ['番犬'],
    131 => %w[とげドラゴン アースニードル サンダーランス],
    90 => ['にぎりみならい', 'にぎりへんげ', 'にぎり親方', 'にぎりもとじめ'],
    86 => ['コドモ戦車'],
    109 => ['パ王', 'パオパ王', 'パオパ王ーン'],
    111 => ['タイガーウッホ', 'タイガーウホーン', 'タイガーウホホーン'],
    101 => ['わらうポリゴン', 'まわるポリゴン', 'おどるポリゴン', 'うたうポリゴン'],
    115 => ['オトト兵', 'オトト軍曹', 'オトト大将', 'オトト元帥'],
    103 => ['チンタラ', 'ちゅうチンタラ', 'おおチンタラ'],
    81 => ['デブータ', 'デブーチョ', 'デブートン']
  }
end
