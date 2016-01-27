import gtk3, gdk3, glib, gobject, pango, cairo, pango_cairo

from engine import Board, getBoard, do_move, reply, tag, move_to_str, move_is_valid

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

proc drawIt(cr: cairo.Context; widget: Widget) {.cdecl.} =
  const
    Font = "Sans 64"

  var
    w, h: cint
    gdk_window = widget.parent_window
    width: gint = gdk_window.width
    height = gdk_window.height
    w8 = width div 8
    h8 = height div 8
    board = rot180(getBoard())
    layout: pango.Layout
    desc: pango.FontDescription
    i: cint
  for i, f in board:
    var h = if tagged[i] == 1: 0.2 else: 0
    if i mod 2 != (i div 8) mod 2:
      cr.set_source_rgba(0.9, 0.9, 0.9 - h, 1)
    else:
      cr.set_source_rgba(1, 1, 1 - h, 1)
    cr.rectangle(cdouble((i mod 8) * w8), cdouble((i div 8) * h8), w8.cdouble, h8.cdouble)
    cr.fill
  layout = createLayout(cr)
  desc = pango.fontDescriptionFromString(Font)
  desc.absolute_size = min(width, height) / 8 * pango.Scale
  layout.setFontDescription(desc)
  pango.free(desc)
  cr.set_source_rgba(0, 0, 0, 1)
  for i, f in board:
    layout.setText(Figures[f], -1)
    cr.updateLayout(layout)
    layout.getSize(w, h)
    cr.move_to(cdouble((i mod 8) * w8 + w8 div 2 - w div 2 div pango.Scale), cdouble((i div 8) * h8 + h8 div 2 - h div 2 div pango.Scale))
    cr.showLayout(layout)
  gobject_unref(layout)

proc onButtonPressEvent(widget: Widget; event: EventButton; userData: gpointer): gboolean {.cdecl.} =
  var p0, p1, x, y: int
  for i in mitems(tagged): i = 0
  if firstclickx == -1:
    firstclickx = int(event.x) # event.x is cdouble
    firstclicky = int(event.y)
    x = firstclickx div (widget.parent_window.width div 8)
    y = firstclicky div (widget.parent_window.height div 8)
    p0 = 63 - (x + y * 8)
    for i in tag(p0):
      tagged[63 - i.di] = 1
    widget.parent_window.invalidate_rect(gdk3.Rectangle(nil), false)
  else:
    x = firstclickx div (widget.parent_window.width div 8)
    y = firstclicky div (widget.parent_window.height div 8)
    p0 = 63 - (x + y * 8)
    x = int(event.x) div (widget.parent_window.width div 8)
    y = int(event.y) div (widget.parent_window.height div 8)
    p1 = 63 - (x + y * 8)
    if p0 == p1:
      firstclickx = -1
      widget.parent_window.invalidate_rect(gdk3.Rectangle(nil), false)
      return false
    if not move_is_valid(p0, p1):
      cast[gtk3.Window](widget.toplevel).title= "invalid move, ignored." # we have to fix this ugly cast
      firstclickx = -1
      widget.parent_window.invalidate_rect(gdk3.Rectangle(nil), false)
      return false
    cast[gtk3.Window](widget.toplevel).title= move_to_str(p0, p1) # we have to fix this ugly cast
    do_move(p0, p1)
    firstclickx = -1
    widget.parent_window.invalidate_rect(gdk3.Rectangle(nil), false)
    discard gtk3.main_iteration_do(false)
    set_cursor(widget.parent_window, cursor_new_from_name(display_get_default(), "wait"))
    discard gtk3.main_iteration_do(false)
    var m = reply()
    cast[gtk3.Window](widget.toplevel).title= move_to_str(m.src, m.dst) & " (score: " & $m.score & ")" # we have to fix this ugly cast
    do_move(m.src, m.dst)
    set_cursor(widget.parent_window, gdk3.Cursor(nil))
    widget.parent_window.invalidate_rect(gdk3.Rectangle(nil), false)
  return false

proc onDrawEvent(widget: Widget; cr: cairo.Context; userData: gpointer): gboolean {.cdecl.} =
  drawIt(cr, widget)
  return false

proc main_proc =
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

gtk3.init_with_argv()
main_proc()
gtk3.main()
