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
  puts "解けてる！".green if board.solved?
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
step(board, :move, [0, 1], true)
step(board, :move, [0, -1], true)
wand = board.inventory.find_by(:name, Item::WAND_BASHOGAE)
step(board, :use, [-1, 1], wand)
step(board, :move, [-1, 0], true)
wand = board.inventory.find_by(:name, Item::WAND_FUKITOBASHI)
step(board, :throw, [1, -1], wand)
2.times do
  step(board, :move, [1, 0], true)
end
wand = board.inventory.find_by(:name, Item::WAND_HIKIYOSE)
step(board, :use, [-1, -1], wand)
step(board, :move, [-1, 0], true)
step(board, :move, [-1, -1], true)
step(board, :move, [0, -1], true)
wand = board.inventory.find_by(:name, Item::WAND_BASHOGAE)
step(board, :throw, [1, 0], wand)
wand = board.inventory.find_by(:name, Item::WAND_HIKIYOSE)
step(board, :throw, [-1, 0], wand)
step(board, :move, [0, -1], true)
