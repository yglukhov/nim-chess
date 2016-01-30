import nimx.window, nimx.view, nimx.context, nimx.font, nimx.view_event_handling

from engine import Board, getBoard, do_move, reply, tag, move_to_str, move_is_valid, Flag, SureCheckmate


type BoardView = ref object of View
# some more cleanup is necessary!

const # unicode font chars
  Figures: array[-6..6, string] = ["\xe2\x99\x9A", "\xe2\x99\x9B", "\xe2\x99\x9C", "\xe2\x99\x9D", "\xe2\x99\x9E", "\xe2\x99\x9F", "",
    "\xe2\x99\x99", "\xe2\x99\x98", "\xe2\x99\x97", "\xe2\x99\x96", "\xe2\x99\x95", "\xe2\x99\x94"]

var
  firstclickx = -1
  firstclicky = -1

proc rot180(b: Board): Board =
  for i, f in b:
    result[63 - i] = f

var tagged: Board

let chessFont = newFontWithFace("Arial Unicode", 64)


method draw(v: BoardView; r: Rect) =
  var
    w, h: cint
    width = v.bounds.width
    height = v.bounds.height
    w8 = width / 8
    h8 = height / 8
    board = rot180(getBoard())
#    layout: pango.Layout
#    desc: pango.FontDescription
    i: cint
    c = currentContext()
  for i, f in board:
    var h = if tagged[i] > 0: 0.2 else: 0
    if i mod 2 != (i div 8) mod 2:
      c.fillColor = newColor(0.9, 0.9, 0.9 - h, 1)
    else:
      c.fillColor = newColor(1, 1, 1 - h, 1)
    c.drawRect(newRect((i mod 8).Coord * w8, (i div 8).Coord * h8, w8, h8))
    if tagged[i] < 0:
      c.fillColor = newColor(0, 0, 0, 0.5)
    else:
      c.fillColor = newColor(0, 0, 0, 1)
    c.drawText(chessFont, newPoint((i mod 8).Coord * w8, (i div 8).float * h8), Figures[f])

method onMouseDown(v: BoardView; event: var Event): bool =
  v.setNeedsDisplay()
  var p0, p1, x, y: int
  var msg: string
  for i in 0 ..< tagged.len: tagged[i] = 0
  if firstclickx == -1:
    firstclickx = int(event.localPosition.x) # event.x is cdouble
    firstclicky = int(event.localPosition.y)
    x = int(firstclickx / (v.bounds.width / 8).int)
    y = int(firstclicky / (v.bounds.height / 8).int)
    p0 = 63 - (x + y * 8)
    for i in tag(p0):
      tagged[63 - i.di] = 1
    tagged[63 - p0] = -1
  else:
    x = int(firstclickx / (v.bounds.width / 8).int)
    y = int(firstclicky / (v.bounds.height / 8).int)
    p0 = 63 - (x + y * 8)
    x = int(int(event.localPosition.x) / (v.bounds.width / 8).int)
    y = int(int(event.localPosition.y) / (v.bounds.height / 8).int)
    p1 = 63 - (x + y * 8)
    if p0 == p1:
      firstclickx = -1
      return false
    if not move_is_valid(p0, p1):
      v.window.title = "invalid move, ignored."
      firstclickx = -1
      return false
    var flag = do_move(p0, p1)
    v.window.title= move_to_str(p0, p1, flag)
    firstclickx = -1
    var m = reply()
    flag = do_move(m.src, m.dst)
    msg = move_to_str(m.src, m.dst, flag) & " (score: " & $m.score & ")"
    if m.score > SureCheckmate:
      msg &= " mate in " & $m.checkmate_depth
    elif m.score < -SureCheckmate:
      msg &= " computer is mate in " & $m.checkmate_depth
    v.window.title= msg
  return false

proc startApplication =
  var mainWindow = newWindow(newRect(40, 40, 1200, 600))

  mainWindow.title = "Chess"

  let boardView = BoardView.new(mainWindow.bounds)
  boardView.autoresizingMask = { afFlexibleWidth, afFlexibleHeight }
  mainWindow.addSubview(boardView)


  #[]
  var window = window_new()
  var darea = drawing_area_new()
  darea.add_events(EventMask.BUTTON_PRESS_MASK.gint)
  window.add(darea)
  discard g_signal_connect(darea, "draw", g_Callback(onDrawEvent), nil)
  discard g_signal_connect(darea, "button-press-event", g_Callback(onButtonPressEvent), nil)
  discard g_signal_connect(window, "destroy", g_Callback(main_quit), nil)
  window.position = WindowPosition.Center
  window.set_default_size(800, 800)
  window.title = "Plain toy chess game, GTK3 GUI with Unicode chess pieces, coded from scratch in Nim"
  window.show_all
  ]#

when defined js:
    import dom
    dom.window.onload = proc (e: ref TEvent) =
        startApplication()
else:
    startApplication()
    runUntilQuit()
