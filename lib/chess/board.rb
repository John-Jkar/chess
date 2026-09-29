require_relative "constants"

module Chess
  class Board
    ROWS = 8
    COLS = 8

    BACK_RANK = %i[rook knight bishop queen king bishop knight rook].freeze

    CORNER_RIGHTS = {
      [7, 0] => "Q",
      [7, 7] => "K",
      [0, 0] => "q",
      [0, 7] => "k"
    }.freeze

    attr_reader :squares, :active_color, :en_passant, :halfmove_clock,
                :fullmove_number, :castling

    def initialize
      @squares = Array.new(ROWS) { Array.new(COLS) }
      @active_color = :white
      @en_passant = nil
      @halfmove_clock = 0
      @fullmove_number = 1
      @castling = "KQkq"
      setup_starting_position
    end

    def [](row, col)
      return nil unless valid_position?(row, col)

      @squares[row][col]
    end

    def []=(row, col, piece)
      raise ArgumentError, "off board: #{row},#{col}" unless valid_position?(row, col)

      @squares[row][col] = piece
    end

    def valid_position?(row, col)
      row.between?(0, ROWS - 1) && col.between?(0, COLS - 1)
    end

    def place(piece, position)
      row, col = position
      self[row, col] = piece
      piece.position = position
      piece
    end

    def move_piece(from, to)
      piece = self[*from]
      return nil if piece.nil?

      from_row, from_col = from
      to_row, to_col = to
      captured = self[to_row, to_col]

      if en_passant_capture?(piece, from, to, captured)
        captured = self[from_row, to_col]
        self[from_row, to_col] = nil
      end

      self[to_row, to_col] = piece
      self[from_row, from_col] = nil
      piece.position = to

      move_castling_rook(from, to) if castling_move?(piece, from, to)
      revoke_castling_for_move(piece, from)
      revoke_castling_for_corner(to) if captured&.type == :rook

      update_en_passant(piece, from, to)
      update_clocks(piece, captured)
      captured
    end

    def active_color=(color)
      raise ArgumentError, "bad color: #{color}" unless COLORS.include?(color)

      @active_color = color
    end

    def switch_turn
      @active_color = opponent(@active_color)
    end

    def can_castle?(color, side)
      rights = color == :white ? "KQ" : "kq"
      char = side == :kingside ? rights[0] : rights[1]
      @castling.include?(char)
    end

    def deep_dup
      copy = self.class.allocate
      copy.instance_variable_set(:@squares, @squares.map { |row| row.map { |piece| piece&.dup } })
      copy.instance_variable_set(:@active_color, @active_color)
      copy.instance_variable_set(:@en_passant, @en_passant&.dup)
      copy.instance_variable_set(:@halfmove_clock, @halfmove_clock)
      copy.instance_variable_set(:@fullmove_number, @fullmove_number)
      copy.instance_variable_set(:@castling, @castling.dup)
      copy
    end

    def pieces
      @squares.flatten.compact
    end

    def pieces_for(color)
      pieces.select { |piece| piece.color == color }
    end

    def opponent(color)
      color == :white ? :black : :white
    end

    def king_position(color)
      king = find_piece(:king, color)
      king&.position
    end

    def attacked?(target, by_color)
      return false if target.nil?

      pieces_for(by_color).any? { |piece| piece.attacks(self).include?(target) }
    end

    def in_check?(color)
      position = king_position(color)
      position && attacked?(position, opponent(color))
    end

    def legal_moves(color = active_color)
      pieces_for(color).flat_map do |piece|
        piece.moves(self).filter_map do |target|
          [piece.position, target] if legal_move?(piece, target)
        end
      end
    end

    def legal_move?(piece, target)
      copy = deep_dup
      copy.move_piece(piece.position, target)
      !copy.in_check?(piece.color)
    end

    def checkmate?(color = active_color)
      in_check?(color) && legal_moves(color).empty?
    end

    def stalemate?(color = active_color)
      !in_check?(color) && legal_moves(color).empty?
    end

    def legal_targets(position)
      piece = self[position[0], position[1]]
      return [] if piece.nil?

      piece.moves(self).select { |target| legal_move?(piece, target) }
    end

    def find_piece(type, color)
      pieces.find { |piece| piece.type == type && piece.color == color }
    end

    def clear
      @squares = Array.new(ROWS) { Array.new(COLS) }
      self
    end

    def each_position
      return to_enum(:each_position) unless block_given?

      ROWS.times do |row|
        COLS.times { |col| yield [row, col] }
      end
    end

    def each_piece(&block)
      return to_enum(:each_piece) unless block_given?

      @squares.flatten.compact.each(&block)
    end

    def to_fen
      [
        placement_to_fen,
        @active_color == :white ? "w" : "b",
        @castling.empty? ? "-" : @castling,
        @en_passant ? square_name(@en_passant) : "-",
        @halfmove_clock.to_s,
        @fullmove_number.to_s
      ].join(" ")
    end

    def from_fen(fen)
      placement, active, castling, ep, halfmove, fullmove = fen.strip.split(/\s+/)

      clear
      parse_placement(placement)

      @active_color = active == "b" ? :black : :white
      @castling = castling == "-" ? "" : castling
      @en_passant = ep == "-" ? nil : parse_square(ep)
      @halfmove_clock = halfmove.to_i
      @fullmove_number = fullmove.to_i
      self
    end

    def square_name(position)
      row, col = position
      return nil unless valid_position?(row, col)

      "#{Chess::FILES[col]}#{8 - row}"
    end

    def parse_square(name)
      return nil unless name.to_s.match?(/\A[a-h][1-8]\z/)

      [8 - name[1].to_i, Chess::FILES.index(name[0])]
    end

    def color_at(row, col)
      piece = self[row, col]
      piece&.color
    end

    def to_h
      { squares: squares.map { |row| row.map { |p| p&.to_h } } }
    end

    private

    def setup_starting_position
      BACK_RANK.each_with_index do |type, col|
        place(Chess.piece_class(type).new(:black), [0, col])
        place(Chess.piece_class(type).new(:white), [7, col])
      end

      COLS.times do |col|
        place(Chess.piece_class(:pawn).new(:black), [1, col])
        place(Chess.piece_class(:pawn).new(:white), [6, col])
      end
    end

    def en_passant_capture?(piece, from, to, captured)
      piece.type == :pawn &&
        captured.nil? &&
        from[1] != to[1] &&
        @en_passant == to
    end

    def castling_move?(piece, from, to)
      piece.type == :king && (to[1] - from[1]).abs == 2
    end

    def move_castling_rook(from, to)
      row = from[0]
      rook_col = to[1] > from[1] ? 7 : 0
      rook_target_col = to[1] > from[1] ? 5 : 3
      rook = self[row, rook_col]
      return if rook.nil?

      self[row, rook_target_col] = rook
      self[row, rook_col] = nil
      rook.position = [row, rook_target_col]
    end

    def revoke_castling_for_move(piece, from)
      case piece.type
      when :king
        rights = piece.color == :white ? "KQ" : "kq"
        @castling = @castling.delete(rights)
      when :rook
        revoke_castling_for_corner(from)
      end
    end

    def revoke_castling_for_corner(position)
      char = CORNER_RIGHTS[position]
      @castling = @castling.delete(char) if char
    end

    def update_en_passant(piece, from, to)
      @en_passant = ([(from[0] + to[0]) / 2, from[1]] if piece.type == :pawn && (to[0] - from[0]).abs == 2)
    end

    def update_clocks(piece, captured)
      @halfmove_clock = piece.type == :pawn || captured ? 0 : @halfmove_clock + 1
      @fullmove_number += 1 if piece.color == :black
    end

    def placement_to_fen
      @squares.map { |row| row_to_fen(row) }.join("/")
    end

    def row_to_fen(row)
      result = +""
      empty = 0

      row.each do |piece|
        if piece
          result << empty.to_s if empty.positive?
          empty = 0
          result << fen_symbol(piece)
        else
          empty += 1
        end
      end

      result << empty.to_s if empty.positive?
      result
    end

    def fen_symbol(piece)
      symbol = Chess::SYMBOL_TO_TYPE.key(piece.type)
      piece.color == :white ? symbol.upcase : symbol
    end

    def parse_placement(placement)
      rows = placement.split("/")
      raise ArgumentError, "FEN needs 8 ranks, got #{rows.length}" unless rows.length == ROWS

      rows.each_with_index do |row_string, row|
        col = 0
        row_string.each_char do |char|
          if char.match?(/\d/)
            col += char.to_i
          else
            raise ArgumentError, "unknown piece '#{char}'" unless Chess::SYMBOL_TO_TYPE.key?(char.downcase)

            color = char == char.upcase ? :white : :black
            type = Chess::SYMBOL_TO_TYPE[char.downcase]
            place(Chess.piece_class(type).new(color), [row, col])
            col += 1
          end
        end
        raise ArgumentError, "rank #{8 - row} describes #{col} squares" unless col == COLS
      end
    end
  end
end
