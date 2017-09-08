# Tictactoe with unbeatable bot, using a minimax implementation made faster
# through alpha-beta pruning

class Board
  WINNING_LINES = [[1, 2, 3], [4, 5, 6], [7, 8, 9],
                   [1, 4, 7], [2, 5, 8], [3, 6, 9],
                   [1, 5, 9], [3, 5, 7]].freeze

  def initialize(copy_squares = nil)
    @squares = copy_squares || {}
    reset unless copy_squares
  end

  def copy
    new_squares = @squares.map { |key, square| [key, square.dup] }.to_h
    self.class.new(new_squares)
  end

  def []=(key, marker)
    @squares[key].marker = marker
  end

  def all_unmarked_keys
    unmarked_keys_in((1..9).to_a)
  end

  def unmarked_keys_in(group)
    @squares.keys.select do |key|
      @squares[key].unmarked? && group.include?(key)
    end
  end

  def full?
    all_unmarked_keys.empty?
  end

  def someone_won?
    !!winning_marker
  end

  def winning_marker
    markers_played.each do |marker|
      WINNING_LINES.each do |line|
        if identical_markers?(3, marker, @squares.values_at(*line))
          return marker
        end
      end
    end
    nil
  end

  def markers_played
    @squares.values.select(&:marked?).map(&:marker).uniq
  end

  def potential_win(marker)
    WINNING_LINES.each do |line|
      if unmarked_keys_in(line).size == 1 &&
         identical_markers?(2, marker, @squares.values_at(*line))
        return unmarked_keys_in(line)[0]
      end
    end
    nil
  end

  def reset
    (1..9).each { |key| @squares[key] = Square.new }
  end

  # rubocop:disable Metrics/AbcSize
  def draw
    puts "     |     |"
    puts "  #{@squares[1]}  |  #{@squares[2]}  |  #{@squares[3]}"
    puts "     |     |"
    puts "-----+-----+-----"
    puts "     |     |"
    puts "  #{@squares[4]}  |  #{@squares[5]}  |  #{@squares[6]}"
    puts "     |     |"
    puts "-----+-----+-----"
    puts "     |     |"
    puts "  #{@squares[7]}  |  #{@squares[8]}  |  #{@squares[9]}"
    puts "     |     |"
  end
  # rubocop:enable Metrics/AbcSize

  private

  def identical_markers?(count, player_marker, squares_to_check)
    markers_to_check = squares_to_check.map(&:marker)
    markers_to_check.count(player_marker) == count
  end
end

class Square
  INITIAL_MARKER = " ".freeze
  attr_accessor :marker

  def initialize(marker = INITIAL_MARKER)
    @marker = marker
  end

  def unmarked?
    marker == INITIAL_MARKER
  end

  def marked?
    !unmarked?
  end

  def to_s
    @marker
  end
end

class Player
  attr_accessor :marker
  attr_reader :name

  def to_s
    name
  end
end

class Computer < Player
  def initialize(board)
    @board = board
  end

  def set_name
    @name = %w(R2D2 C3PO Awesome-O BeepBopRobot Sonny).sample
  end

  def marker=(marker)
    @marker = marker
    @other_marker = (['X', 'O'] - [@marker]).first
  end

  def move
    puts "#{name}'s thinking..."
    square = find_optimal_choice
    sleep(0.2)
    @board[square] = marker
  end

  private

  def find_optimal_choice
    move_scores.max_by { |_, score| score }[0]
  end

  def move_scores
    @board.all_unmarked_keys.each_with_object(Hash.new) do |move, scores|
      new_board = @board.copy
      new_board[move] = @marker
      scores[move] = minimax(new_board, false, -1000, 1000)
    end
  end

  def minimax(board, computer_turn, alpha, beta)
    return end_state_value(board.winning_marker) if board.full? ||
                                                    board.someone_won?

    if computer_turn then simulate_move(board, alpha, beta)
    else                  simulate_opponent_move(board, alpha, beta)
    end
  end

  def simulate_move(board, alpha, beta)
    board.all_unmarked_keys.each do |move|
      new_board = board.copy
      new_board[move] = @marker
      score = minimax(new_board, false, alpha, beta)
      alpha = score if score > alpha
      break if alpha >= beta
    end
    alpha
  end

  def simulate_opponent_move(board, alpha, beta)
    board.all_unmarked_keys.each do |move|
      new_board = board.copy
      new_board[move] = @other_marker
      score = minimax(new_board, true, alpha, beta)
      beta = score if score < beta
      break if alpha >= beta
    end
    beta
  end

  def end_state_value(winner)
    { @marker => 1, @other_marker => -1, nil => 0 }[winner]
  end
end

class Human < Player
  def set_name
    puts "What is your name?"
    name = nil
    loop do
      name = gets.chomp
      break if /\w/ =~ name
      puts "Sorry, must enter something for your name..."
    end
    @name = name
  end
end

class TTTGame
  MARKER_OPTIONS = %w(X O).freeze
  FIRST_TO_MOVE = MARKER_OPTIONS.first

  attr_reader :board, :human, :computer, :score

  def initialize
    @board = Board.new
    @human = Human.new
    @computer = Computer.new(board)
    @current_marker = FIRST_TO_MOVE
    @score = { human: 0, computer: 0 }
  end

  def play
    clear
    display_welcome_message
    [human, computer].each(&:set_name)
    choose_marker
    loop do
      play_game
      display_result('game')
      break unless play_again?
      reset_game
    end
    display_goodbye_message
  end

  private

  def display_welcome_message
    puts "Welcome to Tic Tac Toe!"
    puts ""
  end

  def display_goodbye_message
    puts "Thanks for playing Tic Tac Toe! Goodbye!"
  end

  def display_board
    puts "#{human}(#{human.marker}) : #{@score[:human]} | "\
          "#{computer}(#{computer.marker}) : #{@score[:computer]}"
    puts ""
    board.draw
    puts ""
  end

  def clear_screen_and_display_board
    clear
    display_board
  end

  def joinor(list, delimiter = ',', conjunction = 'or')
    if list.size <= 2
      list.join(" #{conjunction} ")
    else
      list[0...-1].join(delimiter) + " #{conjunction} #{list.last}"
    end
  end

  def human_moves
    puts "Choose a square (#{joinor(board.all_unmarked_keys)}):"
    square = nil
    loop do
      square = gets.chomp.to_i
      break if board.all_unmarked_keys.include?(square)
      puts "Sorry, that's not a valid choice"
    end

    board[square] = human.marker
  end

  def switch_player
    @current_marker = human_turn? ? computer.marker : human.marker
  end

  def current_player_moves
    if human_turn? then human_moves
    else computer.move
    end
  end

  def human_turn?
    @current_marker == human.marker
  end

  def display_result(event)
    clear_screen_and_display_board

    case board.winning_marker
    when human.marker
      puts "You won the #{event}!"
    when computer.marker
      puts "#{computer} won the #{event}!"
    else
      puts "It's a tie!"
    end
    puts
  end

  def play_round
    loop do
      current_player_moves
      return if board.someone_won? || board.full?
      switch_player
      clear_screen_and_display_board if human_turn?
    end
  end

  def play_game
    loop do
      clear_screen_and_display_board
      play_round
      update_score
      return if winner?
      display_result('round')
      new_round
    end
  end

  def display_marker_options
    puts "\nChoose your marker"
    puts "#{FIRST_TO_MOVE} => first turn"
    puts "#{(MARKER_OPTIONS - [FIRST_TO_MOVE])[0]} => second turn"
  end

  def choose_marker
    display_marker_options
    choice = nil
    loop do
      choice = gets.chomp.upcase
      break if MARKER_OPTIONS.include?(choice)
      puts "Sorry, must be either #{joinor(MARKER_OPTIONS)}"
    end
    human.marker = choice
    computer.marker = (MARKER_OPTIONS - [human.marker])[0]
  end

  def update_score
    case board.winning_marker
    when human.marker then @score[:human] += 1
    when computer.marker then @score[:computer] += 1
    end
  end

  def winner?
    @score.values.include?(5)
  end

  def new_round
    puts "Press enter to continue..."
    gets
    @current_marker = FIRST_TO_MOVE
    board.reset
    clear
  end

  def reset_game
    new_round
    @score[:human] = 0
    @score[:computer] = 0
  end

  def play_again?
    answer = nil
    loop do
      puts "Would you like to play again? (y/n)"
      answer = gets.chomp.downcase
      break if %w(y n).include?(answer)
      puts "Sorry, must be y or n"
    end

    answer == 'y'
  end

  def clear
    system 'clear'
  end
end

game = TTTGame.new
game.play
