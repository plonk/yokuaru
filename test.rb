require 'colorize'
require_relative 'main'

def h(str)
  puts
  puts str.green
end

def step(board, *cmd_args)
  Command.create(*cmd_args).tap { |cmd| h cmd.to_s }.execute(board)
  puts board
  puts "アスカが死んだ".red if board.asuka.dead?
end

h "局面を生成してみる"
board = build_demo_problem
puts board

wand = board.inventory.find_by(:name, Item::WAND_BASHOGAE)
step(board, :use, [-1, -1], wand)
step(board, :move, [0, 1], true)
wand = board.inventory.find_by(:name, Item::WAND_BASHOGAE)
step(board, :drop, wand)
step(board, :move, [0, -1], true)
wand = board.inventory.find_by(:name, Item::WAND_FUKITOBASHI)
step(board, :use, [-1,1], wand)

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
