# frozen_string_literal: true

require_relative "lib/chess"

ai = ARGV.include?("--ai") ? Chess::Ai.new(:black) : nil
Chess::Game.new(Chess::Board.new, ai: ai).play
