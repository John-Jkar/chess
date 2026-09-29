module Chess
  class Display
    FILES = ("a".."h").to_a.freeze

    LIGHT_SQUARE = "\e[48;5;108m".freeze
    DARK_SQUARE = "\e[48;5;65m".freeze
    WHITE_PIECE = "\e[1;97m".freeze
    BLACK_PIECE = "\e[1;30m".freeze
    RESET = "\e[0m".freeze
    CLEAR = "\e[H\e[2J".freeze

    def initialize(color: true)
      @color = color
    end

    def clear_screen
      @color ? CLEAR : ""
    end

    def render(board)
      lines = 8.times.map { |row| rank_line(board, row) }
      lines << file_line
      lines.join("\n")
    end

    private

    def rank_line(board, row)
      cells = 8.times.map { |col| cell(board, row, col) }
      "#{8 - row} #{cells.join}#{reset}"
    end

    def cell(board, row, col)
      piece = board[row, col]
      glyph = piece ? piece.to_s : " "
      "#{square_color(row, col)}#{piece_color(piece)} #{glyph} "
    end

    def square_color(row, col)
      return "" unless @color

      (row + col).even? ? LIGHT_SQUARE : DARK_SQUARE
    end

    def piece_color(piece)
      return "" if piece.nil? || !@color

      piece.color == :white ? WHITE_PIECE : BLACK_PIECE
    end

    def file_line
      "  a  b  c  d  e  f  g  h"
    end

    def reset
      @color ? RESET : ""
    end
  end
end
