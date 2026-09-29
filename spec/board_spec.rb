require "chess"

RSpec.describe Chess::Board do
  subject(:board) { described_class.new }

  describe "#initialize" do
    it "builds an 8x8 grid" do
      expect(board.squares.length).to eq(8)
      expect(board.squares.map(&:length).uniq).to eq([8])
    end

    it "places 32 pieces" do
      expect(board.pieces.length).to eq(32)
    end

    it "places white pieces on ranks 1 and 2" do
      white = board.pieces_for(:white)
      expect(white.length).to eq(16)
      expect(white.map(&:row).uniq.sort).to eq([6, 7])
    end

    it "places black pieces on ranks 7 and 8" do
      black = board.pieces_for(:black)
      expect(black.length).to eq(16)
      expect(black.map(&:row).uniq.sort).to eq([0, 1])
    end

    it "puts a rook in the a8 corner" do
      expect(board[0, 0].type).to eq(:rook)
      expect(board[0, 0].color).to eq(:black)
    end

    it "puts a king on e1" do
      king = board[7, 4]
      expect(king.type).to eq(:king)
      expect(king.color).to eq(:white)
    end
  end

  describe "#[]" do
    it "returns the piece at a position" do
      expect(board[7, 4].type).to eq(:king)
    end

    it "returns nil for an empty square" do
      expect(board[4, 4]).to be_nil
    end

    it "returns nil for an off-board position instead of raising" do
      expect(board[8, 0]).to be_nil
      expect(board[0, -1]).to be_nil
    end
  end

  describe "#[]=" do
    it "raises on an off-board position" do
      expect { board[9, 9] = nil }.to raise_error(ArgumentError)
    end
  end

  describe "#move_piece" do
    it "moves the piece and empties the origin" do
      board.move_piece([6, 4], [4, 4])
      expect(board[6, 4]).to be_nil
      expect(board[4, 4].color).to eq(:white)
      expect(board[4, 4].type).to eq(:pawn)
    end

    it "updates the piece position" do
      piece = board[6, 4]
      board.move_piece([6, 4], [4, 4])
      expect(piece.position).to eq([4, 4])
    end

    it "returns the captured piece" do
      board[3, 4] = Chess.piece_class(:pawn).new(:black, [3, 4])
      captured = board.move_piece([6, 4], [3, 4])
      expect(captured.color).to eq(:black)
    end

    it "returns nil when the origin is empty" do
      expect(board.move_piece([4, 4], [3, 4])).to be_nil
    end
  end

  describe "#find_piece" do
    it "finds the king of a given color" do
      expect(board.find_piece(:king, :white).position).to eq([7, 4])
      expect(board.find_piece(:king, :black).position).to eq([0, 4])
    end
  end

  describe "FEN" do
    it "serializes the starting position" do
      expect(board.to_fen).to eq("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    end

    it "round-trips the starting position" do
      original = board.to_fen
      described_class.new.from_fen(original)
      expect(board.to_fen).to eq(original)
    end

    it "builds a middlegame position from FEN" do
      fen = "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4"
      board.from_fen(fen)
      expect(board.pieces.length).to eq(32)
      expect(board[3, 4].color).to eq(:black)
      expect(board[2, 2].type).to eq(:knight)
    end

    it "handles empty rows in FEN" do
      board.from_fen("8/8/8/8/8/8/8/8 w - - 0 1")
      expect(board.pieces).to be_empty
    end

    it "round-trips a position with empty rows" do
      fen = "8/8/8/4k3/8/8/8/4K3 b - - 3 42"
      board.from_fen(fen)
      expect(board.to_fen).to eq(fen)
      expect(board.active_color).to eq(:black)
    end

    it "rejects a rank whose digits do not add up to 8" do
      expect { board.from_fen("4k3/8/8/8/8/8/3p1p3/4K3 w - - 0 1") }
        .to raise_error(ArgumentError, /9 squares/)
    end

    it "rejects the wrong number of ranks" do
      expect { board.from_fen("4k3/8/8 w - - 0 1") }
        .to raise_error(ArgumentError, /8 ranks/)
    end

    it "rejects an unknown piece letter" do
      expect { board.from_fen("4k3/8/8/8/8/8/8/3XK3 w - - 0 1") }
        .to raise_error(ArgumentError, /unknown piece/)
    end
  end

  describe "#square_name" do
    it "converts a position to algebraic notation" do
      expect(board.square_name([0, 0])).to eq("a8")
      expect(board.square_name([7, 4])).to eq("e1")
      expect(board.square_name([3, 3])).to eq("d5")
    end
  end

  describe "#parse_square" do
    it "converts algebraic notation to a position" do
      expect(board.parse_square("a8")).to eq([0, 0])
      expect(board.parse_square("e1")).to eq([7, 4])
      expect(board.parse_square("d5")).to eq([3, 3])
    end
  end
end
