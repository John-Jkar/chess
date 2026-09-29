require_relative "chess/version"
require_relative "chess/constants"
require_relative "chess/pieces/registry"
require_relative "chess/piece"
require_relative "chess/pieces/pawn"
require_relative "chess/pieces/rook"
require_relative "chess/pieces/knight"
require_relative "chess/pieces/bishop"
require_relative "chess/pieces/queen"
require_relative "chess/pieces/king"
require_relative "chess/board"
require_relative "chess/display"
require_relative "chess/game"
require_relative "chess/ai"

module Chess
  PIECE_CLASSES = {
    king: King,
    queen: Queen,
    rook: Rook,
    bishop: Bishop,
    knight: Knight,
    pawn: Pawn
  }.freeze

  def self.piece_class(type)
    PIECE_CLASSES[type]
  end
end
