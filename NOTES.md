# Chess Project — Working Notes

Running log. Newest section at the bottom.

---

## Stage map

1. Setup + RSpec wiring
2. Board + FEN
3. Move generation (per-piece)
4. FEN validation
5. Legal moves / king safety
6. Check, checkmate, stalemate
7. Castling + en passant
8. Serialization
9. CLI + AI
10. Display: coloring a board in a terminal
11. Rubocop

Cross-cutting notes at the end: board redraw bug, one-board redraw, piece registry,
object copying, and known gaps.

---

## Setup

`bundle init` writes a `Gemfile` (plain text at project root). Adding `gem "rspec"`
and running `bundle install` vendors rspec. Run tests with `bundle exec rspec`.

`.rspec` holds flags rspec always applies. `--require spec_helper` loads the
helper before any spec, so no spec needs its own require.

`spec/spec_helper.rb` uses `RSpec.configure` for global settings. Two worth knowing:

- `config.disable_monkey_patching!` means you must write `RSpec.describe` not bare
  `describe`. Keeps the global namespace clean.
- `config.order = :random` shuffles test order, so you can't accidentally depend on
  a test running before another.

---

## Board + FEN

**Coordinate system.** Positions are `[row, col]`, both 0–7. `row 0` is rank 8
(black's back rank), `row 7` is rank 1. So rank 8 is drawn first, which means the
board prints top-to-bottom with no flipping.

**Why `[row, col]` and not `[file, rank]`.** Row-major order matches how the grid
is actually laid out in memory, so a `flatten` on the squares array gives you pieces
in reading order. Mixing the two up is the single most common bug in a chess
program, so the conversion lives in exactly two methods: `square_name` and
`parse_square`.

**The two-dimensional array.** `Array.new(8) { Array.new(8) }` gives 8 separate
rows. The block form matters — `Array.new(8, Array.new(8))` would make all 8
"rows" the *same* object, so writing to one row would write to all of them.

**Pieces hold their own position.** `Board#move_piece` sets `piece.position` after
relocating it. The alternative (always asking the board where a piece is) means
scanning 64 squares to locate a piece you already have in hand.

**`#[](row, col)` returns nil out of bounds** rather than raising. Every move
generator asks about squares past the edge constantly, and raising would mean
guarding each call site. The write path `[]=` *does* raise, because a silent
off-board write is a bug you'd never see.

**`#clear` reassigns the array instead of nil-ing each cell.** `map! { nil }` would
work too, but reassignment is one line and cannot be half-finished.

**FEN.** Six space-separated fields:
```
rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
└ placement ─────┘ └─┘ └──┘ └┘ └┘ └┘
              active castling ep half full
```

- **placement** — 8 ranks separated by `/`. Digits are runs of empty squares
  (`8` = whole row empty). Uppercase is white, lowercase is black.
- **active** — whose turn it is.
- **castling** — which castling rights remain: `K`/`Q` for white, `k`/`q` for
  black, or `-`. Stored verbatim on the board as a string so import/export is
  nearly free (see the Castling section).
- **en passant** — the square a pawn may capture to *en passant*, or `-`.
- **halfmove / fullmove** — counters for the 50-move and draw rules.

Two gotchas the tests caught:
- FEN needs **case-sensitive** output (white uppercase, black lowercase), so
  `to_fen` can't reuse the unicode piece table. There's a separate `fen_symbol`.
- `to_fen` must not emit uppercase for black, or round-trips break silently.

**Why FEN is worth it.** It makes any position a one-line test fixture. Instead of
hand-placing 20 pieces to test checkmate, you paste a string from the Lichess board
editor. It also gives you save/load for free later.

---

## Move generation

**Two-tier design.** `Piece#candidates(board)` is *pseudo-legal* — what the piece
could do ignoring the king. `Piece#moves(board)` filters out squares occupied by
your own pieces. Every subclass only writes `candidates`; the friendly-piece
filter lives once in the base class. Sliding pieces and stepping pieces get it for
free.

**`step_moves` vs `slide_moves`.**
- *Stepping* (knight, king): add a fixed offset, keep it if on board. One
  `filter_map`.
- *Sliding* (rook, bishop, queen): walk in a direction until you hit something.
  `slide` adds each square, then **breaks if the square wasn't empty** — so a
  capture is included but nothing behind it is.

```ruby
while board.valid_position?(r, c)
  targets << [r, c]
  break unless board[r, c].nil?   # stop after hitting a piece
  r += row_offset
  c += col_offset
end
```

**Direction tables instead of arithmetic.** `Rook::DIRECTIONS` is
`[[-1,0],[1,0],[0,-1],[0,1]]`. Queen is rook + bishop directions. No trig, no
sign juggling, and you can read the rules straight off the constant.

**Pawns break the pattern, so they get their own class.** Forward movement,
double-step, and diagonal capture all obey different rules, and `forward` is `-1`
for white and `+1` for black:

```ruby
forward = color == :white ? -1 : 1
```

Pawn captures are `[[forward, -1], [forward, 1]]` — note the order: row offset
first. I originally wrote `[[-1, forward], [1, forward]]` (transposed) and it
looked almost right, which is the dangerous kind of bug.

**`START_ROW` / `PROMOTION_ROW` hashes keyed by color** beat `if color == :white`
branches scattered through the class. Each method becomes one line.

**En passant and castling read board state, but live on the piece.** Both need
information a piece cannot derive alone: the en passant target square, and the
castling-rights string. Rather than a board back-reference (which would make pieces
untestable in isolation and awkward to `dup`), `candidates(board)` receives the
board as an argument. `Pawn#candidates` consults `board.en_passant`;
`King#candidates` consults `board.can_castle?` plus `board.attacked?`.

So the rule is: **pieces may *read* the board, but never *store* it.** The board is
shared mutable state passed in per call; pieces stay simple value objects that are
cheap to `dup` for the legality simulation.

---

## FEN validation

`from_fen` now raises `ArgumentError` on a wrong rank count, an unknown piece
letter, or a rank whose digits don't total 8. This came from a real slip: I typed
`3p1p3` (which sums to 9) in a spec, and the parser happily placed pieces at
column 8 and dropped one on the floor. Silent acceptance of bad input is worse
than an exception, because the test fails with a confusing symptom instead of
pointing at the bad string.

---

## Testing patterns used here

**Test through the public interface.** Everything above is tested via `Board`
methods, not by reaching into `board.squares`. Tests that poke at internals break
on every refactor.

**`subject` / `subject(:name)`.** Declares the object under test once, gets a
`let`-style memoized instance. Saves repeating `described_class.new` in every
example.

**`described_class`** — the class named in the enclosing `describe`. No need to
repeat `Chess::Board` inside its own spec.

**`be_a_kind_of` / `be_nil` / `be_empty`** — RSpec's one-liner matchers. Prefer
these over `expect(x.nil?).to be true`.

**`#uniq` on a mapped array** to assert a property holds for all pieces at once:
`white.map(&:row).uniq.sort == [6, 7]` says "white pieces are only on rows 6 and 7"
in one line, where looping over 16 pieces would take ten.

**`&:sym`** — shorthand for `.map { |x| x.sym }`. Fine when the symbol is the only
operation.

---

## Things to watch for

- `place` takes a **position array**, not row and col. Consistency with `position`
  matters more than which you pick — but pick one.
- Writing FEN by hand is the single biggest source of test bugs in this project.
  Every rank must sum to exactly 8. Verify with the Lichess board editor rather
  than counting characters.
- Specs that address a piece by **square** (`moves_from(fen, "e2")`) fail loudly
  when the FEN is wrong. Specs that grab `pieces_for(:white).find { pawn }` fail
  confusingly, because they quietly test a different pawn than intended.
- Board mutation methods return the board (or piece) so calls can chain.
- `Board#[]` and `Board#valid_position?` are the boundary. Anything outside must
  check bounds first.

---

## Legal moves and king safety

Pseudo-legal moves ignore the king. Real legality is one rule: **after your move,
your own king must not be in check.** Everything else — pins, blocking, fleeing,
castling through check — falls out of that single test.

```ruby
def legal_move?(piece, target)
  copy = deep_dup
  copy.move_piece(piece.position, target)
  !copy.in_check?(piece.color)
end
```

**`deep_dup` instead of mutate-and-undo.** Undo logic is a bug farm: you must
restore the captured piece, the castling rights, the en passant square, the
clocks, and any rook moved during castling. Copying the board and replaying the
move once is harder to get subtly wrong. The copy is shallow by hand — `dup` each
piece (their `initialize_copy` also dups the position array) and copy each scalar
ivar.

**`moves` vs `attacks`** — two different questions:
- `moves` = squares I may legally *go to* (excludes friendly pieces, might exclude
  castling).
- `attacks` = squares I *threaten* regardless of what is there.

Pawns make the difference visible: a pawn `moves` forward (one or two) and
`attacks` diagonally. Using `moves` for attack detection marks the square *in
front* of a pawn as attacked, which wrongly forbids castling past it. This was a
real bug, now covered by a spec.

**King safety needs a special case for `attacks`, not `moves`.** If `attacked?`
called `moves` on the enemy king, and the king's `moves` includes castling, and
castling asks `attacked?`, you recurse forever. `King#attacks` returns plain
adjacent squares and never consults castling — that breaks the cycle.

## Check, checkmate, stalemate

All three fall out of two primitives — `in_check?` and the legal move list:

```ruby
in_check?(c)  = king_position(c) is attacked by opponent(c)
checkmate?(c) = in_check?(c) && legal_moves(c).empty?
stalemate?(c) = !in_check?(c) && legal_moves(c).empty?
```

**Why stalemate is a draw, not a loss.** Origin of the rule: if the side to move
has no legal move but is *not* in check, the game ends level. The predicate pair is
deliberately symmetric — same "no legal moves" test, opposite check condition — so
the two cases can never both fire and neither can be forgotten.

**Cost.** `checkmate?`/`stalemate?` call `legal_moves`, which for each piece calls
`legal_move?`, which calls `deep_dup` and `in_check?`. That is the heaviest path in
the program. It is fine at 64 squares and the clarity is worth it; a real engine
would instead track a king-safety bit incrementally. Correctness first.

**Testing edge cases that matter.**
- Checkmate from a *real game sequence* (Scholar's mate) proves the predicates work
  after normal moves, not just from a hand-built FEN.
- A position that is check but *not* mate (king can escape) guards against the
  `checkmate?` check being dropped.
- Stalemate with the side *not* in check guards the `!in_check?` half.
- `stalemate?` must be false when in check — otherwise check and stalemate overlap.

## Castling

Castling is a **king move of two columns** plus a side effect. The generation
conditions, all required:

1. castling right present for that side (`K`, `Q`, `k`, `q`),
2. king on its home square,
3. king not currently in check,
4. squares between king and rook empty,
5. the two squares the king crosses are not attacked.

Rights are stored as a **string** (`"KQkq"`) rather than booleans. Revoking is
`@castling.delete("KQ")`; FEN import/export is nearly free; a move revokes rights
if the king moves, the rook moves *off* its corner, or a rook is captured *on* its
corner. The corner-to-letter table `CORNER_RIGHTS` keeps the last two cases to one
lookup.

The rook relocation lives in `move_piece`, detected by `(to_col - from_col).abs == 2`,
so both live play and the legality simulation get it with no duplicated code.

The `safe_square?` helper was originally called with a leading `!`, i.e.
`!safe_square?`, which reads as "not (not attacked)". The double negative silently
disabled castling entirely. Naming the helper for the positive condition
(`safe_square?`) is what made the bug obvious.

## En passant

- A pawn that just moved two squares leaves `board.en_passant` = the square it
  skipped.
- `Pawn#candidates` offers that square if it is diagonally ahead of the pawn.
- Applying it is the tricky part: the pawn lands on an **empty** square, so the
  captured pawn is *not* at the destination. `move_piece` detects this case
  (`captured.nil? && from_col != to_col && to == en_passant`) and removes the
  captured pawn from `[from_row, to_col]`.
- The square is cleared by the next `move_piece` unless that move was itself a
  double step, so it is only available for one move.

The halfmove/fullmove clocks and the en passant square are updated inside
`move_piece` too. It is tempting to split "pure movement" from "game bookkeeping",
but keeping them together means the legality simulation sees a fully correct board.

## Serialization

`Game#to_h` stores the FEN plus the move history; `save` writes it with
`JSON.pretty_generate`, `Game.load` reads it back. Because the FEN now carries
castling rights, the en passant square, and both clocks, the board round-trips
exactly and no separate board serialization is needed.

`save`/`load` are on the *game*, not the board, because turn and history belong to
the game. `load` is both a class method (`Game.load`) and an instance method that
mutates in place, so the CLI can reload without reassigning `@game`.

## CLI and the AI

All input handling lives in `Game#handle`, which **returns a string** instead of
printing. `#play` is the only part that touches IO, and it takes `input`/`output`
defaulting to `$stdin`/`$stdout`. That means the whole UI can be tested with a
`StringIO` script — see `spec/ui_spec.rb`, which drives a full scholar's mate and
asserts the game ends in checkmate.

`Ai` picks uniformly from `board.legal_moves(color)`. Injecting a `Random` (default
`Random.new`) makes it deterministic in tests. `Game` takes an optional `ai:`
object and auto-plays its turn; `ruby main.rb --ai` plays against it.

## Testing patterns used here (part 2)

**`StringIO` for CLI tests.** No terminal, no mocking `$stdin`. Feed a script,
assert on `output.string`.

**Seeded randomness.** `Random.new(1)` makes "random" reproducible, so the AI spec
can assert exact equality of two runs.

**Test the negative case explicitly.** "Pawn forward square is not attacked" is a
spec that only exists because the bug existed. When you fix a logic inversion,
write the spec that would have caught it.

---

## Board redraw bug (CLI)

Symptom: in `--ai`, the board only appeared *after the AI's move*. Human moves
registered (the next prompt showed the effects, castling worked, save/load
matched) but the display never changed.

Cause: `play` rendered the board once before the loop, and `play_ai_turn` rendered
after the AI moved. A human move returned `"ok"` and nothing redrew it. The bug
was not in the game logic at all — the position was correct every time — it was
that **rendering was attached to one code path instead of the loop.**

Fix: render once at the top of the loop, so every iteration (human or AI) shows the
current position. The AI path just needs the turn before `next`.

Lesson: if the *state* is right but the *view* is stale, do not go hunting in the
state. Look at where the view is produced and ask which paths skip it.

## Display: coloring a chessboard in a terminal

This took four passes. Each one exposed a constraint the previous one ignored.

**Pass 1 — color by square only.** `LIGHT = "\e[48;5;223m\e[30m"` bundled a
background *and* a foreground. Because the square set the foreground, the piece
color was decided by the square: white pieces turned black on light squares and
vice versa. Bundling two attributes in one escape sequence hid the coupling.

**Pass 2 — split background from foreground.** Now the piece's own color set the
foreground. This fixed side accuracy, but *hollow* white glyphs (`♔`) in near-white
on a light square are invisible. So I added a contrasting "chip" behind each piece.

**Pass 3 — per-piece chip.** Reliable contrast, but the board was no longer a clean
checkerboard: pieces sat on little badges.

**Pass 4 — uniform side colors (final).** The user wanted white pieces white and
black pieces black, everywhere. The blocker is arithmetic: **no single foreground
color is readable on both a near-white and a near-black background.** Pure white
vanishes on light squares; pure black vanishes on dark ones.

The resolution is to choose the *squares* to suit the pieces, not the other way
round: two **mid-tone** square colors (greens `48;5;108` / `48;5;65`) so that both
pure white (`1;97`) and pure black (`1;30`) stay legible on both shades. White is
the Unicode outline glyph, so the square shows through the letterforms and reads as
white.

Trade-off accepted: gray-ish squares instead of the classic tan/brown, in exchange
for side-accurate, position-independent piece colors.

**Terminal color specifics.**
- `\e[48;5;Nm` = 256-color *background* (square), `\e[38;5;Nm` = foreground.
- `\e[1;97m` = bright white, `\e[1;30m` = black (the `1;` is bold).
- The foreground set by `piece_color` must be re-overridden by the next cell's
  `square_color` on every cell, otherwise a piece's color leaks to its right.

## One board, redrawn in place

Redrawing a *new* board below the old one is noisy. `Display#clear_screen` returns
the ANSI clear (`\e[H\e[2J`) and `Game#play` prints it before each render.

**Only clear on a real terminal.** `output.respond_to?(:tty?) && output.tty?` is
false for a pipe or a `StringIO`, so:
- specs and piped runs stay plain (no escape spam, no flakiness),
- the interactive terminal gets the in-place update.

This is why `render` takes the board and returns a string while `play` owns all IO:
the display can be driven by anything, including a `StringIO`.

`Display.new(color: false)` turns off all escapes, which is what the specs use.

## Rubocop

Added `.rubocop.yml` and made the project offense-free (28 files, 0 offenses)
without churning working code.

Rubocop's defaults fought the project on two style points, both settled by config
rather than mass edits:
- `Style/StringLiterals` wants single quotes; the project uses double.
- `Style/FrozenStringLiteralComment` wants a magic comment on every file.

Setting `EnforcedStyle: double_quotes` and disabling the frozen-comment cop keeps
the existing style; `rubocop -a` then only fixed genuine small stuff (stray blank
lines, redundant escapes).

**Metrics cops: raise the limit, don't contort the code.** `Metrics/ClassLength`,
`MethodLength`, `AbcSize`, `CyclomaticComplexity` flagged real methods
(`Board#move_piece`, `Game#parse_move`). Splitting those purely to satisfy a line
count would hurt readability. Raised to `ClassLength 300`, `MethodLength 20`,
`AbcSize 25`, `CyclomaticComplexity 10` — permissive but still catching genuine
monsters. Spec files are excluded from all Metrics; a long `describe` block is
normal and not a smell.

**`SuggestExtensions: false`** silences the "install rubocop-rspec" nag.

Lesson: a linter is a default opinion, not a law. Configure it to match deliberate
choices, and only change code where the linter has a real point.

## Running the game

```
ruby main.rb          # two human players
ruby main.rb --ai     # you (white) vs random AI (black)
```

```
e2 e4        move (or e2e4)
e7 e8 q      promote (q/r/b/n)
board        redraw
save f.json / load f.json
help / quit
```

Useful test sequences (scripted into the game):
- Fool's mate (black wins): `f2f3 e7e5 g2g4 d8h4`
- Scholar's mate (white wins): `e2e4 e7e5 f1c4 b8c6 d1h5 g8f6 h5f7`
- Castling: `e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 e1g1`
- En passant: `e2e4 a7a6 e4e5 d7d5 e5d6`

`Ctrl-C` during your turn exits cleanly: `read_line` rescues `Interrupt` and returns
`nil`, which the loop treats like end-of-input.

---

## Piece registry and load order

`Board` needs to build pieces from a `type` symbol in three places: starting setup,
FEN parsing, and promotion. Rather than a `case` on the type, there is one table:

```ruby
# lib/chess.rb, AFTER all the requires
PIECE_CLASSES = { king: King, queen: Queen, rook: Rook,
                  bishop: Bishop, knight: Knight, pawn: Pawn }.freeze

def self.piece_class(type) = PIECE_CLASSES[type]
```

**Why it is defined after the `require`s, not in `constants.rb`.** The hash
*references the class constants* `King`, `Queen`, and so on. Those don't exist
until `pieces/king.rb` etc. have been loaded. Put the table in a file required
before the pieces and it raises `NameError: uninitialized constant Chess::King` at
load time. This is the classic load-order trap: a constant whose *value* depends on
other files cannot live in the file that is loaded first.

**`SYMBOL_TO_TYPE` is a separate table** (in `pieces/registry.rb`). It maps FEN
letters (`"k"`, `"q"`, …) to type symbols. It looks redundant next to
`PIECE_CLASSES`, but it is about *parsing input*, not *class lookup*, and its keys
are strings, not symbols. Keeping them apart means a `case`-style conversion and a
class lookup don't get tangled.

## Object copying: `dup`, `initialize_copy`, `deep_dup`

Ruby's `dup` copies an object's instance variables **shallowly** — nested objects
are shared, not cloned. Three levels matter here.

**`Piece#initialize_copy`** dups the `@position` array:

```ruby
def initialize_copy(other)
  super
  @position = other.position.dup
end
```

Without it, `piece.dup` would share the same `[row, col]` array; moving the copy
would move the original's coordinate too. Overriding `initialize_copy` is the hook
`dup`/`clone` call, so this happens automatically for every `dup` — including the
ones `deep_dup` does.

**`Board#deep_dup`** exists because a board is *nested*: an array of rows, each row
an array of pieces. A shallow `dup` would share the row arrays and every piece, so
simulating a move on the "copy" would corrupt the real game.

```ruby
copy.instance_variable_set(:@squares,
  @squares.map { |row| row.map { |piece| piece&.dup } })
```

**Why `allocate` + `instance_variable_set` instead of `Board.new`.** `initialize`
calls `setup_starting_position`, which would place 32 pieces you're about to
overwrite. `allocate` creates the object without running `initialize`, then every
ivar is set explicitly. It is also a checklist: forget an ivar (say `@castling`)
and the copy silently diverges from the original — which is exactly the kind of bug
the legality simulation would surface as a phantom illegal move.

**Where copies are used:** `Board#legal_move?` dups the board, applies the move,
and asks whether the mover's king is now in check. Copy-and-test beats
mutate-and-undo, because undo must restore the captured piece, castling rights, the
en passant square, both clocks, *and* any rook displaced by castling.

## Known gaps / where to take it next

Everything the assignment required is done and tested. Deliberately left out:

- **Draw rules.** `halfmove_clock` is maintained in `move_piece` (reset on pawn
  moves and captures), so the **50-move rule** is one line away
  (`halfmove_clock >= 100`). **Threefold repetition** needs a position hash
  (FEN placement + side + castling + ep, without the clocks); store seen positions
  in a Hash and count. **Insufficient material** is a small table of
  K vs K, K+B vs K, K+N vs K, K+B vs K+B same color.
- **Algebraic notation (SAN).** Input is coordinate-only (`e2 e4`). SAN output
  (`Nf3`, `O-O`, `exd5`, `e8=Q+`) needs disambiguation when two same-type pieces
  can reach a square, plus `+`/`#` suffixes from the existing `in_check?` and
  `checkmate?`. SAN *input* additionally needs legal-move matching.
- **A stronger AI.** The current one is uniformly random, as the extra credit
  allows. Minimax with material + piece-square tables would slot in behind the same
  `Ai#move(board)` interface — `Game` never needs to know.
- **Promotion choice in the CLI is minimal.** The suffix (`e7 e8 q`) defaults to
  queen; an interactive prompt listing the four pieces would be friendlier.


