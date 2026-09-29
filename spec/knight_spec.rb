require "chess"

RSpec.describe Chess::Knight do
  let(:board) { Chess::Board.new }

  def moves_from(fen, color)
    board.from_fen(fen)
    knight = board.find_piece(:knight, color)
    knight.moves(board).map { |pos| board.square_name(pos) }
  end

  describe "#moves" do
    it "has eight moves from the center" do
      board.clear
      board.place(described_class.new(:white), [3, 3])
      expect(board.pieces.first.moves(board).length).to eq(8)
    end

    it "returns the L-shaped offsets from b1" do
      expect(moves_from("4k3/8/8/8/8/8/8/1N2K3 w - - 0 1", :white))
        .to contain_exactly("a3", "c3", "d2")
    end

    it "returns only two moves from a corner" do
      expect(moves_from("N3k3/8/8/8/8/8/8/4K3 w - - 0 1", :white))
        .to contain_exactly("b6", "c7")
    end

    it "jumps over pieces" do
      expect(moves_from("4k3/8/8/8/8/8/4P3/4K2N w - - 0 1", :white))
        .to contain_exactly("f2", "g3")
    end

    it "can capture an enemy piece" do
      expect(moves_from("4k3/8/8/8/8/5n2/8/4K2N w - - 0 1", :white))
        .to contain_exactly("f2", "g3")
    end

    it "cannot land on a friendly piece" do
      names = moves_from("4k3/8/8/8/8/6P1/8/4K2N w - - 0 1", :white)
      expect(names).not_to include("g3")
      expect(names).to include("f2")
    end

    it "has the same moves for black" do
      expect(moves_from("4k2n/8/8/8/8/8/8/4K3 w - - 0 1", :black))
        .to contain_exactly("f7", "g6")
    end
  end
end
