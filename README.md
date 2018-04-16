!# backgammon

An OCaml implementation of command-line backgammon with an AI trained using reinforcement learning. Play against the AI [here](https://www.jacobh.co.uk/backgammon)!

Backgammon was the first major board game to be successfully attacked with techniques that resemble modern reinforcement learning, by Gerald Tesauro in the early 1990s. A first-hand account of the development of his program, TD-Gammon, can be found [here][2]. A good second-hand summary, including an introduction to the TD-*&lambda;* algorithm on which the program is based, can be found in [1]. Details of some later implementations can be found [here][3] and [here][4].

This implementation uses a closely-related but distinct algorithm. In outline, the general form of the algorithm is as follows.
- Set up a feedforward neural network that takes as input a representation of a board position from the perspective of a particular player, and is intended to output an estimate of that player's "equity", i.e. the probability of that player winning the game (as well as the probabilities of winning or losing a gammon or a backgammon).
- Construct an "amplified" equity estimator, which is allowed to be more expensive than the neural network but should also be more accurate. In the simplest case, the amplified estimator can use 1-ply look-ahead, i.e. consider every possible roll of the dice and calculate the expected equity, as estimated by the neural network itself, once the opponent has played their next move. The amplified estimator should correctly identify who has won (and whether by a gammon or a backgammon) once the game is over.
- Generate a sequence of board positions (by self-play using the amplified estimator, for example), estimate the equity of each position using the amplified estimator, and use these as training examples for the neural network.

The 1-ply look-ahead version of this algorithm can be obtained from as TD-*&lambda;* by making the following modifications.
- Set the time-decay parameter *&lambda;* to zero, i.e. only feed back errors one time step. Tesauro mentions [here][3] that most later development of TD-Gammon used this modification.
- Rather than choosing a single roll of the dice at random, consider every possible roll and take the expected value before feeding back the error.
- Train the neural network once the game is over rather than learning online.

This algorithm cannot be used in quite as general a setting as TD-*&lambda;* itself: it requires us to have perfect knowledge of the environment, in order to consider every possible roll of the dice. But given that this knowledge is available to us, the algorithm offers a number of advantages.
- The averaging should smoothen the training process. Formally, it has a stronger convergence property: with an idealised function approximator instead of the neural network (such as a lookup table), and assuming that every possible board position is reached infinitely many times, the algorithm converges to produce a completely accurate equity estimator *without needing to lower the learning rate* (whereas TD-*&lambda;* only converges if the learning rate tends to zero).
- It is straightforward to plug in a different amplification scheme in place of 1-ply look-ahead, such as Monte Carlo tree search or one of its variants. With such a modification the algorithm may be viewed as a simplified version of [AlphaZero](https://arxiv.org/abs/1712.01815).
- The training of the neural network is decoupled from the process of generating training examples. This makes it possible to use the training examples more effeciently and to apply techniques such as [experience replay](https://arxiv.org/pdf/1312.5602v1.pdf) to further smoothen training. It also simplifies parallelisation of the algorithm.

The implementation uses [tensorflow-ocaml](https://github.com/LaurentMazare/tensorflow-ocaml).

## Experiments

### Training using a handcrafted AI

Tesauro [mentions][2] that with random play, backgammon games often last several hundred or even several thousand moves. This threatens to significantly slow down the initial stages of training when using self-play. This is especially true since we only feed back one time step, so initially the neural network only learns to improve on board positions that are one move away from the end of the game.

Since it is possible to vary the amplified equity estimator scheme in our algorithm, we therefore tried using a handcrafted AI as the amplified equity estimator, at least during the initial stages of training. Our handcrafted AI uses 1-ply look-ahead, but instead of using the neural network, it uses the ratio of the players' [pip counts](https://en.wikipedia.org/wiki/Backgammon) as a heuristic evaluation function. This ratio is a very poor estimate of the probability of winning (except very close to the end of the game), but with look-ahead it produces an AI that is able to implement simple strategies such as capturing and playing safe, preventing the game from lasting a very long time.

We compared three variants of the algorithm for 2,000 training games: using self-play (with 1-ply look-ahead), using only our handcrafted AI, and using a hybrid method in which the handcrafted AI was used for the first 500 training games before switching to self-play. This experiment used a very similar neural network architecture to Tesauro, with a single fully-connected hidden layer of 40 units and sigmoid activation. Only our board encoding is slightly different: in the encoding of the number *n* of a player's counters on a particular point, we replace the condition *n* = 3 by the condition *n* ≥ 3, in an attempt to take advantage of the fact that this indicates that the player will still have a made point after removing a counter; the unit specifying the number of counters on the bar is split in two, one specifying whether any counters are on the bar; and the unit indicating whose turn it is is removed, thereby removing a symmetry of the original representation. For training, we use the [Adam](https://arxiv.org/pdf/1412.6980.pdf) optimisation algorithm, and train on 500 minibatches of size 128 after every 10 games, using a [replay memory](https://arxiv.org/pdf/1312.5602v1.pdf) with a capacity of 50,000 board positions. For testing, after every 10 training games, 100 games were played between an AI that chooses moves using the neural network (with no look-ahead) and the handcrafted AI.

Here are the results, shown as moving averages so as to cancel out the noise.

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
    'self':   faithful_rolling_mean(pd.Series([2, 0, 3, 0, 5, 2, 3, 4, 9, 7, 3, 11, 6, 2, 5, 8, 5, 6, 6, 12, 7, 9, 12, 8, 7, 8, 6, 7, 8, 12, 8, 10, 7, 9, 12, 8, 6, 12, 9, 6, 9, 10, 9, 9, 10, 10, 6, 9, 7, 18, 11, 5, 14, 18, 10, 13, 16, 19, 17, 14, 8, 14, 12, 18, 13, 17, 15, 33, 15, 23, 26, 24, 23, 24, 21, 18, 17, 15, 22, 26, 43, 32, 31, 36, 45, 40, 38, 31, 39, 46, 44, 40, 47, 41, 42, 57, 40, 45, 55, 55, 54, 56, 62, 58, 50, 60, 59, 66, 64, 59, 66, 62, 57, 56, 59, 63, 62, 57, 65, 55, 59, 60, 56, 68, 66, 68, 62, 62, 65, 57, 64, 63, 58, 61, 61, 67, 69, 63, 68, 69, 72, 70, 68, 70, 71, 70, 73, 75, 70, 72, 72, 69, 70, 73, 62, 74, 80, 73, 64, 71, 71, 77, 72, 71, 73, 73, 69, 76, 67, 74, 74, 73, 73, 73, 75, 73, 75, 67, 73, 76, 75, 83, 66, 74, 77, 77, 68, 75, 80, 70, 67, 75, 68, 77, 67, 74, 70, 75, 75, 73, 73, 68, 76, 75, 83, 78, 75, 76, 81, 81, 74, 76]) / 100),
    'pcr':    faithful_rolling_mean(pd.Series([33, 34, 44, 40, 45, 44, 46, 46, 40, 54, 51, 45, 54, 48, 41, 50, 59, 48, 55, 55, 63, 55, 56, 47, 54, 47, 56, 49, 51, 54, 52, 57, 43, 54, 49, 51, 56, 43, 51, 61, 47, 45, 55, 50, 53, 47, 43, 37, 50, 48, 49, 47, 47, 38, 48, 50, 51, 48, 50, 52, 45, 49, 36, 42, 57, 52, 50, 51, 49, 49, 43, 40, 52, 48, 47, 49, 45, 47, 53, 45, 46, 49, 49, 44, 39, 47, 53, 47, 41, 44, 41, 51, 43, 43, 60, 50, 51, 50, 48, 55, 53, 45, 52, 54, 52, 45, 45, 50, 48, 45, 47, 53, 48, 44, 54, 45, 51, 54, 59, 51, 42, 52, 51, 49, 42, 58, 53, 57, 49, 53, 53, 50, 35, 45, 42, 56, 42, 51, 45, 43, 48, 57, 49, 53, 42, 44, 46, 52, 57, 49, 39, 49, 55, 50, 48, 43, 49, 46, 50, 52, 46, 60, 50, 55, 52, 50, 52, 46, 42, 53, 45, 57, 48, 51, 53, 52, 43, 54, 45, 45, 48, 52, 52, 52, 54, 51, 52, 55, 44, 49, 53, 47, 52, 40, 52, 48, 51, 47, 50, 42, 54, 46, 45, 49, 48, 52, 38, 48, 41, 45, 56, 54]) / 100),
    'hybrid': faithful_rolling_mean(pd.Series([23, 29, 47, 42, 48, 44, 50, 46, 52, 48, 46, 50, 49, 50, 40, 51, 54, 46, 50, 47, 48, 48, 48, 40, 45, 56, 48, 46, 50, 48, 47, 50, 51, 55, 50, 42, 50, 45, 47, 48, 40, 50, 46, 52, 51, 46, 45, 48, 43, 50, 45, 42, 43, 39, 42, 49, 35, 50, 47, 43, 53, 54, 60, 60, 58, 46, 67, 49, 54, 56, 53, 63, 46, 60, 55, 58, 62, 60, 60, 62, 55, 64, 61, 63, 61, 58, 68, 68, 61, 62, 66, 64, 76, 66, 63, 62, 63, 71, 62, 62, 63, 69, 68, 65, 70, 68, 69, 78, 74, 60, 75, 72, 66, 63, 62, 63, 73, 70, 55, 63, 79, 65, 69, 66, 74, 69, 56, 59, 64, 60, 69, 67, 61, 74, 65, 69, 65, 65, 67, 71, 74, 71, 64, 72, 71, 65, 66, 61, 67, 70, 68, 67, 75, 74, 71, 62, 61, 70, 67, 67, 70, 76, 65, 72, 71, 72, 67, 74, 77, 77, 67, 71, 65, 75, 75, 73, 71, 62, 75, 64, 73, 76, 70, 69, 70, 64, 78, 78, 76, 77, 69, 73, 74, 72, 66, 69, 72, 77, 77, 69, 74, 76, 75, 71, 72, 76, 76, 74, 72, 79, 73, 71]) / 100),
},  columns = ['pcr', 'self', 'hybrid'])
df = df.rename(columns={
    'self': 'Trained using self-play',
    'pcr': 'Trained using handcrafted AI',
    'hybrid': 'Hybrid\n(self-play after 500 games)',
})
df.index = df.index * 10
plt.rcParams.update({'font.size': 12})
ax = df.plot(figsize=(8, 5), grid=True, title='Test games won against handcrafted AI')
ax.set_xlabel('Training games played')
ax.set_ylabel('250 training game-wide moving average')
ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: '{:.0%}'.format(y))) 
plt.show()
](handcrafted_experiment.png)

As expected, training using the handcrafted AI very quickly produces something with reasonable performance, but this performance plateaus at 50%, i.e. it cannot outperform the handcrafted AI itself. The hybrid method clearly improves upon this, while training using self-play starts out much more slowly. However, the self-play method catches up with the hybrid method in under 1,500 training games. Interestingly, in this particular run, after the full 2,000 games, the AI produced using self-play was slightly better than the AI produced using the hybrid method, winning 52,024 games in a 100,000-game head-to-head. While this difference could be put down to noise in the training process, it certainly appears that any early advantage gained by using the hybrid method has all but disappeared after 2,000 training games. Our best explanation for this is that, while the handcrafted AI is able to make reasonable moves, its equity estimates are very poor, so the hybrid method has a lot of "unlearning" to do after it switches to self-play.

However, the graph does not show the length of the early training games and the time saved as a result. Therefore the best approach may be to use the handcrafted AI for a very small number of initial training games (a single game, say), to put the AI on the right track, before switching to self-play. Since the benefit appears to be modest, in the remaining experiments we choose to forgo the use of handcrafted AI entirely for the sake of simplicity.

Finally, we note that our AI performs well after relatively few training games. Tesauro [notes][2] that TD-Gammon achieves an intermediate level of play after 200,000 training games. While we have unfortunately not yet implemented a way to test our AI against a shared benchmark, our self-play method stops improving after a few thousand games. However, this difference is somewhat of an illusion, as our algorithm considers around a few hundred times as many positions in its 1-ply look-ahead as TD-Gammon does, making the performance more comparable.

### Coming soon...

- An experiment between different neural network architectures using an expanded board representation: using 1 hidden layer of size 40, using 2 hidden layers of size 80, and using 5 hidden layers of size 400 (with relu activation in the final case).
- An experiment between 1-ply look-ahead and some form of Monte Carlo tree search guided by the output of the neural network

## Reference

[1] Richard S. Sutton and Andrew G. Barto. *Reinforcement Learning: An Introduction.*
[2]: http://www.bkgm.com/articles/tesauro/tdl.html
[3]: http://www.scholarpedia.org/article/User:Gerald_Tesauro/Proposed/Td-gammon
[4]: https://www.cs.cornell.edu/boom/2001sp/Tsinteris/gammon.htm