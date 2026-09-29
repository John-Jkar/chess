require "chess"

RSpec.describe "castling and en passant" do
  let(:board) { Chess::Board.new }

  def load(fen)
    board.from_fen(fen)
    board
  end

  describe "castling" do
    let(:open_board) { "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1" }

    it "allows both sides when the path is clear" do
      load(open_board)
      targets = board.legal_targets(board.king_position(:white))
      names = targets.map { |t| board.square_name(t) }
      expect(names).to include("g1", "c1")
    end

    it "is blocked by a piece between king and rook" do
      load("r3k2r/8/8/8/8/8/8/R3KB1R w KQkq - 0 1")
      names = board.legal_targets(board.king_position(:white)).map { |t| board.square_name(t) }
      expect(names).not_to include("g1")
      expect(names).to include("c1")
    end

    it "is illegal while in check" do
      load("r3k2r/8/8/8/8/8/4r3/R3K2R w KQkq - 0 1")
      names = board.legal_targets(board.king_position(:white)).map { |t| board.square_name(t) }
      expect(names).not_to include("g1", "c1")
    end

    it "is illegal when the king would pass through an attacked square" do
      load("r3k1r1/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
      names = board.legal_targets(board.king_position(:white)).map { |t| board.square_name(t) }
      expect(names).not_to include("g1")
    end

    it "is illegal when the destination is attacked" do
      load("r3k1rk/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
      names = board.legal_targets(board.king_position(:white)).map { |t| board.square_name(t) }
      expect(names).not_to include("g1")
    end

    it "moves the rook as well as the king" do
      load(open_board)
      board.move_piece([7, 4], [7, 6])
      expect(board[7, 6].type).to eq(:king)
      expect(board[7, 5].type).to eq(:rook)
      expect(board[7, 7]).to be_nil
    end

    it "moves the rook correctly for queenside" do
      load(open_board)
      board.move_piece([7, 4], [7, 2])
      expect(board[7, 2].type).to eq(:king)
      expect(board[7, 3].type).to eq(:rook)
      expect(board[7, 0]).to be_nil
    end

    it "revokes rights once the king moves" do
      load(open_board)
      board.move_piece([7, 4], [6, 4])
      board.move_piece([6, 4], [7, 4])
      names = board.legal_targets(board.king_position(:white)).map { |t| board.square_name(t) }
      expect(names).not_to include("g1", "c1")
    end

    it "revokes rights once the rook moves" do
      load(open_board)
      board.move_piece([7, 7], [6, 7])
      names = board.legal_targets(board.king_position(:white)).map { |t| board.square_name(t) }
      expect(names).not_to include("g1")
      expect(names).to include("c1")
    end

    it "revokes rights when the rook is captured on its home square" do
      load("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
      board.move_piece([7, 7], [0, 7])
      expect(board.castling).not_to include("K")
    end

    it "respects the FEN castling field" do
      load("r3k2r/8/8/8/8/8/8/R3K2R w - - 0 1")
      names = board.legal_targets(board.king_position(:white)).map { |t| board.square_name(t) }
      expect(names).not_to include("g1", "c1")
    end

    it "lets black castle kingside" do
      load("r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1")
      names = board.legal_targets(board.king_position(:black)).map { |t| board.square_name(t) }
      expect(names).to include("g8", "c8")
    end
  end

  describe "en passant" do
    it "is offered to a pawn beside a double-stepping pawn" do
      load("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
      expect(board.legal_targets([3, 4]).map { |t| board.square_name(t) })
        .to include("d6")
    end

    it "removes the captured pawn from its own square" do
      load("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
      board.move_piece([3, 4], [2, 3])
      expect(board[2, 3].type).to eq(:pawn)
      expect(board[3, 3]).to be_nil
      expect(board[3, 4]).to be_nil
    end

    it "is only available immediately after the double step" do
      board.from_fen("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
      board.move_piece([3, 4], [2, 4])
      expect(board.en_passant).to be_nil
    end

    it "is not offered when the king is absent or the square is not set" do
      load("4k3/8/8/3pP3/8/8/8/4K3 w - - 0 1")
      expect(board.legal_targets([3, 4]).map { |t| board.square_name(t) })
        .not_to include("d6")
    end

    it "is legal for black as well" do
      load("4k3/8/8/8/3Pp3/8/8/4K3 b - d3 0 1")
      expect(board.legal_targets([4, 4]).map { |t| board.square_name(t) })
        .to include("d3")
    end

    it "is illegal when it would expose the king to a rook along the rank" do
      load("k7/8/8/r2pPK2/8/8/8/8 w - d6 0 1")
      expect(board.in_check?(:white)).to be false
      expect(board.legal_targets([3, 4]).map { |t| board.square_name(t) })
        .to contain_exactly("e6")
    end
  end
end
