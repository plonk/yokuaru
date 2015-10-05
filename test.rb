require 'colorize'
require_relative 'main'

def h(str)
  puts
  puts str.green
end

h "局面を生成してみる"
board = build_demo_problem
usi = board.characters.find_by(:name, 'うしわか丸')
usi.dir = [-1,-1]
puts board

h "右に動いてみる"
c = Command.create(:move, [+1, 0], true)
c.execute(board)
puts board

h "左上に場所替えの杖を振る"
wand = board.inventory.find_by(:name, Item::WAND_HIKIYOSE)
p wand
Command.create(:use, [-1, -1], wand).execute(board)
puts board

# h "上にひきよせの杖を振る"
# wand = board.inventory.find_by(:name, Item::WAND_HIKIYOSE)
# p wand
# Command.create(:use, [0, -1], wand).execute(board)
# puts board

# h "上に動いてみる"
# c = Command.create(:move, [0, -1])
# board = c.execute(board)
# puts board


# h "右上にふきとばしの杖を投げてみる"
# wand = board.inventory.find_by(:name, "ふきとばしの杖")
# c = Command.create(:throw, [1, -1], wand)
# board = c.execute(board)
# puts board

# h "上に動いてみる"
# c = Command.create(:move, [0, -1])
# board = c.execute(board)
# puts board

# h "右上に場所替えの杖を投げてみる"
# wand = board.inventory.find_by(:name, "場所替えの杖")
# c = Command.create(:throw, [1, -1], wand)
# board = c.execute(board)
# puts board
