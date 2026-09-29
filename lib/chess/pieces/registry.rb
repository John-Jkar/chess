module Chess
  PIECE_TYPES = %i[king queen rook bishop knight pawn].freeze

  SYMBOL_TO_TYPE = {
    "k" => :king,
    "q" => :queen,
    "r" => :rook,
    "b" => :bishop,
    "n" => :knight,
    "p" => :pawn
  }.freeze
end
