require "json"

module Chess
  class Game
    class IllegalMove < StandardError; end

    attr_reader :board, :history

    def self.load(path)
      data = JSON.parse(File.read(path))
      game = new
      game.board.from_fen(data.fetch("fen"))
      game.history.concat(data.fetch("history", []).map do |entry|
        { from: entry.fetch("from"), to: entry.fetch("to") }
      end)
      game
    end

    def initialize(board = Board.new, ai: nil)
      @board = board
      @history = []
      @ai = ai
    end

    def current_color
      board.active_color
    end

    def play_move(from_name, to_name, promotion: :queen)
      from = board.parse_square(from_name)
      to = board.parse_square(to_name)
      raise IllegalMove, "bad square" if from.nil? || to.nil?

      piece = board[*from]
      raise IllegalMove, "no piece on #{from_name}" if piece.nil?
      raise IllegalMove, "that is not your piece" unless piece.color == current_color

      legal = board.legal_targets(from)
      raise IllegalMove, "illegal move" unless legal.include?(to)

      apply(from, to, promotion)
      board.switch_turn
      history << { from: from, to: to }
      self
    end

    def over?
      checkmate? || stalemate?
    end

    def checkmate?
      board.checkmate?(current_color)
    end

    def stalemate?
      board.stalemate?(current_color)
    end

    def in_check?
      board.in_check?(current_color)
    end

    def result
      return "checkmate" if checkmate?
      return "stalemate" if stalemate?

      "in progress"
    end

    def status
      return "#{winner} wins by checkmate." if checkmate?
      return "Draw by stalemate." if stalemate?
      return "#{current_color} is in check." if in_check?

      "#{current_color} to move."
    end

    def to_h
      {
        fen: board.to_fen,
        history: history.map { |entry| { from: entry[:from], to: entry[:to] } }
      }
    end

    def save(path)
      File.write(path, JSON.pretty_generate(to_h))
      path
    end

    def load(path)
      loaded = self.class.load(path)
      @board = loaded.board
      @history = loaded.history
      self
    end

    HELP = <<~TEXT.freeze
      Commands:
        e2 e4        make a move (e2e4 also works)
        e7 e8 q      promote a pawn (q, r, b, or n)
        board        redraw the board
        save <file>  save the game to a file
        load <file>  load a game from a file
        help         show this message
        quit         leave the game
    TEXT

    PROMOTIONS = { "q" => :queen, "r" => :rook, "b" => :bishop, "n" => :knight }.freeze

    def play(input: $stdin, output: $stdout, display: Display.new)
      refresh(output, display)

      until over?
        output.puts status

        if ai_turn?
          output.puts play_ai_turn
          refresh(output, display)
          next
        end

        output.print "#{current_color}> "
        line = read_line(input)
        break if line.nil?

        line = line.strip
        break if %w[quit exit].include?(line.downcase)

        output.puts handle(line, display)
        refresh(output, display)
      end

      output.puts status
    end

    def handle(line, display = Display.new)
      return HELP if line.empty? || %w[help ?].include?(line.downcase)
      return display.render(board) if line.casecmp("board").zero?
      return save_message(Regexp.last_match(1)) if line =~ /\Asave\s+(\S+)\z/i
      return load_message(Regexp.last_match(1)) if line =~ /\Aload\s+(\S+)\z/i

      from, to, promotion = parse_move(line)
      return "I did not understand '#{line}'." if from.nil?

      play_move(from, to, promotion: promotion)
      "ok"
    rescue IllegalMove => e
      "Illegal move: #{e.message}"
    end

    private

    def read_line(input)
      input.gets
    rescue Interrupt
      nil
    end

    def refresh(output, display)
      output.print display.clear_screen if output.respond_to?(:tty?) && output.tty?
      output.puts display.render(board)
    end

    def ai_turn?
      !@ai.nil? && @ai.color == current_color
    end

    def play_ai_turn
      move = @ai.move(board)
      from = board.square_name(move[:from])
      to = board.square_name(move[:to])
      play_move(from, to, promotion: move[:promotion])
      "#{@ai.color} plays #{from}-#{to}."
    end

    def parse_move(line)
      tokens = line.downcase.split(/\s+/)

      if tokens.length == 1 && tokens[0].match?(/\A[a-h][1-8][a-h][1-8][qrbn]?\z/)
        text = tokens[0]
        [text[0, 2], text[2, 2], PROMOTIONS.fetch(text[4], :queen)]
      elsif tokens.length >= 2 && tokens[0].match?(/\A[a-h][1-8]\z/) && tokens[1].match?(/\A[a-h][1-8]\z/)
        [tokens[0], tokens[1], PROMOTIONS.fetch(tokens[2], :queen)]
      end
    end

    def save_message(path)
      save(path)
      "Saved to #{path}."
    end

    def load_message(path)
      load(path)
      "Loaded #{path}."
    end

    def winner
      current_color == :white ? "Black" : "White"
    end

    def apply(from, to, promotion)
      board.move_piece(from, to)

      piece = board[*to]
      promote(piece, promotion) if piece.is_a?(Pawn) && piece.promotion?
    end

    def promote(pawn, type)
      raise IllegalMove, "cannot promote to #{type}" unless Pawn::PROMOTION_TYPES.include?(type)

      replacement = Chess.piece_class(type).new(pawn.color, pawn.position)
      row, col = pawn.position
      board[row, col] = replacement
    end
  end
end
