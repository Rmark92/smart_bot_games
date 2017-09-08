# The BestRobot option tracks the success of all the other robot strategies
# against the player's move history and subs in the best one

class Move
  OPTIONS = { 'r' => 'rock', 'p' => 'paper', 's' => 'scissors' }.freeze

  WINNERS = { 'rock' => 'scissors',
              'paper' => 'rock',
              'scissors' => 'paper' }.freeze

  attr_accessor :value

  def initialize(choice)
    @value = choice
  end

  def beats?(other_move)
    WINNERS[value] == other_move.value
  end

  def to_s
    @value
  end
end

module Strategies
  def predict_next_move(move_sequences, player_move_history)
    predicted_move = nil
    move_sequences.each do |sequence|
      recent_moves = player_move_history[-(sequence.size - 1)..-1]
      break predicted_move = sequence.last if sequence[0...-1] == recent_moves
    end
    predicted_move
  end

  def counter_move(predicted_move)
    Move::WINNERS.select { |_, loser| loser == predicted_move }.keys[0]
  end

  def play_against_favorites(move_frequency)
    weighted_move_options = []
    move_frequency.each do |move, count|
      count.times { |_| weighted_move_options << counter_move(move) }
    end

    (weighted_move_options + Move::OPTIONS.values).sample
  end

  def minimize_losses(result_percentages)
    moves_weighted_against_losses = []
    Move::OPTIONS.values.each do |move|
      weighted_move_count = ((1 - result_percentages[move][:loss]) * 5).round
      weighted_move_count.times { moves_weighted_against_losses << move }
    end

    (moves_weighted_against_losses + Move::OPTIONS.values).sample
  end

  def random_pick
    Move::OPTIONS.values.sample
  end
end

class Player
  attr_accessor :move, :name

  def to_s
    name
  end
end

class Computer < Player
  include Strategies
  attr_accessor :log, :stats

  def initialize(name, log, stats)
    @log = log
    @stats = stats
    @name = name
  end

  def reveal_strategy
    puts self.class::STRATEGY_DISPLAY
  end

  def choose_based_on_prediction(human_sequences)
    prediction = predict_next_move(human_sequences, log.moves[:human].map(&:value))
    prediction ? counter_move(prediction) : random_pick
  end
end

class Sonny < Computer
  STRATEGY_DISPLAY = <<~END_MSG
    I weigh my options based on the number of times you've played
    each move. The more you play a given move, the more likely I
    am to choose a move that beats it.
  END_MSG
                     .freeze

  def initialize(log, stats)
    super('Sonny', log, stats)
  end

  def choose
    player_favorites = stats.calculate_move_frequency(:human)
    choice = play_against_favorites(player_favorites)
    self.move = Move.new(choice)
  end
end

class BeepBopRobot < Computer
  STRATEGY_DISPLAY = <<~END_MSG
    I weigh my options based on the number of times I lose with
    each move.  The more I lose with a given move, the less likely
    I am to play it.
  END_MSG
                     .freeze

  def initialize(log, stats)
    super('Beep.Bop.Robot', log, stats)
  end

  def choose
    losses_per_move = stats.calculate_result_percentages(:computer)
    self.move = Move.new(minimize_losses(losses_per_move))
  end
end

class R2D2 < Computer
  STRATEGY_DISPLAY = <<~END_MSG
    I figure out the move you usually play after your last move
    and pick a move that beats it.
  END_MSG
                     .freeze

  def initialize(log, stats)
    super('R2D2', log, stats)
  end

  def choose
    choice = choose_based_on_prediction(stats.move_sequences_by_frequency(:human))
    self.move = Move.new(choice)
  end
end

class C3PO < Computer
  STRATEGY_DISPLAY = <<~END_MSG
    I don't trust R2's approach.  R2D2 picks a move that beats the move
    you usually play after your last move. I choose the move that beats
    R2D2's choice.
  END_MSG
                     .freeze

  def initialize(log, stats)
    super('C3PO', log, stats)
  end

  def choose
    choice = counter_move(choose_based_on_prediction(stats.move_sequences_by_frequency(:human)))
    self.move = Move.new(choice)
  end
end

class AwesomeO < Computer
  STRATEGY_DISPLAY = <<~END_MSG
    I use your move patterns to predict what you'll do next and play
    a move that beats it.  I'll look for a pattern that matches your
    last sequence of moves, the longer the pattern the better
  END_MSG
                     .freeze

  def initialize(log, stats)
    super('Awesome-O', log, stats)
  end

  def choose
    choice = choose_based_on_prediction(stats.move_sequences_by_length(:human))
    self.move = Move.new(choice)
  end
end

class RandomO < Computer
  STRATEGY_DISPLAY = "I dunno...I just pick!".freeze

  def initialize(log, stats)
    super('Random-O', log, stats)
  end

  def choose
    self.move = Move.new(random_pick)
  end
end

class BestRobot < Computer
  ALL_ROBOTS = [Sonny, BeepBopRobot, AwesomeO, R2D2, C3PO, RandomO].freeze

  def initialize(log, stats)
    @bots = ALL_ROBOTS.map do |robot|
      new_log = Log.new
      robot.new(new_log, Stats.new(new_log))
    end
    super('BestRobot', log, stats)
  end

  def update_bot_logs
    @bots.each do |bot|
      unless @log.moves[:human].empty?
        bot.log.moves[:human] << @log.moves[:human].last
        bot.log.update_winner
      end
    end
  end

  def find_best_bot
    @bots.max_by do |bot|
      bot.log.moves[:winner].last(5).count(:computer) -
        bot.log.moves[:winner].last(5).count(:human)
    end
  end

  def choose
    update_bot_logs
    @best_bot = find_best_bot
    @bots.each { |bot| bot.log.moves[:computer] << bot.choose }
    self.move = @best_bot.move
  end

  def reveal_strategy
    puts "Subbed in...#{@best_bot}"
    puts @best_bot.class::STRATEGY_DISPLAY
  end
end

class Human < Player
  def choose
    puts "Pick a move..."
    choice = ''
    loop do
      Move::OPTIONS.each { |input, move| puts "#{input} => #{move}" }
      puts "? => random move"
      choice = register_move
      break unless choice == :invalid
      puts "Invalid choice.  Please choose from the following:"
    end

    self.move = Move.new(choice)
  end

  def register_move
    choice = gets.chomp.downcase
    if choice == '?' || choice == 'random move'
      Move::OPTIONS.values.sample
    elsif Move::OPTIONS.values.include?(choice)
      choice
    else
      Move::OPTIONS.fetch(choice, :invalid)
    end
  end
end

class Log
  attr_accessor :moves, :score

  def initialize
    @score = { human: 0, computer: 0 }
    @moves = { human: [], computer: [], winner: [] }
    @full_history_display = []
  end

  def update(human_move, computer_move)
    update_moves(human_move, computer_move)
    update_winner
    update_history_display
    update_score
  end

  def update_moves(human_move, computer_move)
    moves[:human] << human_move
    moves[:computer] << computer_move
  end

  def update_winner
    human_move = moves[:human].last
    computer_move = moves[:computer].last

    winner = if human_move.beats? computer_move    then :human
             elsif computer_move.beats? human_move then :computer
             else                                       :tie
             end
    @moves[:winner] << winner
  end

  def update_score
    winner = moves[:winner].last
    score[winner] += 1 unless winner == :tie
  end

  def round_results_string
    human_move = moves[:human].last
    computer_move = moves[:computer].last

    case moves[:winner].last
    when :human    then "#{human_move} > #{computer_move}"
    when :computer then "#{human_move} < #{computer_move}"
    when :tie      then "#{human_move} = #{computer_move}"
    end
  end

  def update_history_display
    @full_history_display << round_results_string
  end

  def full_history_display
    @full_history_display.join("\n")
  end

  def abbrev_history_display
    @full_history_display.last(5).join("\n")
  end
end

class Stats
  attr_reader :log
  def initialize(log)
    @log = log
  end

  def calculate_move_frequency(player)
    move_count = Hash.new

    Move::OPTIONS.values.each do |move|
      move_count[move] = log.moves[player].map(&:value).count(move)
    end

    move_count
  end

  def calculate_move_results(player)
    player_move_results = log.moves[player].map(&:value).zip(log.moves[:winner])
    win_count = Hash.new(0)
    loss_count = Hash.new(0)

    player_move_results.each do |move, winner|
      win_count[move] += 1 if winner == player
      loss_count[move] += 1 unless [player, :tie].include?(winner)
    end

    [win_count, loss_count]
  end

  def calculate_result_percentages(player)
    win_count, loss_count = calculate_move_results(player)
    total_move_count = calculate_move_frequency(player)
    result_percentages = Hash.new

    total_move_count.each do |move, total_count|
      if total_count.zero?
        result_percentages[move] = { win: 0, loss: 0 }
      else
        result_percentages[move] = { win: win_count[move].to_f / total_count,
                                     loss: loss_count[move].to_f / total_count }
      end
    end

    result_percentages
  end

  def move_sequences_by_length(player)
    human_moves = log.moves[player].map(&:value)
    move_count = log.moves[player].size
    (0...human_moves.size).to_a
                          .combination(2)
                          .select { |idx1, idx2| idx1 < idx2 }
                          .each_with_object([]) do |(idx1, idx2), move_sequences|
                            move_sequences << human_moves[idx1..idx2]
                          end.sort_by(&:length).reverse
  end


  def move_sequences_by_frequency(player)
    return [] if log.moves[player].empty?
    log.moves[player]
       .map(&:value)
       .each_cons(2)
       .each_with_object(Hash.new { |h, k| h[k] = 0} ) { |seq, count| count[seq] += 1 }
       .sort_by { |_, count| }
       .reverse
       .map { |moves, _| moves }
  end
end

module Displayable
  MENU_OPTIONS = <<~END_MSG
    'h' => show full moves history
    's' => show move stats
    'r' => reveal computer strategy
    'n' => start new game
    'q' => quit
    END_MSG
                 .freeze

  def welcome
    system 'clear'
    puts "Welcome to Rock, Paper, Scissors!"
  end

  def display_menu_options
    puts "Press enter to exit the menu or..."
    puts MENU_OPTIONS
  end

  def display_score
    puts "You : #{log.score[:human]} | "\
         "#{computer} : #{log.score[:computer]}"
    puts
  end

  def display_log
    display_score
    puts log.abbrev_history_display
    puts
  end

  def display_moves
    puts "\nYou chose #{human.move}...#{computer} chose #{computer.move}"
  end

  def display_full_history
    system 'clear'
    display_score
    puts log.full_history_display
    puts
  end

  def display_stats
    system 'clear'
    display_score
    puts "\n" + "Your stats:".center(25)
    display_stat_table(:human)
    puts "\n" + "#{computer}'s stats:".center(25)
    display_stat_table(:computer)
    puts
  end

  def display_stat_table(player)
    puts "Moves:".ljust(12) + "# (win%/loss%)"
    Move::OPTIONS.values.each do |move|
      display_move_stats(player, move)
    end
  end

  def display_move_stats(player, move)
    move_frequency = stats.calculate_move_frequency(player)[move]

    win_rate = stats.calculate_result_percentages(player)[move][:win]
    win_percentage = (win_rate * 100).round

    loss_rate = stats.calculate_result_percentages(player)[move][:loss]
    loss_percentage = (loss_rate * 100).round

    puts "#{move.ljust(8)} => #{move_frequency} "\
         "(#{win_percentage}% / #{loss_percentage}%)"
  end

  def reveal_computer_strategy
    system 'clear'
    puts "Name: #{computer.name}"
    puts "\nStrategy:"
    computer.reveal_strategy
    puts
  end

  def display_winner
    case log.moves[:winner].last
    when :human then puts "You won the round!"
    when :computer then puts "#{computer} won the round!"
    when :tie then puts "It's a tie!"
    end
  end

  def display_game_results
    display_log
    display_moves
    display_winner
  end
end

class RPSGame
  include Displayable

  attr_accessor :human, :computer, :log, :stats
  def initialize
    @log = Log.new
    @stats = Stats.new(log)
    @human = Human.new
    welcome
    @computer = choose_opponent.new(log, stats)
  end

  def new_game
    self.class.new.play
  end

  def choose_opponent
    puts "\nChoose your robot opponent.  Enter..."
    opponent_choice = ''
    loop do
      puts "1 => BestRobot\n2 => Beep.Bop.Robot\n3 => Sonny\n4 => R2D2"\
           "\n5 => C3PO\n6 => Awesome-O\n? => Random-O"
      answer = gets.chomp
      opponent_choice = register_opponent(answer)
      break unless opponent_choice == :invalid
      puts "Invalid entry.  Please choose from the following:"
    end

    opponent_choice
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def register_opponent(answer)
    case answer
    when '1' then BestRobot
    when '2' then BeepBopRobot
    when '3' then Sonny
    when '4' then R2D2
    when '5' then C3PO
    when '6' then AwesomeO
    when '?' then RandomO
    else          :invalid
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def main_menu
    loop do
      display_menu_options
      answer = gets.chomp.downcase
      case answer[0]
      when 'h' then display_full_history
      when 's' then display_stats
      when 'r' then reveal_computer_strategy
      when 'n' then new_game
      when 'q' then puts "Thanks for playing!"
                    exit
      else break
      end
    end
  end

  def player_continues
    puts "\nPress enter to continue or 'm' for main menu"
    answer = gets.chomp.downcase
    if answer.start_with?('m')
      system 'clear'
      main_menu
    end

    system 'clear'
  end

  def play
    loop do
      player_continues
      display_log
      computer.choose
      human.choose
      display_moves
      log.update(human.move, computer.move)
      display_winner
    end
  end
end

RPSGame.new.play
