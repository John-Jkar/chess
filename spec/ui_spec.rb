require "chess"
require "stringio"
require "tmpdir"

RSpec.describe Chess::Game do
  subject(:game) { described_class.new }

  describe "#handle" do
    it "plays a spaced move" do
      expect(game.handle("e2 e4")).to eq("ok")
      expect(game.board[4, 4].type).to eq(:pawn)
    end

    it "plays a compact move" do
      expect(game.handle("e2e4")).to eq("ok")
      expect(game.board[4, 4].type).to eq(:pawn)
    end

    it "reports an illegal move instead of raising" do
      expect(game.handle("e2 e5")).to match(/Illegal move/)
    end

    it "reports gibberish" do
      expect(game.handle("hello")).to match(/did not understand/)
    end

    it "returns the help text" do
      expect(game.handle("help")).to eq(described_class::HELP)
    end

    it "returns a rendered board for the board command" do
      expect(game.handle("board")).to include("a  b  c")
    end

    it "handles a promotion suffix" do
      game.board.from_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
      game.handle("a7 a8 n")
      expect(game.board[0, 0].type).to eq(:knight)
    end
  end

  describe "#play" do
    it "runs a scripted game to a checkmate" do
      input = StringIO.new("e2e4\ne7e5\nf1c4\nb8c6\nd1h5\ng8f6\nh5f7\n")
      output = StringIO.new

      game.play(input: input, output: output, display: Chess::Display.new(color: false))

      expect(game.result).to eq("checkmate")
      expect(output.string).to match(/White wins by checkmate/)
    end

    it "stops on a nil input" do
      output = StringIO.new
      expect { game.play(input: StringIO.new, output: output, display: Chess::Display.new(color: false)) }
        .not_to raise_error
    end

    it "exits cleanly on Ctrl-C instead of crashing" do
      interrupting_input = Object.new
      def interrupting_input.gets
        raise Interrupt
      end

      output = StringIO.new
      expect do
        game.play(input: interrupting_input, output: output, display: Chess::Display.new(color: false))
      end.not_to raise_error
      expect(output.string).to include("white to move")
    end
  end
end

RSpec.describe Chess::Display do
  subject(:display) { described_class.new(color: false) }

  it "renders eight ranks and a file label" do
    lines = display.render(Chess::Board.new).split("\n")
    expect(lines.length).to eq(9)
    expect(lines.last).to include("a", "h")
  end

  it "shows the pieces of the starting position" do
    expect(display.render(Chess::Board.new)).to include("♜", "♙", "♔")
  end
end
