module Chess
  class Piece
    attr_accessor :position
    attr_reader :color

    def initialize(color, position = [0, 0])
      @color = color
      @position = position
    end

    def initialize_copy(other)
      super
      @position = other.position.dup
    end

    def row
      position[0]
    end

    def col
      position[1]
    end

    def type
      self.class.name.split("::").last.downcase.to_sym
    end

    def to_s
      Chess::PIECES[color][type]
    end

    def to_h
      { type: type, color: color, row: row, col: col }
    end

    def ==(other)
      other.is_a?(self.class) && other.color == color && other.position == position
    end

    def moves(board)
      candidates(board).reject { |target| friendly_at?(board, target) }
    end

    def attacks(board)
      candidates(board)
    end

    def can_move_to?(board, target)
      moves(board).include?(target)
    end

    def candidates(_board)
      []
    end

    protected

    def friendly_at?(board, target)
      piece = board[target[0], target[1]]
      !piece.nil? && piece.color == color
    end

    def enemy_at?(board, target)
      piece = board[target[0], target[1]]
      !piece.nil? && piece.color != color
    end

    def empty_at?(board, target)
      board[target[0], target[1]].nil?
    end

    def step_moves(board, offsets)
      offsets.filter_map do |row_offset, col_offset|
        target = [row + row_offset, col + col_offset]
        target if board.valid_position?(target[0], target[1])
      end
    end

    def slide_moves(board, directions)
      directions.flat_map { |row_offset, col_offset| slide(board, row_offset, col_offset) }
    end

    def slide(board, row_offset, col_offset)
      targets = []
      current_row = row + row_offset
      current_col = col + col_offset

      while board.valid_position?(current_row, current_col)
        target = [current_row, current_col]
        targets << target
        break unless board[current_row, current_col].nil?

        current_row += row_offset
        current_col += col_offset
      end

      targets
    end
  end
end
