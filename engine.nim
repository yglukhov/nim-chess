# very basic chess game in Nim
# c S. Salewski 2016

from algorithm import sort
from sequtils import keepIf, anyIt
from times import cpuTime

const
  AB_Inf = 32000
  MaxDepth = 15
  VoidID = 0
  PawnID = 1
  KnightID = 2
  BishopID = 3
  RookID = 4
  QueenID = 5
  KingID = 6
  WPawn = PawnID
  WKnight = KnightID
  WBishop = BishopID
  WRook = RookID
  WQueen = QueenID
  WKing = KingID
  BPawn = -PawnID
  BKnight = -KnightID
  BBishop = -BishopID
  BRook = -RookID
  BQueen = -QueenID
  BKing = -KingID

const
  Forward = 8
  Sideward = 1
  S = Forward
  O = Sideward
  N = -S
  W = -O
  NO = N + O
  SO = S + O
  NW = N + W
  SW = S + W

  PawnDirsWhite = [Forward - Sideward, Forward + Sideward, Forward, Forward + Forward]
  BishopDirs = [NO, SO, NW, SW]
  RookDirs = [N, O, S, W]
  KnightDirs = [N + NO, N + NW, W + NW, W + SW, O + NO, O + SO, S + SO, S + SW]
  KingDirs = [N, O, S, W, NO, SO, NW, SW] # KingDirs = BishopDirs + RookDirs

const
  StaleMateValue = 0
  VoidValue = 0
  PawnValue = 100
  KnightValue = 300
  BishopValue = 300
  RookValue = 500
  QueenValue = 900
  KingValue = 18000
  SureCheckmate* = KingValue div 2

  FigureValue: array[-KingID..KingID, int] = [-KingValue, -QueenValue, -RookValue, -BishopValue, -KnightValue, -PawnValue, VoidValue,
    PawnValue, KnightValue, BishopValue, RookValue, QueenValue, KingValue]

const
  Setup = [
    WRook, WKnight, WBishop, WKing, WQueen,WBishop, WKnight, WRook,
    WPawn, WPawn, WPawn, WPawn, WPawn, WPawn, WPawn, WPawn,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    BPawn, BPawn, BPawn, BPawn, BPawn, BPawn, BPawn, BPawn,
    BRook, BKnight, BBishop, BKing, BQueen, BBishop, BKnight, BRook]

# the traditional row and column designators -- B prefix for Board
const BA = 7; const BB = 6; const BC = 5; const BD = 4; const BE = 3; const BF = 2; const BG = 1; const BH = 0
const B1 = 0; const B2 = 1; const B3 = 2; const B4 = 3; const B5 = 4; const B6 = 5; const B7 = 6; const B8 = 7

const PosRange = 0..63

type
  Color = enum Black = -1, White = 1
  ColorIndex = 0..1
  Position = 0..63
  Col = 0..7
  Row = 0..7
  FigureID = int
  Board* = array[Position, FigureID]
  Has_Moved = array[Position, bool]
  Mobset = array[Position, set[0..MaxDepth]]
  Freedom = array[8, array[Position, int]] # VoidID..KingID; I think I should call it happyness

type
  Gnu = tuple # move precalculation is based on old gnuchess ideas...
    pos: int
    nxt_dir_idx: int

  Path = array[Position, array[Position, Gnu]]

var # we use global data for now
  board: Board
  mob_set: Mobset
  has_moved: Has_Moved
  freedom: Freedom
  pawn_path: array[ColorIndex, Path]
  knight_path: Path
  bishop_path: Path
  rook_path: Path
  king_path: Path
  checkmate_depth = -1
  pjm = -1

# proc same_sign(i: int; j: Color): bool = (i.int xor j.int) >= 0

proc clear[T](s: var seq[T]) = s.setLen(0)

proc is_a_pawn(p: Position): bool = board[p].abs == PawnID

proc is_a_king(p: Position): bool = board[p].abs == KingID

proc col_idx(c: Color): ColorIndex = (c.int + 1) div 2

proc isWhite(c: Color): bool = c.int == White.int

proc isBlack(c: Color): bool = c.int == Black.int

proc oppColor(c: Color): Color = (-c.int).Color

proc col(p: Position): Col = p mod 8

proc row(p: Position): Row = p div 8

proc base_row(p: Position): bool = (p div 8) mod 7 == 0

proc sign(i: int): int = (if i < 0: -1 elif i > 0: 1 else: 0) # maybe not the best solution

proc even(i: int): bool = i mod 2 == 0

proc odd(i: int): bool = i mod 2 != 0

#proc border(p: int): bool =
#  p < 8 or p > 48 or p mod 8 == 0 or p mod 8 == 7

proc off_board64(dst: int): bool = dst < Board.low or dst > Board.high

# do we not cross the border of the board when figure is moved in a regular way
proc move_is_valid(src: Position; dst: int): bool =
  if off_board64(dst): return false
  var
    a = col(src)
    b = col(dst)
  if a > b: swap(a, b)
  not (a == 0 and b == 7)

proc knight_move_is_valid(src: Position; dst: int): bool =
  if off_board64(dst): return false
  var
    a = col(src)
    b = col(dst)
  if a > b: swap(a, b)
  not ((a == 0 and (b == 7 or b == 6)) or (a == 1 and b == 7))

proc pawn_move_is_valid(c: Color; src, dst: int): bool =
  if not move_is_valid(src, dst): return false
  if (src - dst).abs == 16:
    return if c.isWhite: row(src) == B2 else: row(src) == B7
  return true

proc initRook =
  for src in PosRange:
    var i = 0
    for d in RookDirs:
      var pos = src
      while true:
        var dst = pos + d
        if not move_is_valid(pos, dst): break
        rook_path[src][i].pos = if pos == src: - dst else: dst # mark start pos for this dir
        inc i
        pos = dst
    var nxt_dir_start = i # index of the last terminal node
    rook_path[src][i].pos = -1 # terminator
    while i > 0:
      dec i
      rook_path[src][i].nxt_dir_idx = nxt_dir_start
      if rook_path[src][i].pos < 0:
        nxt_dir_start = i
        rook_path[src][i].pos *= -1

proc initBishop =
  for src in PosRange:
    var i = 0
    for d in BishopDirs:
      var pos = src
      while true:
        var dst = pos + d
        if not move_is_valid(pos, dst): break
        bishop_path[src][i].pos = if pos == src: -dst else: dst
        inc i
        pos = dst
    var nxt_dir_start = i
    bishop_path[src][i].pos = -1
    freedom[BishopID][src] = i
    while i > 0:
      dec i
      bishop_path[src][i].nxt_dir_idx = nxt_dir_start
      if bishop_path[src][i].pos < 0:
        nxt_dir_start = i
        bishop_path[src][i].pos *= -1

proc initKnight =
  for src in PosRange:
    var i = 0
    for d in KnightDirs:
      if knight_move_is_valid(src, src + d):
        knight_path[src][i].pos = src + d
        knight_path[src][i].nxt_dir_idx = i + 1 # not really needed
        inc i
    knight_path[src][i].pos = -1
    freedom[KnightID][src] = i

proc initKing =
  for src in PosRange:
    var i = 0
    for d in KingDirs:
      if move_is_valid(src, src + d):
        king_path[src][i].pos = src + d
        king_path[src][i].nxt_dir_idx = i + 1
        inc i
    king_path[src][i].pos = -1

# the first two moves are possible captures or -1 if at the border of the board
proc initPawn(color: Color) =
  for src in PosRange:
    var i = 0
    for d in PawnDirsWhite:
      pawn_path[color.col_idx][src][i].pos =
        if pawn_move_is_valid(color, src, src + d * color.int): src + d * color.int else: -1
      pawn_path[color.col_idx][src][i].nxt_dir_idx = i + 1 # not really needed
      inc i
    pawn_path[color.col_idx][src][i].pos = -1

type
  KK = tuple # source figure, destination figure, source index, destination index and score
    sf: int
    df: int
    si: int
    di: int
    s: int

  KKS = seq[KK]

proc capture(kk: KK):bool = kk.sf * kk.df < 0

proc walkRook(kk: KK; s: var KKS) =
  var i: int
  var kk = kk
  while true:
    kk.di = rook_path[kk.si][i].pos
    if kk.di == -1: break
    kk.df = board[kk.di]
    if kk.df == 0:
      inc i
      s.add kk
    else:
      i = rook_path[kk.si][i].nxt_dir_idx
      if capture(kk): s.add kk

proc walkBishop(kk: KK; s: var KKS) =
  var i: int
  var kk = kk
  while true:
    kk.di = bishop_path[kk.si][i].pos
    if kk.di == -1: break
    kk.df = board[kk.di]
    if kk.df == 0:
      inc i
      s.add kk
    else:
      i = bishop_path[kk.si][i].nxt_dir_idx
      if capture(kk): s.add kk

proc walkKing(kk: KK; s: var KKS) =
  var i: int
  var kk = kk
  while true:
    kk.di = king_path[kk.si][i].pos
    if kk.di == -1: break
    kk.df = board[kk.di]
    if kk.df == 0 or capture(kk):
      s.add kk
    inc i

proc walkKnight(kk: KK; s: var KKS) =
  var i: int
  var kk = kk
  while true:
    kk.di = knight_path[kk.si][i].pos
    if kk.di == -1: break
    kk.df = board[kk.di]
    if kk.df == 0 or capture(kk):
      s.add kk
    inc i

proc walkPawn(kk: KK; s: var KKS) =
  let col_idx = col_idx(sign(kk.sf).Color)
  var i: int
  var kk = kk
  while i < 2:
    kk.di = pawn_path[col_idx][kk.si][i].pos
    inc i
    if kk.di >= 0:
      kk.df = board[kk.di]
      if capture(kk) or (kk.s >= 0 and (not base_row(kk.di)) and kk.s in mob_set[kk.di]):
        s.add kk
  kk.di = pawn_path[col_idx][kk.si][i].pos
  inc i
  if kk.di >= 0:
    kk.df = board[kk.di]
    if kk.df == 0:
      s.add kk
      kk.di = pawn_path[col_idx][kk.si][i].pos
      if kk.di >= 0:
        kk.df = board[kk.di]
        if kk.df == 0:
          s.add kk

type
  Move = tuple
    src: int
    dst: int
    score: int
    checkmate_depth: int

var ev_counter: int
proc evaluate_board: int =
  ev_counter += 1
  for p, f in board: result += FigureValue[f] + freedom[f.abs][p] * sign(f.int)

discard """
https://chessprogramming.wikispaces.com/Alpha-Beta
int alphaBeta( int alpha, int beta, int depthleft ) {
   if( depthleft == 0 ) return quiesce( alpha, beta );
   for ( all moves)  {
      score = -alphaBeta( -beta, -alpha, depthleft - 1 );
      if( score >= beta )
         return beta;   //  fail hard beta-cutoff
      if( score > alpha )
         alpha = score; // alpha acts like max in MiniMax
   }
   return alpha;
}
"""

proc quiescence(color: Color; depthleft: int; alpha: int; beta: int): int =
  var alpha = alpha
  let state = evaluate_board() * color.int
  if state >= beta: return beta
  if alpha < state: alpha = state
  var
    s = newSeq[KK]()
    kk: KK
  kk.s = depthleft # <= 0 # only for 0 ep capture is possible
  for si, sf in board: # source index, source figure
    if sf * color.int <= 0: continue
    kk.si = si
    kk.sf = sf
    case sf.abs:
      of PawnID: walkPawn(kk, s)
      of KnightID: walkKnight(kk, s)
      of BishopID: walkBishop(kk, s)
      of RookID: walkRook(kk, s)
      of QueenID: walkBishop(kk, s); walkRook(kk, s)
      of KingID: walkKing(kk, s)
      else: discard
  keepIf(s, proc(el: KK): bool = el.df != VoidID) # only captures
  for el in s.mitems:
    el.s = FigureValue[el.df].abs - FigureValue[el.sf].abs
  s.sort do (a, b: KK) -> int:
    result = cmp(b.s, a.s)
  for el in s:
    if el.df.abs == KingID: return KingValue + depthleft * QueenValue
    board[el.si] = VoidID
    board[el.di] = el.sf
    var en_passant = el.sf.abs == PawnID and el.df == VoidID and (el.di - el.si).odd # move is an e_p capture
    if en_passant: board[el.di - color.int * 8] = VoidID
    var score = -quiescence(color.oppColor, depthleft - 1, -beta, -alpha)
    board[el.di] = el.df
    board[el.si] = el.sf
    if en_passant: board[el.di - color.int * 8] = -el.sf
    if score >= beta: return beta
    if score > alpha: alpha = score
    board[el.si] = el.sf
  return alpha

proc alphabeta(color: Color; depthleft: int; alpha0: int; beta: int): Move =
  if depthleft == 0:
    result.score = quiescence(color, 0, alpha0, beta)
    #result.score = evaluate_board() * color.int
    return result
  var
    alpha = alpha0
    s = newSeq[KK]()
    kk: KK
  let x = depthleft - 1
  kk.s = depthleft
  for si, sf in board: # source index, source figure
    if sf * color.int <= 0: continue
    kk.si = si
    kk.sf = sf
    case sf.abs:
      of PawnID: walkPawn(kk, s)
      of KnightID: walkKnight(kk, s)
      of BishopID: walkBishop(kk, s)
      of RookID: walkRook(kk, s)
      of QueenID: walkBishop(kk, s); walkRook(kk, s)
      of KingID: walkKing(kk, s)
      else: discard
  if s.len == 0 : result.score = StaleMateValue; return
  for el in s.mitems:
    el.s = FigureValue[el.df].abs - FigureValue[el.sf].abs - KingValue
  s.sort do (a, b: KK) -> int:
    result = cmp(b.s, a.s)
  if depthleft > 3: # fast search for good move ordering
    for el in s.mitems:
      if el.df.abs == KingID: el.s = KingValue; break #result.score = KingValue + depthleft * QueenValue; break
      board[el.si] = VoidID
      board[el.di] = el.sf
      if base_row(el.di) and board[el.di].abs == PawnID:
        board[el.di] *= QueenID
      if base_row(el.di): incl(mob_set[el.di], depthleft) # we attack this square in base row
      var en_passant = el.sf.abs == PawnID and el.df == VoidID and (el.di - el.si).odd # move is an e_p capture
      if en_passant: board[el.di - color.int * 8] = VoidID
      var h = has_moved[el.si]
      has_moved[el.si] = true # may be a king or rook move, so castling is forbidden
      var pawn_jump = el.sf.abs == PawnID and (el.si - el.di).abs == 16
      if pawn_jump: incl(mob_set[(el.si + el.di) div 2], x) # next opp move can do e_p capture
      var m = alphabeta(color.oppColor, depthleft - 3, -beta, -alpha)
      if pawn_jump: excl(mob_set[(el.si + el.di) div 2], x)
      has_moved[el.si] = h
      board[el.di] = el.df
      board[el.si] = el.sf
      if en_passant: board[el.di - color.int * 8] = -el.sf
      m.score *= -1
      el.s = m.score # for move ordering
      if m.score >= beta:
        #result.score = beta # or return m.score? should not really matter
        break
      if m.score > alpha:
        alpha = m.score
    s.sort do (a, b: KK) -> int:
      result = cmp(b.s, a.s)
  alpha = alpha0
  for el in s:
    if el.df.abs == KingID:
      result.score = KingValue + depthleft * QueenValue
      result.src = el.si
      result.dst = el.di
      return
    board[el.si] = VoidID
    board[el.di] = el.sf
    if base_row(el.di) and board[el.di].abs == PawnID:
      board[el.di] *= QueenID
    if base_row(el.di): incl(mob_set[el.di], depthleft) # we attack this square
    var en_passant = el.sf.abs == PawnID and el.df == VoidID and (el.di - el.si).odd # move is an e_p capture
    if en_passant: board[el.di - color.int * 8] = VoidID
    let h = has_moved[el.si]
    has_moved[el.si] = true # may be a king or rook move, so castling is forbidden
    var pawn_jump = el.sf.abs == PawnID and (el.si - el.di).abs == 16
    if pawn_jump: incl(mob_set[(el.si + el.di) div 2], x) # next opp move can do e_p capture
    var m = alphabeta(color.oppColor, x, -beta, -alpha)
    if pawn_jump: excl(mob_set[(el.si + el.di) div 2], x)
    has_moved[el.si] = h
    board[el.di] = el.df
    board[el.si] = el.sf
    if en_passant: board[el.di - color.int * 8] = -el.sf
    m.score *= -1
    if m.score >= beta:
      result.score = beta # or return m.score? should not really matter
      return
    if m.score > alpha:
      alpha = m.score
      result.src = el.si
      result.dst = el.di

  const # king, void, void, void, rook, king_delta, rook_delta
    Q = [[3, 2, 1, 1, 0, -2, 2], [3, 4, 5, 6, 7, 2, -3]]
  let
    k = WKing * color.int
    r = WRook * color.int
  for i in 0..1: # castlings both sides
    var q = Q[i]
    if color == Black:
      for j in 0..4:
        q[j] += 7 * 8
    if board[q[0]] == k and board[q[1]] == 0 and board[q[2]] == 0 and board[q[3]] == 0 and board[q[4]] == r and
      not (has_moved[q[0]] or has_moved[q[4]]):
      has_moved[q[0]] = true; has_moved[q[4]] = true
      board[q[0]] = 0
      board[q[0] + q[5]] = k
      board[q[4] + q[6]] = r
      board[q[4]] = 0
      excl(mob_set[q[0]], x); excl(mob_set[q[1]], x); excl(mob_set[q[2]], x) # attacked positions, opp moves will set these
      var m = alphabeta(color.oppColor, x, -beta, AB_inf) # full width search with max beta to set really all attack bits
      has_moved[q[0]] = false; has_moved[q[4]] = false
      board[q[0]] = k
      board[q[1]] = 0
      board[q[2]] = 0
      board[q[3]] = 0
      board[q[4]] = r
      if not (x in mob_set[q[0]] or x in mob_set[q[1]] or x in mob_set[q[2]]): # was castling legal?
        m.score *= -1
        if m.score >= beta:
          result.score = beta # or return m.score? should not really matter
          return
        if m.score > alpha:
          alpha = m.score
          result.src = q[0]
          result.dst = q[0] + q[5]
  result.score = alpha

proc king_pos(c: Color): Position =
  var oppK = KingID * c.int
  for i, f in board:
    if f == oppK:
      return i

proc in_check(si: int, col): bool =
  var
    kk: KK
    s = newSeq[KK]()
    #result = false
  kk.si = si
  kk.sf = sign(col.int) * KingID
  while true:
    walkBishop(kk, s)
    result = anyIt(s, it.df.abs == BishopID or it.df.abs == QueenID)
    if result: break
    s.clear
    walkRook(kk, s)
    result = anyIt(s, it.df.abs == RookID or it.df.abs == QueenID)
    if result: break
    s.clear
    walkKnight(kk, s)
    result = anyIt(s, it.df.abs == KnightID)
    if result: break
    s.clear
    walkPawn(kk, s)
    result = anyIt(s, it.df.abs == PawnID)
    break
  #return result

type Flag* {.pure.} = enum
  plain, capture, ep, promotion, procap
  
proc do_move*(p0, p1: Position; silent = false): Flag =
  if board[p1] != VoidID: result = Flag.capture
  if not silent: has_moved[p0] = true
  pjm = -1
  if is_a_pawn(p0) and (p0 - p1).abs == 16:
    pjm = (p0 + p1) div 2
  if (p1 - p0).abs == 2 and is_a_king(p0):
    if col(p1) == 1:
      board[p0 - 1] = board[p0 - 3]
      board[p0 - 3] = VoidID
    else:
      board[p0 + 1] = board[p0 + 4]
      board[p0 + 4] = VoidID
  if base_row(p1) and board[p0].abs == PawnID:
    board[p0] *= QueenID
    result = if result == Flag.capture: Flag.procap else: Flag.promotion
  if is_a_pawn(p0) and board[p1].abs == VoidID and (p1 - p0).odd:
    result = Flag.ep
    board[p1 - sign(board[p0]) * 8] = VoidID
  board[p1] = board[p0]
  board[p0] = VoidID
  
proc tag*(si: int): KKS =
  var kk: KK
  kk.sf = board[si]
  let color = sign(kk.sf).Color
  kk.si = si
  kk.s = 0 # for walkPawn() ep
  var s = newSeq[KK]()
  if pjm > 0:
    incl(mob_set[pjm], 0) # next opp move can do e_p capture
  case kk.sf.abs:
    of PawnID: walkPawn(kk, s)
    of KnightID: walkKnight(kk, s)
    of BishopID: walkBishop(kk, s)
    of RookID: walkRook(kk, s)
    of QueenID: walkBishop(kk, s); walkRook(kk, s)
    of KingID: walkKing(kk, s)
    else: discard
  if si == 3 or si == 3 + 7 * 8:
    const # king, void, void, void, rook, king_delta, rook_delta
      Q = [[3, 2, 1, 1, 0, -2, 2], [3, 4, 5, 6, 7, 2, -3]]
    let
      k = WKing * color.int
      r = WRook * color.int
    for i in 0..1: # castlings both sides
      var q = Q[i]
      if color == Black:
        for j in 0..4:
          q[j] += 7 * 8
      if board[q[0]] == k and board[q[1]] == 0 and board[q[2]] == 0 and board[q[3]] == 0 and board[q[4]] == r and
        not (has_moved[q[0]] or has_moved[q[4]]):
        if not (in_check(q[1], color) or in_check(q[2], color)):
          kk.di = q[0] + q[5]
          s.add kk
  var backup = board
  for el in s.mitems:
    discard do_move(el.si, el.di, silent = true)
    el.s = if in_check(king_pos(color), color): -1 else: 0
    board = backup
  keepIf(s, proc(el: KK): bool = el.s == 0)
  if pjm > 0:
    excl(mob_set[pjm], 0)
  return s

proc move_is_valid*(si, di: int): bool =
  if not (sign(board[si]).Color == White): return false
  for m in tag(si):
    if m.di == di: return true
  false

const
  FigStr = ["  ", "  ", "N_", "B_", "R_", "Q_", "K_"]

proc col_str(c: Col): char = char('H'.int - c.int)

proc row_str(c: Col): char = char('1'.int + c.int)

proc getBoard*: Board =
  result = board

# call this after do_move()
proc move_to_str*(si, di: Position; flag: Flag): string =
  if true: # move_is_valid(si, di): # avoid unnecessary expensive test
    if board[di].abs == KingID and (di - si).abs == 2:
      result = if col(di) == 1: "o-o" else: "o-o-o"
    else:
      result = (FigStr[board[di].abs])
      result.add(col_str(col(si)))
      result.add(row_str(row(si)))
      result.add(if flag == Flag.capture or flag == Flag.procap: 'x' else: '-')
      result.add(col_str(col(di)))
      result.add(row_str(row(di)))
      if flag == Flag.ep or flag == Flag.procap:
        result.add(" e.p.")
    if in_check(king_pos((-sign(board[di])).Color), -sign(board[di])):
      result.add(" +")
  else:
    result = "invalid move"

const
  Ply = 5

proc reply*(): Move =
  var depth = 0
  ev_counter = 0
  if checkmate_depth >= 0:
    while depth < Ply:
      inc depth
      if pjm > 0: incl(mob_set[pjm], depth) # next opp move can do e_p capture
      result = alphabeta(Black, depth, -AB_Inf, AB_inf)
      if pjm > 0: excl(mob_set[pjm], depth)
      if result.score.abs > SureCheckmate: break
  else:
    depth = Ply - 1
    var start_time = cpuTime()
    while depth < Ply + 1: # max 2 times
      inc depth
      if pjm > 0: incl(mob_set[pjm], depth)
      result = alphabeta(Black, depth, -AB_Inf, AB_inf)
      if pjm > 0: excl(mob_set[pjm], depth)
      if result.score.abs > SureCheckmate: break
      if cpuTime() - start_time > 0.2: break
  if result.score.abs > SureCheckmate:
    checkmate_depth = depth
  result.checkmate_depth = checkmate_depth div 2 - 2
  echo "calls of evaluate: ", ev_counter
  echo "depth: ", depth

#proc set_board(f: FigureID; c, r: Position) = board[c + r * 8] = f

#proc set_happyness(f: FigureID; c, r: Position; h: int) = freedom[f][c + r * 8] = h

initPawn(White)
initPawn(Black)
initBishop()
initKnight()
initKing()
initRook()
board = Setup
checkmate_depth = -1
#set_board(WPawn, BE, B5)
#set_happyness(PawnID, BE, B5, 75)

when isMainModule:
  echo "use board.nim"

