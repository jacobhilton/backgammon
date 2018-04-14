# backgammon

An OCaml implementation of command-line backgammon with an AI trained using reinforcement learning.

The basic reinforcement learning algorithm is loosely based on the classic [TD-Gammon](http://www.scholarpedia.org/article/User:Gerald_Tesauro/Proposed/Td-gammon) algorithm, with a few differences:
- The network is trained to estimate the chance of winning from a given position by looking ahead to refine its own estimate - this is similar to the case *λ* = 0 in the original algorithm.
- As well as training by playing against itself, the network can also be trained by watching a hand-crafted AI play against itself, in an attempt to speed up the early stages of training. The hand-crafted AI used looks ahead to the next player's turn and uses the ratio of the players' pip counts as a heuristic evaluation function.
- The board is encoded slightly differently: the number *n* of counters on a particular point is encoded using the condition *n* ≥ 3 rather than the condition *n* = 3, in an attempt to take advantage of the fact that this indicates that the player will still have a made point after removing a counter; the unit specifying the number of counters on the bar is split in two, one specifying whether any counters are on the bar; and the unit indicating whose turn it is is removed, thereby removing a symmetry of the original representation.

This is currently work in progress. Once the basic setup is working I intend to adapt the algorithm to include ideas from more recent progress in reinforcement learning, such as:
- Using experience replay to smoothen training
- Replacing the exhaustive fixed-depth tree search with a Monte Carlo tree search guided by the output of the neural network
- Using a different neural network architecture
- Using improved optimisation algorithms such as Adam

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

## Method experiment (to be completed)

![
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
def faithful_rolling_mean(series, max_odd_window=25):
    result = series.map(lambda _: np.nan)
    for window in range(max_odd_window, -1, -2):
        result = np.where(np.isnan(result), series.rolling(window, center=True).mean(), result)
    return result[:- (max_odd_window - 1) // 2]
df = pd.DataFrame({
    'pcr':    faithful_rolling_mean(pd.Series([33, 34, 44, 40, 45, 44, 46, 46, 40, 54, 51, 45, 54, 48, 41, 50, 59, 48, 55, 55, 63, 55, 56, 47, 54, 47, 56, 49, 51, 54, 52, 57, 43, 54, 49, 51, 56, 43, 51, 61, 47, 45, 55, 50, 53, 47, 43, 37, 50, 48, 49, 47, 47, 38, 48, 50, 51, 48, 50, 52, 45, 49, 36, 42, 57, 52, 50, 51, 49, 49, 43, 40, 52, 48, 47, 49, 45, 47, 53, 45, 46, 49, 49, 44, 39, 47, 53, 47, 41, 44, 41, 51, 43, 43, 60, 50, 51, 50, 48, 55, 53, 45, 52, 54, 52, 45, 45, 50, 48, 45, 47, 53, 48, 44, 54, 45, 51, 54, 59, 51, 42, 52, 51, 49, 42, 58, 53, 57, 49, 53, 53, 50, 35, 45, 42, 56, 42, 51, 45, 43, 48, 57, 49, 53, 42, 44, 46, 52, 57, 49, 39, 49, 55, 50, 48, 43, 49, 46, 50, 52, 46, 60, 50, 55, 52, 50, 52, 46, 42, 53, 45, 57, 48, 51, 53, 52, 43, 54, 45, 45, 48, 52, 52, 52, 54, 51, 52, 55, 44, 49, 53, 47, 52, 40, 52, 48, 51, 47, 50, 42, 54, 46, 45, 49, 48, 52, 38, 48, 41, 45, 56, 54]) / 100),
    'self':   faithful_rolling_mean(pd.Series([2, 0, 3, 0, 5, 2, 3, 4, 9, 7, 3, 11, 6, 2, 5, 8, 5, 6, 6, 12, 7, 9, 12, 8, 7, 8, 6, 7, 8, 12, 8, 10, 7, 9, 12, 8, 6, 12, 9, 6, 9, 10, 9, 9, 10, 10, 6, 9, 7, 18, 11, 5, 14, 18, 10, 13, 16, 19, 17, 14, 8, 14, 12, 18, 13, 17, 15, 33, 15, 23, 26, 24, 23, 24, 21, 18, 17, 15, 22, 26, 43, 32, 31, 36, 45, 40, 38, 31, 39, 46, 44, 40, 47, 41, 42, 57, 40, 45, 55, 55, 54, 56, 62, 58, 50, 60, 59, 66, 64, 59, 66, 62, 57, 56, 59, 63, 62, 57, 65, 55, 59, 60, 56, 68, 66, 68, 62, 62, 65, 57, 64, 63, 58, 61, 61, 67, 69, 63, 68, 69, 72, 70, 68, 70, 71, 70, 73, 75, 70, 72, 72, 69, 70, 73, 62, 74, 80, 73, 64, 71, 71, 77, 72, 71, 73, 73, 69, 76, 67, 74, 74, 73, 73, 73, 75, 73, 75, 67, 73, 76, 75, 83, 66, 74, 77, 77, 68, 75, 80, 70, 67, 75, 68, 77, 67, 74, 70, 75, 75, 73, 73, 68, 76, 75, 83, 78, 75, 76, 81, 81, 74, 76]) / 100),
    'hybrid': faithful_rolling_mean(pd.Series([23, 29, 47, 42, 48, 44, 50, 46, 52, 48, 46, 50, 49, 50, 40, 51, 54, 46, 50, 47, 48, 48, 48, 40, 45, 56, 48, 46, 50, 48, 47, 50, 51, 55, 50, 42, 50, 45, 47, 48, 40, 50, 46, 52, 51, 46, 45, 48, 43, 50, 45, 42, 43, 39, 42, 49, 35, 50, 47, 43, 53, 54, 60, 60, 58, 46, 67, 49, 54, 56, 53, 63, 46, 60, 55, 58, 62, 60, 60, 62, 55, 64, 61, 63, 61, 58, 68, 68, 61, 62, 66, 64, 76, 66, 63, 62, 63, 71, 62, 62, 63, 69, 68, 65, 70, 68, 69, 78, 74, 60, 75, 72, 66, 63, 62, 63, 73, 70, 55, 63, 79, 65, 69, 66, 74, 69, 56, 59, 64, 60, 69, 67, 61, 74, 65, 69, 65, 65, 67, 71, 74, 71, 64, 72, 71, 65, 66, 61, 67, 70, 68, 67, 75, 74, 71, 62, 61, 70, 67, 67, 70, 76, 65, 72, 71, 72, 67, 74, 77, 77, 67, 71, 65, 75, 75, 73, 71, 62, 75, 64, 73, 76, 70, 69, 70, 64, 78, 78, 76, 77, 69, 73, 74, 72, 66, 69, 72, 77, 77, 69, 74, 76, 75, 71, 72, 76, 76, 74, 72, 79, 73, 71]) / 100),
},  columns = ['pcr', 'self', 'hybrid'])
df = df.rename(columns={
    'pcr': 'Trained on handcrafted AI',
    'self': 'Self-trained',
    'hybrid': 'Hybrid\n(self-trained after 500 games)',
})
df.index = df.index * 10
plt.rcParams.update({'font.size': 12})
ax = df.plot(figsize=(8, 5), grid=True, title='Test games won against handcrafted AI')
ax.set_xlabel('Training games played')
ax.set_ylabel('250 training game-wide moving average')
ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: '{:.0%}'.format(y))) 
plt.show()
](method_experiment.png)

Self actually slightly better (52024/100000) but could be due to noise in the training process and perhaps you should compare 2500 vs 2000.
Describe no lookahead, problem with too many moves, pcr wrongness.