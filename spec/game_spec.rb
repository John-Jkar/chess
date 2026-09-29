require "chess"
require "tmpdir"

RSpec.describe Chess::Game do
  subject(:game) { described_class.new }

  describe "#initialize" do
    it "starts with white to move" do
      expect(game.current_color).to eq(:white)
    end

    it "starts with an empty history" do
      expect(game.history).to be_empty
    end

    it "starts with a board in the initial position" do
      expect(game.board.pieces.length).to eq(32)
    end
  end

  describe "#play_move" do
    it "moves a piece and switches turns" do
      game.play_move("e2", "e4")
      expect(game.board[4, 4].type).to eq(:pawn)
      expect(game.current_color).to eq(:black)
    end

    it "accepts a legal reply" do
      game.play_move("e2", "e4")
      game.play_move("e7", "e5")
      expect(game.current_color).to eq(:white)
    end

    it "records each move in the history" do
      game.play_move("e2", "e4")
      expect(game.history.length).to eq(1)
      expect(game.history.first).to eq(from: [6, 4], to: [4, 4])
    end

    it "rejects moving from an empty square" do
      expect { game.play_move("e3", "e4") }
        .to raise_error(described_class::IllegalMove, /no piece/)
    end

    it "rejects moving the opponent's piece" do
      expect { game.play_move("e7", "e5") }
        .to raise_error(described_class::IllegalMove, /not your piece/)
    end

    it "rejects a move that is not in the piece's pattern" do
      expect { game.play_move("e2", "e5") }
        .to raise_error(described_class::IllegalMove, /illegal move/)
    end

    it "rejects a king moving onto an attacked square" do
      game.board.from_fen("3r2k1/8/8/8/8/8/8/3K4 w - - 0 1")
      expect { game.play_move("d1", "d2") }.to raise_error(described_class::IllegalMove)
    end

    it "rejects a move from a piece that is pinned" do
      game.board.from_fen("4k3/4r3/8/8/8/8/4B3/4K3 w - - 0 1")
      expect { game.play_move("e2", "d3") }.to raise_error(described_class::IllegalMove)
    end

    it "rejects a nonsensical square" do
      expect { game.play_move("e9", "e4") }
        .to raise_error(described_class::IllegalMove, /bad square/)
    end
  end

  describe "check detection" do
    it "reports check" do
      game.board.from_fen("4k3/8/8/8/8/8/8/4R2K b - - 0 1")
      expect(game.in_check?).to be true
      expect(game.status).to match(/black is in check/)
    end
  end

  describe "checkmate" do
    it "detects the scholar's mate after the final move" do
      %w[e2e4 e7e5 f1c4 b8c6 d1h5 g8f6 h5f7].each do |move|
        game.play_move(move[0..1], move[2..3])
      end

      expect(game.checkmate?).to be true
      expect(game.over?).to be true
      expect(game.result).to eq("checkmate")
      expect(game.status).to match(/White wins/)
    end
  end

  describe "stalemate" do
    it "reports a stalemate position" do
      game.board.from_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
      expect(game.stalemate?).to be true
      expect(game.over?).to be true
      expect(game.result).to eq("stalemate")
    end
  end

  describe "special moves through the game" do
    it "plays a kingside castle and moves the rook" do
      game.board.from_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
      game.play_move("e1", "g1")
      expect(game.board[7, 6].type).to eq(:king)
      expect(game.board[7, 5].type).to eq(:rook)
      expect(game.current_color).to eq(:black)
    end

    it "plays an en passant capture" do
      game.board.from_fen("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
      game.play_move("e5", "d6")
      expect(game.board[2, 3].type).to eq(:pawn)
      expect(game.board[3, 3]).to be_nil
    end
  end

  describe "promotion" do
    it "promotes a pawn to a queen by default" do
      game.board.from_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
      game.play_move("a7", "a8")
      expect(game.board[0, 0].type).to eq(:queen)
    end

    it "promotes to the requested piece" do
      game.board.from_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
      game.play_move("a7", "a8", promotion: :knight)
      expect(game.board[0, 0].type).to eq(:knight)
    end

    it "rejects an invalid promotion piece" do
      game.board.from_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
      expect { game.play_move("a7", "a8", promotion: :king) }
        .to raise_error(described_class::IllegalMove, /cannot promote/)
    end
  end

  describe "saving and loading" do
    let(:path) { File.join(Dir.tmpdir, "chess_save_spec.json") }

    after { File.delete(path) if File.exist?(path) }

    it "round-trips a game through a file" do
      %w[e2e4 e7e5 g1f3].each { |move| game.play_move(move[0..1], move[2..3]) }
      game.save(path)

      loaded = described_class.load(path)
      expect(loaded.board.to_fen).to eq(game.board.to_fen)
      expect(loaded.current_color).to eq(:black)
      expect(loaded.history.length).to eq(3)
    end

    it "can load into an existing game object" do
      game.play_move("e2", "e4")
      game.save(path)

      other = described_class.new
      other.load(path)
      expect(other.board.to_fen).to eq(game.board.to_fen)
    end

    it "writes valid JSON" do
      game.save(path)
      expect(JSON.parse(File.read(path))).to include("fen", "history")
    end
  end
end
