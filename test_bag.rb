require_relative 'bag'
require 'test/unit'

class MArrayTest < Test::Unit::TestCase
  def test_input
    assert_equal (Bag[] << 1), Bag[1]
  end

  def test_brackets
    bag = Bag[]
    assert_true bag.empty?

    bag = Bag[1,2,3]
    assert_equal bag.size, 3
  end

  def test_new
    bag = Bag.new
    assert_true bag.empty?

    bag = Bag.new [1,2,3]
    assert_equal bag.size, 3
  end

  def test_include?
    bag = Bag[1,2,3]

    assert_true bag.include? 1

    assert_false bag.include? 9
  end

  def test_size
    bag = Bag[1,2,3]
    assert_equal bag.size, 3
  end

  def test_empty?
    bag = Bag[]
    assert_true bag.empty?
  end

  def test_plus
    bag = Bag[1,2,3] + Bag[4,5,6]
    assert_equal bag.size, 6

    bag = Bag[1,1,1] + Bag[1,1,1]
    assert_equal bag.size, 6
  end

  def test_minus
    bag = Bag[1,1,1] - Bag[1]
    assert_equal bag.size, 2

    bag = Bag[1,2,3] - Bag[1,9,8]
    assert_equal bag.size, 2

    bag = Bag[1,1,1] - Bag[1,1,1]
    assert_true bag.empty?

    bag = Bag[1,2,3] - Bag[4,5,6]
    assert_equal bag.size, 3
  end

  def test_equals
    assert_true Bag[1] == Bag[1]
    assert_true Bag["a"] == Bag["a"]

    # 要素オブジェクトへの変更は Bag 自体の値を変える
    bag = Bag["a"]
    bag["a"].upcase!
    assert_true bag == Bag["A"]

    assert_true Bag[1,2,3] == Bag[3,2,1]
    assert_false Bag[1,2,3] == Bag[1,2,3,3]
  end

  def test_find_eql
    assert_equal Bag["a"].find_eql("a"), "a"
    assert_equal Bag["a"].find_eql("b"), nil
  end

  def test_hash
    assert_equal Bag['1','2','3'].hash, Bag['2','3','1'].hash
  end

  def test_delete
    assert_equal Bag['1','2','2','3'].delete('2'), Bag['1','2','3']
  end

  def test_inspect
    assert_equal eval(Bag[1,2,3].inspect), Bag[1,2,3]
  end

  def test_add
    assert_equal Bag[1,2,3].add(0), Bag[0,1,2,3]
  end

  def test_dup
    bag = Bag[1,2,3]
    _bag = bag.dup
    bag.delete(1)
    assert_not_equal bag, _bag
  end

  def test_clone
    bag = Bag[1,2,3]
    _bag = bag.clone
    bag.delete(1)
    assert_not_equal bag, _bag
  end
end
