# nim-chess
Plain chess game, written from scratch, GTK3 GUI with unicode pieces, written in Nim

This is a very plain chess game I wrote just for fun in a few days in Nim.
GUI is GTK3 with chess pieces drawn with unicode font.

You can play only with White pieces against computer.
Computer should reply synchronously in less than one second.

My feeling is that playing strength is not that bad -- depth is 5 plies
with full quiescence search.

Chess engine has 600 lines of code, with move precalculation as known from
gnuchess and well known alpha-beta-pruning. Static evaluation of end nodes is
very simple, and there is nearly no position strategy included currently.
So we may have a chance to win a few games.

Castling and en passant moves should be fully supported, but are untested.
And there is no end of game detection when king is captured.

So there is much room for improvements...

The program should work on Linux boxes. I have added all the necessary
Nim wrapper files to this repository. In principle it should also work
with the Nim GTK3 wrappers from github, but a few minor fixes may be necessary.

Install:

You need the Nim compiler, at least version 0.13 from
http://nim-lang.org/

In your terminal type:

mkdir toychessdir

cd  toychessdir

git clone https://github.com/StefanSalewski/nim-chess

cd nim-chess

nim c -d:release board.nim

./board

Of course you may hack the source code, that is really easy.
Maybe improve playing strength, add command line parameters or extend the GUI.


