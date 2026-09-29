require_relative "../piece"

module Chess
  class King < Piece
    DIRECTIONS = [
      [-1, 0], [1, 0], [0, -1], [0, 1],
      [-1, -1], [-1, 1], [1, -1], [1, 1]
    ].freeze

    HOME = { white: [7, 4], black: [0, 4] }.freeze

    def candidates(board)
      step_moves(board, DIRECTIONS) + castling_moves(board)
    end

    def attacks(board)
      step_moves(board, DIRECTIONS)
    end

    private

    def castling_moves(board)
      return [] unless position == HOME[color]
      return [] if board.in_check?(color)

      moves = []
      moves << [row, 6] if can_castle_kingside?(board)
      moves << [row, 2] if can_castle_queenside?(board)
      moves
    end

    def can_castle_kingside?(board)
      board.can_castle?(color, :kingside) &&
        empty_columns?(board, 5, 6) &&
        rook_present?(board, 7) &&
        safe_square?(board, 5) &&
        safe_square?(board, 6)
    end

    def can_castle_queenside?(board)
      board.can_castle?(color, :queenside) &&
        empty_columns?(board, 1, 2, 3) &&
        rook_present?(board, 0) &&
        safe_square?(board, 3) &&
        safe_square?(board, 2)
    end

    def empty_columns?(board, *columns)
      columns.all? { |col| board[row, col].nil? }
    end

    def rook_present?(board, col)
      piece = board[row, col]
      piece&.type == :rook && piece.color == color
    end

    def safe_square?(board, col)
      !board.attacked?([row, col], board.opponent(color))
    end
  end
end
