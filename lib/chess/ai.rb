module Chess
  class Ai
    attr_reader :color

    def initialize(color = :black, random: Random.new)
      @color = color
      @random = random
    end

    def move(board)
      choices = board.legal_moves(color)
      raise "no legal moves for #{color}" if choices.empty?

      from, to = choices.sample(random: @random)
      { from: from, to: to, promotion: :queen }
    end
  end
end
