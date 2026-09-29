require "chess"

RSpec.describe Chess::Rook do
  let(:board) { Chess::Board.new }

  def names_for(fen)
    board.from_fen(fen)
    rook = board.pieces_for(:white).find { |p| p.type == :rook }
    rook.moves(board).map { |pos| board.square_name(pos) }
  end

  describe "#moves" do
    it "slides along ranks and files" do
      expect(names_for("4k3/8/8/8/8/8/8/R3K3 w - - 0 1"))
        .to contain_exactly("a2", "a3", "a4", "a5", "a6", "a7", "a8", "b1", "c1", "d1")
    end

    it "slides the full length of an open rank" do
      expect(names_for("4k3/8/8/8/8/8/8/R6K w - - 0 1"))
        .to contain_exactly("b1", "c1", "d1", "e1", "f1", "g1", "a2", "a3", "a4", "a5", "a6", "a7", "a8")
    end

    it "stops at a blocking piece and cannot capture it" do
      names = names_for("4k3/8/8/8/8/8/8/RP1K4 w - - 0 1")
      expect(names).not_to include("b1", "c1", "d1")
      expect(names).to include("a2", "a3")
    end

    it "can capture an enemy piece" do
      names = names_for("4k3/8/8/8/8/8/8/Rp1K4 w - - 0 1")
      expect(names).to include("b1")
      expect(names).not_to include("c1", "d1")
    end

    it "has no diagonal moves" do
      names = names_for("4k3/8/8/8/8/8/8/R3K3 w - - 0 1")
      expect(names).not_to include("b2", "b3")
    end

    it "works for black" do
      board.from_fen("r3k3/8/8/8/8/8/8/4K3 w - - 0 1")
      rook = board.pieces_for(:black).find { |p| p.type == :rook }
      names = rook.moves(board).map { |pos| board.square_name(pos) }
      expect(names).to include("a7", "a6", "b8", "c8", "d8")
    end
  end
end

RSpec.describe Chess::Bishop do
  let(:board) { Chess::Board.new }

  def names_for(fen)
    board.from_fen(fen)
    bishop = board.pieces_for(:white).find { |p| p.type == :bishop }
    bishop.moves(board).map { |pos| board.square_name(pos) }
  end

  describe "#moves" do
    it "slides on diagonals" do
      expect(names_for("4k3/8/8/8/8/8/8/B3K3 w - - 0 1"))
        .to contain_exactly("b2", "c3", "d4", "e5", "f6", "g7", "h8")
    end

    it "has no orthogonal moves" do
      names = names_for("4k3/8/8/8/8/8/8/B3K3 w - - 0 1")
      expect(names).not_to include("a2", "a4", "b1")
    end

    it "stops at a blocking piece" do
      names = names_for("4k3/8/8/4P3/8/8/8/B3K3 w - - 0 1")
      expect(names).to include("b2", "c3", "d4")
      expect(names).not_to include("e5", "f6", "g7", "h8")
    end

    it "can capture an enemy piece" do
      names = names_for("4k3/8/8/4p3/8/8/8/B3K3 w - - 0 1")
      expect(names).to include("e5")
      expect(names).not_to include("f6", "g7", "h8")
    end

    it "never leaves the color of square it started on" do
      names = names_for("4k3/8/8/4p3/8/8/8/B3K3 w - - 0 1")
      starting_color = (7 + 0).even? ? :dark : :light
      names.each do |name|
        row, col = Chess::Board.new.parse_square(name)
        expect((row + col).even? ? :dark : :light).to eq(starting_color)
      end
    end
  end
end

RSpec.describe Chess::Queen do
  let(:board) { Chess::Board.new }

  def names_for(fen)
    board.from_fen(fen)
    queen = board.pieces_for(:white).find { |p| p.type == :queen }
    queen.moves(board).map { |pos| board.square_name(pos) }
  end

  describe "#moves" do
    it "combines rook and bishop moves" do
      names = names_for("4k3/8/8/8/8/8/8/Q3K3 w - - 0 1")
      expect(names).to include("a2", "a3", "b1", "c1", "d1", "b2", "c3", "d4")
    end

    it "has 27 squares available on an open board" do
      expect(names_for("5k2/8/8/8/3Q4/8/8/2K5 w - - 0 1").length).to eq(27)
    end
  end
end

RSpec.describe Chess::King do
  let(:board) { Chess::Board.new }

  def names_for(fen)
    board.from_fen(fen)
    king = board.pieces_for(:white).find { |p| p.type == :king }
    king.moves(board).map { |pos| board.square_name(pos) }
  end

  describe "#moves" do
    it "steps one square in any direction" do
      expect(names_for("8/8/8/8/8/3K4/8/7k w - - 0 1"))
        .to contain_exactly("c2", "c3", "c4", "d2", "d4", "e2", "e3", "e4")
    end

    it "has fewer moves in a corner" do
      expect(names_for("8/8/8/8/8/8/8/K6k w - - 0 1"))
        .to contain_exactly("a2", "b1", "b2")
    end

    it "cannot step onto a friendly piece" do
      names = names_for("8/8/8/8/8/8/1P6/K6k w - - 0 1")
      expect(names).not_to include("b2")
      expect(names).to include("a2", "b1")
    end
  end
end
