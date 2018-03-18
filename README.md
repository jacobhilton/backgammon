# backgammon

An OCaml implementation of command-line backgammon with an AI trained using reinforcement learning.

The basic reinforcement learning algorithm is loosely based on the classic [TD-Gammon](http://www.scholarpedia.org/article/User:Gerald_Tesauro/Proposed/Td-gammon) algorithm, with a few differences:
- The network is trained to estimate the chance of winning from a given position by looking ahead to refine its own estimate - this is similar to the case *λ* = 0 in the original algorithm.
- As well as training by playing against itself, the network can also be trained by watching a hand-crafted AI play against itself, in an attempt to speed up the early stages of training. The hand-crafted AI used looks ahead to the next player's turn and uses the ratio of the players' pip counts as a heuristic evaluation function.
- The board is encoded slightly differently: the number *n* of counters on a particular point is encoded using the condition *n* ≥ 3 rather than the condition *n* = 3, in an attempt to take advantage of the fact that this indicates that the player will still have a made point after removing a counter; also, the unit indicating whose turn it is is removed, thereby removing a symmetry of the original representation.

This is currently work in progress. Once the basic setup is working I intend to adapt the algorithm to include ideas from more recent progress in reinforcement learning, such as:
- Using experience replay to smoothen training
- Replacing the exhaustive fixed-depth tree search with a Monte Carlo tree search guided by the output of the neural network
- Using a different neural network architecture

The implementation uses [tensorflow-ocaml](https://github.com/LaurentMazare/tensorflow-ocaml).

Sample output:

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