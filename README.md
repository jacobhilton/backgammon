# backgammon

An OCaml implementation of command-line backgammon. Sample output:

```
$ _build/default/main.exe -X human -O '(pip_count_ratio (look_ahead 2))' -show-board
Player X to start.

Os borne off: none
  24   23   22   21   20   19        18   17   16   15   14   13
  -------------------------------------------------------------------
  |  v    v    v    v    v    v  |   |  v    v    v    v    v    v  |
  |                              |   |                              |
  |  X                        O  |   |       O                   X  |
  |  X                        O  |   |       O                   X  |
  |                           O  |   |       O                   X  |
  |                           O  |   |                           X  |
  |                           O  |   |                           X  |
  |                              |   |                              |
  |                              |   |                              |
  |                              |   |                              |
  |------------------------------|   |------------------------------|
  |                              |   |                              |
  |                              |   |                              |
  |                              |   |                              |
  |                           X  |   |                           O  |
  |                           X  |   |                           O  |
  |                           X  |   |       X                   O  |
  |  O                        X  |   |       X                   O  |
  |  O                        X  |   |       X                   O  |
  |                              |   |                              |
  |  ^    ^    ^    ^    ^    ^  |   |  ^    ^    ^    ^    ^    ^  |
  -------------------------------------------------------------------
     1    2    3    4    5    6         7    8    9   10   11   12
     Xs borne off: none

Move 1: player X rolls a 5-3.
Your move:
```

There is a "pip count ratio" AI which performs an expectiminimax calculation using the ratio of the players' pip count ratios as a heuristic evaluation function.

There is also an implementation of a version of [TD-Gammon](http://www.scholarpedia.org/article/User:Gerald_Tesauro/Proposed/Td-gammon) using [tensorflow-ocaml](https://github.com/LaurentMazare/tensorflow-ocaml) which is work in progress.