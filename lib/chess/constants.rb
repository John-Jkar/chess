module Chess
  COLORS = %i[white black].freeze

  FILES = ("a".."h").to_a.freeze

  PIECES = {
    black: { king: "♚", queen: "♛", rook: "♜", bishop: "♝", knight: "♞", pawn: "♟" },
    white: { king: "♔", queen: "♕", rook: "♖", bishop: "♗", knight: "♘", pawn: "♙" }
  }.freeze
end
