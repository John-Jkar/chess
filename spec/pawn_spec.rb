require "chess"

RSpec.describe Chess::Pawn do
  let(:board) { Chess::Board.new }

  def moves_from(fen, square, color = :white)
    board.from_fen(fen)
    row, col = board.parse_square(square)
    pawn = board[row, col]
    raise "no pawn on #{square}" unless pawn&.type == :pawn && pawn.color == color

    pawn.moves(board).map { |pos| board.square_name(pos) }
  end

  describe "#moves" do
    it "advances one and two squares from the starting rank" do
      expect(moves_from("4k3/8/8/8/8/8/4P3/4K3 w - - 0 1", "e2"))
        .to contain_exactly("e3", "e4")
    end

    it "advances only one square from a later rank" do
      expect(moves_from("4k3/8/8/4P3/8/8/8/4K3 w - - 0 1", "e5"))
        .to contain_exactly("e6")
    end

    it "cannot advance when blocked ahead" do
      expect(moves_from("4k3/8/8/8/8/4p3/4P3/4K3 w - - 0 1", "e2")).to be_empty
    end

    it "cannot capture straight ahead" do
      expect(moves_from("4k3/8/8/8/8/4p3/4P3/4K3 w - - 0 1", "e2")).to be_empty
    end

    it "cannot jump over a piece to reach the double step" do
      expect(moves_from("4k3/8/8/8/4p3/8/4P3/4K3 w - - 0 1", "e2"))
        .to contain_exactly("e3")
    end

    it "captures one square diagonally" do
      expect(moves_from("4k3/8/8/8/8/3p4/4P3/4K3 w - - 0 1", "e2"))
        .to contain_exactly("d3", "e3", "e4")
    end

    it "captures on both diagonals" do
      expect(moves_from("4k3/8/8/8/8/3p1p2/4P3/4K3 w - - 0 1", "e2"))
        .to contain_exactly("d3", "e3", "e4", "f3")
    end

    it "cannot move diagonally into an empty square" do
      expect(moves_from("4k3/8/8/8/8/8/4P3/4K3 w - - 0 1", "e2"))
        .not_to include("d3", "f3")
    end

    it "cannot capture a friendly piece diagonally" do
      expect(moves_from("4k3/8/8/8/8/8/1P1P4/4K3 w - - 0 1", "d2"))
        .to contain_exactly("d3", "d4")
    end

    it "moves forward for black" do
      expect(moves_from("4k3/8/8/3p4/8/8/8/4K3 b - - 0 1", "d5", :black))
        .to contain_exactly("d4")
    end

    it "advances two squares for black from rank 7" do
      expect(moves_from("4k3/3p4/8/8/8/8/8/4K3 b - - 0 1", "d7", :black))
        .to contain_exactly("d6", "d5")
    end

    it "captures diagonally for black" do
      expect(moves_from("4k3/8/8/8/2p5/1P1P4/8/4K3 b - - 0 1", "c4", :black))
        .to contain_exactly("b3", "c3", "d3")
    end
  end

  describe "#promotion?" do
    it "is true on the last rank" do
      board.from_fen("4P2k/8/8/8/8/8/8/4K3 w - - 0 1")
      expect(board[0, 4].promotion?).to be true
    end

    it "is false on the second rank" do
      board.from_fen("4k3/8/8/8/8/8/4P3/4K3 w - - 0 1")
      expect(board[6, 4].promotion?).to be false
    end
  end

  describe "#promotion_types" do
    it "offers the four standard choices" do
      board.from_fen("4P2k/8/8/8/8/8/8/4K3 w - - 0 1")
      expect(board[0, 4].promotion_types).to contain_exactly(:queen, :rook, :bishop, :knight)
    end
  end
end
