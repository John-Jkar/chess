require "chess"

RSpec.describe Chess::Ai do
  let(:board) { Chess::Board.new }

  describe "#move" do
    it "returns a move that is legal for its color" do
      ai = described_class.new(:white)
      move = ai.move(board)
      piece = board[*move[:from]]
      expect(piece.color).to eq(:white)
      expect(board.legal_targets(move[:from])).to include(move[:to])
    end

    it "always returns one of the legal moves" do
      ai = described_class.new(:black)
      legal = board.legal_moves(:black)
      move = ai.move(board)
      expect(legal).to include([move[:from], move[:to]])
    end

    it "raises when there are no legal moves" do
      board.from_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
      ai = described_class.new(:black)
      expect { ai.move(board) }.to raise_error(/no legal moves/)
    end

    it "is deterministic with a seeded random" do
      first = described_class.new(:white, random: Random.new(1)).move(board)
      second = described_class.new(:white, random: Random.new(1)).move(board)
      expect(first).to eq(second)
    end
  end

  describe "integration with Game" do
    it "lets the AI reply as black" do
      game = Chess::Game.new(Chess::Board.new, ai: described_class.new(:black, random: Random.new(2)))
      game.play_move("e2", "e4")
      expect(game.current_color).to eq(:black)

      input = StringIO.new("")
      game.play(input: input, output: StringIO.new, display: Chess::Display.new(color: false))
      expect(game.current_color).to eq(:white)
    end
  end
end
