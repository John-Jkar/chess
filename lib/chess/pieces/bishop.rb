require_relative "../piece"

module Chess
  class Bishop < Piece
    DIRECTIONS = [[-1, -1], [-1, 1], [1, -1], [1, 1]].freeze

    def candidates(board)
      slide_moves(board, DIRECTIONS)
    end
  end
end
