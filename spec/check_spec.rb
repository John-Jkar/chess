require "chess"

RSpec.describe "check and legal moves" do
  let(:board) { Chess::Board.new }

  def load(fen)
    board.from_fen(fen)
    board
  end

  describe "#in_check?" do
    it "detects a rook checking along a file" do
      load("4k3/8/8/8/8/8/8/4R2K b - - 0 1")
      expect(board.in_check?(:black)).to be true
      expect(board.in_check?(:white)).to be false
    end

    it "detects a bishop checking on a diagonal" do
      load("7k/8/8/8/8/8/8/B3K3 b - - 0 1")
      expect(board.in_check?(:black)).to be true
    end

    it "detects a knight check" do
      load("8/8/8/4k3/8/5N2/8/4K3 b - - 0 1")
      expect(board.in_check?(:black)).to be true
    end

    it "detects a pawn check" do
      load("3k4/4P3/8/8/8/8/8/4K3 b - - 0 1")
      expect(board.in_check?(:black)).to be true
    end

    it "is false when no attacker reaches the king" do
      load("4k3/8/8/8/8/8/8/4K3 w - - 0 1")
      expect(board.in_check?(:black)).to be false
      expect(board.in_check?(:white)).to be false
    end

    it "is blocked by a piece in the way" do
      load("4k3/8/8/8/8/8/4N3/4R2K b - - 0 1")
      expect(board.in_check?(:black)).to be false
    end

    it "does not count a pawn's forward square as attacked" do
      load("4k3/8/8/3p4/8/8/8/4K3 w - - 0 1")
      expect(board.attacked?([4, 3], :black)).to be false
      expect(board.attacked?([4, 2], :black)).to be true
      expect(board.attacked?([4, 4], :black)).to be true
    end
  end

  describe "#legal_moves" do
    it "does not let a pinned piece move off the pin line" do
      load("4k3/4r3/8/8/8/8/8/4K3 w - - 0 1")
      targets = board.legal_targets(board.king_position(:white))
      names = targets.map { |target| board.square_name(target) }
      expect(names).to contain_exactly("d1", "d2", "f1", "f2")
    end

    it "does not let the king step back onto the checking line" do
      load("3r2k1/8/8/8/8/8/8/3K4 w - - 0 1")
      targets = board.legal_targets(board.king_position(:white))
      names = targets.map { |target| board.square_name(target) }
      expect(names).to contain_exactly("c1", "c2", "e1", "e2")
    end

    it "returns no targets for an empty square" do
      load("4k3/8/8/8/8/8/8/4K3 w - - 0 1")
      expect(board.legal_targets([4, 4])).to be_empty
    end
  end

  describe "#checkmate?" do
    it "detects the fool's mate" do
      load("rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3")
      expect(board.in_check?(:white)).to be true
      expect(board.checkmate?(:white)).to be true
    end

    it "detects the scholar's mate" do
      load("r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4")
      expect(board.checkmate?(:black)).to be true
    end

    it "is false when the king can escape" do
      load("4k3/8/8/8/8/8/8/4R2K b - - 0 1")
      expect(board.checkmate?(:black)).to be false
    end

    it "is false when not in check" do
      load("4k3/8/8/8/8/8/8/4K3 w - - 0 1")
      expect(board.checkmate?(:white)).to be false
    end
  end

  describe "#stalemate?" do
    it "detects a corner stalemate" do
      load("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
      expect(board.in_check?(:black)).to be false
      expect(board.legal_moves(:black)).to be_empty
      expect(board.stalemate?(:black)).to be true
    end

    it "is false when the side to move has a legal move" do
      load("7k/5Q2/6K1/8/8/8/8/8 w - - 0 1")
      expect(board.stalemate?(:white)).to be false
    end

    it "is false when the side to move is in check" do
      load("rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3")
      expect(board.stalemate?(:white)).to be false
    end
  end
end
