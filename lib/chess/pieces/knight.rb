require_relative "../piece"

module Chess
  class Knight < Piece
    OFFSETS = [
      [-2, -1], [-2, 1],
      [-1, -2], [-1, 2],
      [1, -2], [1, 2],
      [2, -1], [2, 1]
    ].freeze

    def candidates(board)
      step_moves(board, OFFSETS)
    end
  end
end
