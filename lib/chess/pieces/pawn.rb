require_relative "../piece"

module Chess
  class Pawn < Piece
    START_ROW = { white: 6, black: 1 }.freeze
    PROMOTION_ROW = { white: 0, black: 7 }.freeze
    PROMOTION_TYPES = %i[queen rook bishop knight].freeze

    def candidates(board)
      forward = color == :white ? -1 : 1
      advance(board, forward) + double_advance(board, forward) +
        captures(board, forward) + en_passant_moves(board, forward)
    end

    def promotion?
      PROMOTION_ROW[color] == row
    end

    def promotion_types
      PROMOTION_TYPES
    end

    def attacks(board)
      forward = color == :white ? -1 : 1
      [[forward, -1], [forward, 1]].filter_map do |row_offset, col_offset|
        target = [row + row_offset, col + col_offset]
        target if board.valid_position?(*target)
      end
    end

    private

    def advance(board, forward)
      target = [row + forward, col]
      empty_at?(board, target) ? [target] : []
    end

    def double_advance(board, forward)
      return [] unless row == START_ROW[color]

      one = [row + forward, col]
      two = [row + (forward * 2), col]
      return [] unless empty_at?(board, one) && empty_at?(board, two)

      [two]
    end

    def captures(board, forward)
      [[forward, -1], [forward, 1]].filter_map do |row_offset, col_offset|
        target = [row + row_offset, col + col_offset]
        target if board.valid_position?(*target) && enemy_at?(board, target)
      end
    end

    def en_passant_moves(board, forward)
      target = board.en_passant
      return [] unless target

      adjacent = [[row + forward, col - 1], [row + forward, col + 1]]
      adjacent.include?(target) ? [target] : []
    end
  end
end
