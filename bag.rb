class Bag
  class << Bag
    def [](*elts)
      Bag.new(elts)
    end
  end

  include Enumerable

  def initialize(ary = [])
    @ary = ary.dup
  end

  def initialize_copy(orig)
    @ary = orig.instance_variable_get(:@ary).dup
  end

  def each(&block)
    @ary.each(&block)
  end

  def add(elt)
    @ary << elt
    self
  end
  alias << add

  def inspect
    "Bag#{@ary.inspect}"
  end

  def delete(target)
    idx = @ary.index { |elt| elt == target }
    @ary.delete_at(idx) if idx
    self
  end

  def to_a
    @ary.dup
  end

  def hash
    @ary.map(&:hash).inject(0, :^)
  end

  def eql?(other)
    self == other
  end

  def ==(other)
    (self - other).empty? && (other - self).empty?
  end

  def [](that)
    @ary.find { |elt| elt == that }
  end
  alias find_eql []

  def -(other)
    ary = @ary.dup
    other.each do |elt|
      idx = ary.index(elt)
      ary.delete_at(idx) if idx
    end
    Bag.new(ary)
  end

  def +(other)
    raise TypeError unless other.is_a? Bag
    @ary.concat(other.instance_variable_get(:@ary))
  end

  def size
    @ary.size
  end

  def empty?
    @ary.empty?
  end

  def include?(target)
    @ary.include?(target)
  end
end
