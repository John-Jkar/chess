require_relative "../piece"

module Chess
  class Queen < Piece
    DIRECTIONS = [
      [-1, 0], [1, 0], [0, -1], [0, 1],
      [-1, -1], [-1, 1], [1, -1], [1, 1]
    ].freeze

    def candidates(board)
      slide_moves(board, DIRECTIONS)
    end
  end
end
