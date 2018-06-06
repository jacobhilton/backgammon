# backgammon

An OCaml implementation of command-line backgammon with a bot trained using reinforcement learning.

**Play against the bot [here](https://www.jacobh.co.uk/backgammon)!**

The current version plays about as well as the top human players using a single neural network to evaluate board positions with no look-ahead or other modifications (achieving a 42–43% win rate against GNU Backgammon in single-game match play).

## How it works

Backgammon was the first major board game to be successfully attacked with techniques that resemble modern reinforcement learning, by Gerald Tesauro in the early 1990s. A first-hand account of the development of his program, TD-Gammon, can be found [here][2]. A good second-hand summary, including an introduction to the TD(*&lambda;*) algorithm on which the program is based, can be found in [1]. Details of some later (re-)implementations can be found [here][3] and [here][4].

Our implementation uses a closely-related but distinct algorithm. In outline, the general form of our algorithm is as follows.
- Set up a feedforward neural network that takes as input a representation of a board position from the perspective of a particular player, and is intended to output an estimate of that player's "equity", i.e. the probability of that player winning the game (one may additionally ask for the probabilities of more specific outcomes, i.e. winning or losing a gammon or a backgammon).
- Construct an "amplified" equity estimator, which is allowed to be more expensive than the neural network but should also be more accurate. In the simplest case, the amplified estimator can use 1-ply look-ahead, i.e. consider every possible roll of the dice and calculate the expected equity, as estimated by the neural network itself, once the opponent has played their next move. The amplified estimator should correctly identify who has won (and whether by a gammon or a backgammon) once the game is over.
- Generate a sequence of board positions (using every position evaluated by the amplified estimator during self-play, for example), evaluate each position using the amplified estimator, and use these as training examples for the neural network.

One may view the 1-ply look-ahead version of this algorithm as being obtained from TD(*&lambda;*) by making the following modifications.
- Set the time-decay parameter *&lambda;* to zero, i.e. only feed back errors one time step. Tesauro mentions [here][3] that most later development of TD-Gammon used this modification.
- Rather than choosing a single roll of the dice at random, consider every possible roll and take the expected value before feeding back the error.
- Train the neural network between games rather than learning online.

This algorithm cannot be used in quite as general a setting as TD(*&lambda;*) itself: it requires us to have perfect knowledge of the environment, in order to consider every possible roll of the dice. But given that this knowledge is available in backgammon, the algorithm offers a number of advantages.
- The averaging should smoothen the training process. Formally, it provides a stronger convergence property: with an idealised function approximator instead of the neural network (such as a lookup table), and assuming that every possible board position is reached infinitely many times, the algorithm converges to produce a completely accurate equity estimator *without needing to lower the learning rate* (whereas TD(*&lambda;*) only converges if the learning rate tends to zero).
- It is straightforward to use a different amplification scheme in place of 1-ply look-ahead, such as Monte Carlo tree search or one of its variants. With such a modification the algorithm may be viewed as a simplified version of [AlphaZero](https://arxiv.org/abs/1712.01815).
- The training of the neural network is decoupled from the process of generating training examples. This makes it possible to use the training examples more efficiently and to apply techniques such as [experience replay](https://arxiv.org/pdf/1312.5602.pdf) to further smoothen training. It also simplifies parallelisation of the algorithm.

The implementation uses [tensorflow-ocaml](https://github.com/LaurentMazare/tensorflow-ocaml).

## Experiments

### Training using a handcrafted bot

Tesauro [remarks][2] that with random play, backgammon games often last several hundred or even several thousand moves. This threatens to significantly slow down the initial stages of training when using self-play. This is especially true since we only feed back one time step, so initially the neural network only learns to improve on board positions that are one move away from the end of the game.

Since it is possible to change the amplified equity estimator in our algorithm, we therefore tried using a handcrafted bot as the amplified equity estimator, at least during the initial stages of training. Our handcrafted bot uses 1-ply look-ahead, but instead of using the neural network, it uses the ratio of the players' [pip counts](https://en.wikipedia.org/wiki/Backgammon) as a heuristic evaluation function. This ratio is a very poor estimate of the probability of winning, but with look-ahead it produces a bot that is able to implement simple strategies such as capturing and playing safe, preventing the game from lasting a very long time. We refer to this bot as the "pip count ratio bot".

We compared three variants of the algorithm for 2,000 training games: using self-play (with 1-ply look-ahead), using only the pip count ratio bot, and using a hybrid method in which the pip count ratio bot was used for the first 500 training games before switching to self-play. This experiment used a very similar neural network architecture to Tesauro, with a single fully-connected hidden layer of 40 units and sigmoid activation. Only our board encoding is slightly different: in the encoding of the number *n* of a player's counters on a particular point, we replace the condition *n* = 3 by the condition *n* ≥ 3, in an attempt to take advantage of the fact that this indicates that the player will still have a made point after removing a counter; the unit specifying the number of counters on the bar is split in two, one specifying whether any counters are on the bar; and the unit indicating whose turn it is is removed, thereby removing a symmetry of the original representation. For training, we use the [Adam](https://arxiv.org/pdf/1412.6980.pdf) optimisation algorithm, and train on 500 minibatches of size 128 after every 10 games, using a [replay memory](https://arxiv.org/pdf/1312.5602.pdf) with a capacity of 50,000 board positions. For testing, after every 10 training games, 100 games were played between a bot that chooses moves using the neural network (with no look-ahead) and the pip count ratio bot.

Here are the results, with moving averages displayed in order to cancel out some of the noise.

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
    'self': faithful_rolling_mean(pd.Series([2, 0, 3, 0, 5, 2, 3, 4, 9, 7, 3, 11, 6, 2, 5, 8, 5, 6, 6, 12, 7, 9, 12, 8, 7, 8, 6, 7, 8, 12, 8, 10, 7, 9, 12, 8, 6, 12, 9, 6, 9, 10, 9, 9, 10, 10, 6, 9, 7, 18, 11, 5, 14, 18, 10, 13, 16, 19, 17, 14, 8, 14, 12, 18, 13, 17, 15, 33, 15, 23, 26, 24, 23, 24, 21, 18, 17, 15, 22, 26, 43, 32, 31, 36, 45, 40, 38, 31, 39, 46, 44, 40, 47, 41, 42, 57, 40, 45, 55, 55, 54, 56, 62, 58, 50, 60, 59, 66, 64, 59, 66, 62, 57, 56, 59, 63, 62, 57, 65, 55, 59, 60, 56, 68, 66, 68, 62, 62, 65, 57, 64, 63, 58, 61, 61, 67, 69, 63, 68, 69, 72, 70, 68, 70, 71, 70, 73, 75, 70, 72, 72, 69, 70, 73, 62, 74, 80, 73, 64, 71, 71, 77, 72, 71, 73, 73, 69, 76, 67, 74, 74, 73, 73, 73, 75, 73, 75, 67, 73, 76, 75, 83, 66, 74, 77, 77, 68, 75, 80, 70, 67, 75, 68, 77, 67, 74, 70, 75, 75, 73, 73, 68, 76, 75, 83, 78, 75, 76, 81, 81, 74, 76]) / 100),
    'pcr': faithful_rolling_mean(pd.Series([33, 34, 44, 40, 45, 44, 46, 46, 40, 54, 51, 45, 54, 48, 41, 50, 59, 48, 55, 55, 63, 55, 56, 47, 54, 47, 56, 49, 51, 54, 52, 57, 43, 54, 49, 51, 56, 43, 51, 61, 47, 45, 55, 50, 53, 47, 43, 37, 50, 48, 49, 47, 47, 38, 48, 50, 51, 48, 50, 52, 45, 49, 36, 42, 57, 52, 50, 51, 49, 49, 43, 40, 52, 48, 47, 49, 45, 47, 53, 45, 46, 49, 49, 44, 39, 47, 53, 47, 41, 44, 41, 51, 43, 43, 60, 50, 51, 50, 48, 55, 53, 45, 52, 54, 52, 45, 45, 50, 48, 45, 47, 53, 48, 44, 54, 45, 51, 54, 59, 51, 42, 52, 51, 49, 42, 58, 53, 57, 49, 53, 53, 50, 35, 45, 42, 56, 42, 51, 45, 43, 48, 57, 49, 53, 42, 44, 46, 52, 57, 49, 39, 49, 55, 50, 48, 43, 49, 46, 50, 52, 46, 60, 50, 55, 52, 50, 52, 46, 42, 53, 45, 57, 48, 51, 53, 52, 43, 54, 45, 45, 48, 52, 52, 52, 54, 51, 52, 55, 44, 49, 53, 47, 52, 40, 52, 48, 51, 47, 50, 42, 54, 46, 45, 49, 48, 52, 38, 48, 41, 45, 56, 54]) / 100),
    'hybrid': faithful_rolling_mean(pd.Series([23, 29, 47, 42, 48, 44, 50, 46, 52, 48, 46, 50, 49, 50, 40, 51, 54, 46, 50, 47, 48, 48, 48, 40, 45, 56, 48, 46, 50, 48, 47, 50, 51, 55, 50, 42, 50, 45, 47, 48, 40, 50, 46, 52, 51, 46, 45, 48, 43, 50, 45, 42, 43, 39, 42, 49, 35, 50, 47, 43, 53, 54, 60, 60, 58, 46, 67, 49, 54, 56, 53, 63, 46, 60, 55, 58, 62, 60, 60, 62, 55, 64, 61, 63, 61, 58, 68, 68, 61, 62, 66, 64, 76, 66, 63, 62, 63, 71, 62, 62, 63, 69, 68, 65, 70, 68, 69, 78, 74, 60, 75, 72, 66, 63, 62, 63, 73, 70, 55, 63, 79, 65, 69, 66, 74, 69, 56, 59, 64, 60, 69, 67, 61, 74, 65, 69, 65, 65, 67, 71, 74, 71, 64, 72, 71, 65, 66, 61, 67, 70, 68, 67, 75, 74, 71, 62, 61, 70, 67, 67, 70, 76, 65, 72, 71, 72, 67, 74, 77, 77, 67, 71, 65, 75, 75, 73, 71, 62, 75, 64, 73, 76, 70, 69, 70, 64, 78, 78, 76, 77, 69, 73, 74, 72, 66, 69, 72, 77, 77, 69, 74, 76, 75, 71, 72, 76, 76, 74, 72, 79, 73, 71]) / 100),
},  columns = ['pcr', 'self', 'hybrid'])
df = df.rename(columns={
    'self': 'Trained using self-play',
    'pcr': 'Trained using pip count ratio bot',
    'hybrid': 'Hybrid\n(self-play after 500 games)',
})
df.index = df.index * 10
plt.rcParams.update({'font.size': 12})
ax = df.plot(figsize=(8, 5), grid=True, title='Test games won against pip count ratio bot')
ax.set_xlabel('Training games played')
ax.set_ylabel('250 training game-wide moving average')
ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: '{:.0%}'.format(y)))
plt.show()
](handcrafted_experiment.png)

As expected, training using the pip count ratio bot very quickly produces something with reasonable performance, but this performance plateaus at 50%, since naturally it cannot outperform the pip count ratio bot itself. The hybrid method clearly improves upon this, while training using self-play starts out much more slowly. However, the self-play method catches up with the hybrid method in under 1,500 training games. Interestingly, in this particular run, after the full 2,000 games, the bot produced using self-play was slightly better than the bot produced using the hybrid method, winning 52,024 games in a 100,000-game head-to-head. While this difference could be put down to noise in the training process, it certainly appears that any early advantage gained by using the hybrid method is at best modest after 2,000 training games. Our explanation for this is that, while the pip count ratio bot is able to make reasonable moves, its equity estimates are very poor, so the hybrid method has a lot of "unlearning" to do after it switches to self-play.

Despite those remarks, the graph does not show the length of the early training games and the time saved as a result. Therefore the best approach may be to use the pip count ratio bot for a very small number of initial training games (a single game, say), to put the bot on the right track, before switching to self-play. Since the benefit appears to be modest, in our remaining experiments we choose to forgo the use of the pip count ratio bot entirely for the sake of simplicity. Nonetheless, the general idea could be useful in other reinforcement learning settings.

### Increasing the size of the neural network

We studied the effect of increasing the size of the neural network on performance. As part of this we introduced an expanded board representation, with additional nodes specifying whether the number of counters of a player on a point is at greater than or equal to 4, 5 and 6, and further additional nodes representing the number of counters of a player on the bar and the number of counters that a player has borne off. This expanded representation has a total of 326 rather than 198 nodes.

We tested three different neural network architectures:
- with 1 hidden layer of size 40, sigmoid activation, and the same board representation as before;
- with 2 hidden layers of size 80, sigmoid activation, and the expanded board representation;
- and with 5 hidden layers of size 400, relu activation, and the expanded board representation.

100 test games were played after every 10 training games between a bot that chooses moves using the neural network and a bot that chooses moves using a fully-trained neural network with the first architecture (both with no look-ahead).

Here are the results, again with moving averages displayed.

![
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
def faithful_rolling_mean(series, max_odd_window=49):
    result = series.map(lambda _: np.nan)
    for window in range(max_odd_window, -1, -2):
        result = np.where(np.isnan(result), series.rolling(window, center=True).mean(), result)
    return result[:- (max_odd_window - 1) // 2]
df = pd.DataFrame({
    'small': faithful_rolling_mean(pd.Series([1, 0, 3, 2, 1, 2, 1, 0, 0, 1, 1, 0, 3, 3, 0, 1, 4, 5, 6, 4, 5, 3, 3, 5, 5, 10, 4, 4, 6, 11, 8, 9, 6, 7, 5, 7, 7, 7, 7, 6, 9, 14, 9, 9, 7, 9, 16, 8, 7, 6, 12, 10, 9, 7, 11, 11, 18, 10, 13, 13, 15, 19, 13, 19, 13, 9, 17, 14, 19, 10, 12, 16, 16, 16, 11, 20, 16, 15, 15, 19, 18, 20, 18, 9, 17, 19, 23, 23, 24, 14, 15, 22, 25, 26, 25, 14, 21, 21, 24, 25, 28, 32, 25, 32, 28, 29, 25, 31, 28, 34, 36, 28, 38, 38, 27, 30, 27, 34, 39, 37, 29, 38, 30, 36, 37, 38, 36, 30, 35, 47, 37, 48, 35, 39, 52, 43, 46, 50, 36, 39, 47, 43, 45, 52, 44, 40, 43, 47, 50, 49, 44, 49, 43, 46, 49, 51, 51, 54, 48, 53, 47, 42, 44, 32, 52, 49, 53, 36, 40, 39, 39, 56, 44, 33, 43, 45, 45, 56, 49, 51, 49, 52, 47, 50, 48, 45, 52, 50, 48, 53, 43, 47, 50, 47, 53, 46, 55, 51, 47, 51, 47, 51, 42, 47, 50, 49, 46, 51, 48, 46, 43, 48, 47, 53, 49, 52, 45, 50, 45, 50, 50, 53, 43, 47, 51, 50, 48, 47, 49, 57, 49, 52, 58, 44, 45, 51, 38, 51, 38, 48, 62, 51, 48, 42, 52, 48, 50, 54, 50, 51, 44, 48, 54, 50, 47, 55, 53, 49, 53, 49, 51, 51, 47, 48, 48, 46, 55, 54, 50, 45, 53, 56, 44, 47, 42, 52, 48, 52, 49, 41, 53, 52, 51, 49, 57, 49, 44, 54, 45, 54, 55, 45, 44, 46, 53, 52, 46, 59, 47, 36, 52, 50, 44, 47, 52, 46, 55, 42, 59, 44, 57, 45, 54, 53, 62, 56, 55, 52, 51, 42, 50, 47, 53, 49, 49, 45, 45, 44, 51, 51, 43, 55, 52, 53, 49, 54, 51, 52, 47, 51, 41, 49, 47, 56, 55, 54, 53, 43, 52, 43, 43, 48, 48, 49, 53, 43, 54, 42, 44, 51, 55, 56, 46, 47, 43, 46, 52, 54, 58, 47, 54, 51, 48, 58, 48, 48, 54, 59, 51, 55, 39, 42, 52, 51, 57, 49, 59, 53, 43, 47, 51, 43, 47, 54, 54, 46, 46, 46, 41, 41, 45, 53, 51, 48, 44, 47, 51, 48, 46, 58, 46, 48, 41, 45, 51, 58, 52, 49, 49, 35, 51, 51, 56, 60, 60, 47, 52, 52, 47, 42, 42, 50, 55, 51, 48, 42, 52, 52, 54, 47, 46, 40, 44, 49, 52, 55, 51, 55, 54, 52, 51, 49, 52, 51, 53, 59, 49, 50, 49, 50, 52, 53, 45, 51, 61, 50, 45, 50, 50, 55, 54, 48, 50, 44, 54, 52, 49, 48, 41, 53, 56, 49, 55, 51, 50, 45, 52, 50, 49, 58, 39, 56, 52, 54, 51, 41, 46, 49, 47, 60, 47, 54, 45, 51, 60, 51, 56, 55, 58, 50, 53, 51, 50, 50, 47, 62, 53, 50, 49, 57, 53, 51, 48, 55]) / 100),
    'medium': faithful_rolling_mean(pd.Series([0, 1, 0, 1, 1, 2, 1, 1, 0, 0, 4, 0, 3, 1, 2, 1, 2, 1, 1, 4, 3, 3, 3, 0, 0, 1, 1, 5, 5, 5, 8, 8, 5, 6, 4, 5, 2, 5, 4, 4, 2, 13, 10, 9, 6, 10, 9, 22, 13, 16, 18, 10, 20, 22, 22, 27, 22, 29, 28, 22, 23, 29, 21, 24, 30, 26, 25, 40, 32, 31, 28, 33, 31, 34, 40, 32, 31, 26, 38, 31, 35, 37, 35, 43, 31, 34, 41, 37, 36, 44, 50, 39, 41, 50, 45, 47, 49, 48, 36, 38, 35, 55, 50, 31, 51, 57, 45, 51, 48, 49, 37, 39, 44, 47, 51, 48, 51, 45, 45, 48, 47, 42, 46, 42, 42, 49, 44, 44, 53, 47, 50, 47, 51, 50, 47, 41, 38, 51, 51, 48, 41, 43, 51, 48, 48, 60, 54, 48, 47, 53, 46, 53, 51, 47, 46, 56, 55, 60, 48, 48, 44, 47, 49, 48, 53, 57, 50, 49, 55, 49, 49, 50, 46, 49, 50, 40, 40, 55, 51, 46, 52, 48, 48, 54, 54, 42, 52, 47, 52, 56, 62, 53, 49, 47, 47, 43, 53, 46, 48, 47, 54, 49, 47, 48, 53, 52, 47, 48, 53, 51, 60, 55, 52, 47, 55, 50, 63, 46, 49, 53, 46, 52, 51, 59, 51, 50, 53, 56, 51, 52, 49, 50, 42, 53, 48, 51, 48, 52, 47, 57, 49, 50, 47, 51, 40, 46, 52, 48, 51, 48, 52, 53, 53, 45, 60, 57, 47, 50, 51, 50, 60, 46, 57, 49, 52, 53, 50, 52, 59, 59, 57, 54, 55, 47, 45, 44, 54, 54, 50, 48, 61, 64, 57, 51, 56, 59, 49, 50, 58, 49, 54, 58, 58, 61, 49, 58, 55, 54, 53, 51, 47, 45, 60, 60, 54, 54, 54, 55, 52, 50, 56, 59, 61, 53, 54, 56, 57, 59, 51, 48, 50, 49, 51, 53, 56, 47, 63, 54, 53, 57, 47, 51, 52, 48, 58, 47, 54, 61, 51, 52, 53, 46, 52, 59, 51, 46, 54, 57, 50, 55, 43, 52, 60, 54, 65, 50, 61, 59, 52, 51, 64, 53, 52, 57, 51, 52, 48, 47, 53, 52, 61, 52, 54, 64, 48, 52, 58, 58, 50, 55, 51, 46, 60, 46, 63, 60, 63, 61, 65, 53, 46, 61, 54, 59, 48, 54, 54, 53, 51, 58, 56, 55, 49, 45, 56, 59, 54, 64, 60, 58, 55, 50, 53, 60, 52, 55, 44, 51, 50, 55, 49, 57, 62, 56, 55, 52, 50, 56, 69, 62, 51, 47, 48, 62, 53, 44, 50, 59, 55, 51, 56, 44, 47, 54, 54, 57, 56, 50, 51, 59, 60, 56, 48, 63, 61, 62, 58, 53, 58, 60, 53, 45, 62, 60, 52, 54, 54, 57, 67, 55, 57, 54, 62, 55, 53, 62, 49, 54, 51, 58, 53, 58, 58, 50, 63, 60, 55, 55, 58, 53, 52, 57, 56, 48, 59, 47, 59, 47, 54, 63, 58, 58, 50, 61, 50, 56, 50, 58, 58, 52, 57, 52, 49, 45, 51, 60, 59, 61, 61, 59, 51, 49, 57, 44]) / 100),
    'large': faithful_rolling_mean(pd.Series([1, 1, 0, 1, 2, 1, 2, 12, 13, 4, 9, 13, 11, 9, 13, 13, 13, 10, 15, 7, 15, 10, 12, 13, 9, 8, 15, 9, 14, 13, 11, 15, 5, 13, 11, 9, 12, 6, 10, 14, 13, 9, 9, 13, 10, 9, 11, 11, 10, 8, 4, 9, 11, 13, 8, 2, 5, 6, 9, 7, 4, 3, 5, 12, 5, 6, 6, 6, 8, 8, 15, 13, 9, 8, 9, 8, 7, 13, 15, 17, 19, 11, 14, 19, 16, 21, 22, 21, 20, 26, 21, 17, 21, 20, 18, 25, 19, 21, 26, 34, 27, 24, 22, 27, 22, 27, 33, 29, 28, 31, 26, 36, 33, 24, 36, 38, 32, 30, 32, 30, 42, 34, 35, 39, 31, 41, 38, 29, 36, 35, 43, 38, 45, 43, 46, 37, 48, 47, 54, 46, 35, 38, 40, 42, 50, 45, 43, 51, 41, 50, 52, 43, 39, 46, 52, 47, 40, 49, 42, 46, 45, 54, 51, 49, 53, 55, 51, 48, 46, 52, 55, 47, 52, 53, 58, 50, 51, 43, 52, 43, 50, 39, 49, 56, 49, 48, 56, 48, 57, 54, 55, 53, 59, 55, 56, 46, 49, 55, 53, 56, 60, 58, 53, 63, 52, 50, 60, 58, 51, 45, 60, 52, 61, 52, 49, 58, 54, 53, 48, 57, 62, 58, 55, 58, 52, 57, 56, 55, 57, 51, 56, 53, 50, 46, 50, 57, 59, 53, 50, 56, 58, 62, 63, 51, 55, 53, 54, 54, 53, 59, 64, 58, 63, 57, 57, 64, 58, 59, 52, 60, 46, 52, 50, 58, 53, 52, 60, 49, 62, 57, 61, 60, 56, 53, 53, 60, 66, 58, 59, 54, 68, 60, 53, 57, 60, 54, 64, 57, 55, 57, 63, 55, 53, 53, 60, 64, 61, 53, 62, 65, 51, 58, 61, 52, 53, 53, 58, 59, 57, 58, 58, 60, 59, 53, 56, 51, 60, 58, 56, 54, 52, 54, 45, 55, 52, 55, 58, 54, 51, 53, 57, 58, 57, 65, 58, 51, 45, 46, 60, 52, 64, 55, 55, 57, 61, 62, 54, 60, 51, 63, 56, 57, 52, 54, 55, 57, 59, 55, 46, 50, 64, 56, 49, 58, 59, 61, 62, 59, 55, 54, 54, 59, 45, 51, 63, 52, 54, 56, 60, 56, 69, 61, 49, 53, 57, 52, 64, 55, 53, 50, 59, 63, 50, 60, 66, 64, 56, 53, 61, 58, 59, 58, 58, 55, 65, 61, 60, 54, 49, 64, 64, 56, 55, 58, 46, 56, 55, 57, 60, 56, 59, 56, 60, 53, 64, 60, 61, 58, 55, 54, 51, 63, 51, 53, 55, 56, 54, 67, 58, 63, 54, 48, 61, 59, 58, 55, 58, 55, 53, 57, 55, 60, 56, 55, 54, 57, 55, 55, 61, 61, 62, 60, 53, 57, 56, 61, 59, 57, 55, 56, 46, 51, 59, 56, 74, 56, 51, 62, 55, 59, 54, 59, 55, 70, 53, 50, 51, 61, 62, 64, 56, 60, 54, 56, 57, 57, 60, 56, 63, 60, 56, 62, 61, 52, 56, 69, 55, 62, 61, 60, 56, 58, 59, 56, 55, 66, 55, 59, 60, 50, 51, 61, 58, 64]) / 100),
},  columns = ['small', 'medium', 'large'])
df = df.rename(columns={
    'small': '1 hidden layer of size 40',
    'medium': '2 hidden layers of size 80',
    'large': '5 hidden layers of size 400',
})
df.index = df.index * 10
plt.rcParams.update({'font.size': 12})
ax = df.plot(figsize=(8, 5), grid=True, title='Test games won against 1 hidden layer of size 40 bot')
ax.set_xlabel('Training games played')
ax.set_ylabel('490 training game-wide moving average')
ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: '{:.0%}'.format(y)))
plt.show()
](architecture_experiment.png)

The larger architectures clearly performed better, though the training process was slower and less smooth.

### Benchmarking against GNU Backgammon

We tested the largest architecture described in the previous section by pitting a bot that chooses moves using the neural network (with no look-ahead) against [GNU Backgammon](http://www.gnubg.org/), a strong open-source program that uses three neural networks and an endgame database. 100 test games were played after every 10 training games.

Here are the results, again with moving averages displayed.

![
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
def faithful_rolling_mean(series, max_odd_window=49):
    result = series.map(lambda _: np.nan)
    for window in range(max_odd_window, -1, -2):
        result = np.where(np.isnan(result), series.rolling(window, center=True).mean(), result)
    return result[:- (max_odd_window - 1) // 2]
series = pd.Series(faithful_rolling_mean(pd.Series([0, 0, 0, 1, 1, 1, 1, 1, 4, 1, 5, 7, 12, 7, 7, 8, 12, 4, 4, 4, 6, 10, 9, 1, 7, 2, 6, 11, 3, 7, 5, 7, 12, 6, 5, 6, 7, 12, 6, 5, 8, 8, 8, 4, 8, 6, 10, 4, 5, 5, 4, 5, 3, 7, 4, 4, 3, 7, 3, 4, 3, 9, 3, 7, 7, 4, 3, 3, 7, 3, 7, 1, 8, 8, 5, 5, 6, 5, 8, 10, 10, 7, 5, 5, 9, 5, 8, 9, 8, 6, 7, 9, 9, 7, 11, 9, 9, 11, 10, 9, 11, 13, 11, 14, 17, 9, 14, 14, 14, 11, 10, 15, 11, 13, 15, 10, 13, 17, 15, 24, 16, 20, 17, 24, 17, 18, 18, 15, 18, 18, 23, 25, 26, 25, 25, 23, 20, 31, 18, 27, 20, 28, 28, 25, 29, 28, 26, 29, 31, 23, 33, 29, 30, 33, 38, 29, 35, 26, 32, 32, 36, 24, 37, 30, 28, 30, 29, 31, 34, 32, 33, 29, 36, 37, 35, 41, 36, 43, 29, 38, 40, 25, 31, 35, 34, 40, 41, 39, 34, 44, 34, 42, 40, 39, 33, 41, 39, 38, 41, 40, 29, 35, 38, 37, 41, 44, 31, 41, 34, 42, 45, 44, 40, 44, 39, 35, 40, 45, 43, 41, 40, 43, 33, 39, 41, 36, 41, 36, 44, 46, 46, 39, 43, 41, 44, 49, 40, 32, 37, 45, 47, 33, 46, 33, 40, 39, 37, 39, 40, 44, 51, 37, 40, 37, 36, 44, 46, 39, 44, 48, 31, 46, 41, 38, 35, 44, 41, 43, 37, 36, 46, 44, 42, 43, 42, 44, 41, 35, 43, 36, 44, 36, 49, 51, 34, 38, 41, 52, 38, 44, 38, 42, 43, 40, 40, 44, 43, 35, 42, 38, 32, 45, 37, 41, 43, 49, 35, 49, 51, 45, 46, 40, 40, 44, 39, 38, 34, 37, 41, 37, 47, 35, 37, 39, 38, 46, 41, 43, 38, 42, 46, 44, 42, 46, 47, 39, 38, 43, 41, 41, 41, 42, 37, 40, 47, 40, 45, 35, 46, 43, 40, 39, 51, 44, 57, 44, 43, 43, 47, 45, 45, 42, 47, 43, 48, 38, 44, 39, 48, 43, 45, 56, 38, 41, 47, 43, 38, 33, 31, 34, 44, 50, 38, 45, 44, 44, 34, 40, 43, 43, 44, 40, 49, 46, 37, 34, 43, 35, 36, 44, 39, 36, 47, 40, 43, 31, 42, 34, 47, 39, 44, 38, 45, 37, 41, 38, 29, 46, 38, 39, 44, 41, 36, 46, 43, 44, 44, 41, 54, 45, 46, 43, 44, 42, 45, 41, 43, 40, 37, 46, 39, 45, 43, 43, 48, 41, 37, 43, 40, 42, 43, 40, 46, 54, 43, 47, 50, 52, 52, 46, 47, 43, 40, 42, 38, 47, 41, 42, 38, 44, 45, 45, 36, 39, 46, 47, 45, 44, 41, 43, 43, 47, 50, 37, 43, 52, 46, 35, 46, 44, 40, 36, 46, 44, 41, 42, 46, 46, 51, 42, 42, 45, 45, 44, 50, 41, 48, 55, 37, 42, 41, 49, 43, 44, 42, 40, 42, 45, 34, 45, 43, 43, 48, 40]) / 100))
series.index = series.index * 10
plt.rcParams.update({'font.size': 12})
ax = series.plot(figsize=(8, 5), grid=True, title='Test games won against GNU Backgammon')
ax.set_xlabel('Training games played')
ax.set_ylabel('490 training game-wide moving average')
ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: '{:.0%}'.format(y)))
ax.legend().remove()
plt.show()
](benchmark_experiment.png)

A win rate of around 41% was achieved after around 2,500 training games. With each game lasting around 57 moves on average, this corresponds to an "error rating" (thousandths of expected games given up per move made) of around 3.2 above that of GNU Backgammon, which is about as good as the top human players.

It may appear that our bot requires relatively few training games: Tesauro [notes][2] that TD-Gammon achieves an intermediate level of play after 200,000 training games. However, our algorithm evaluates around a few hundred times as many positions in its 1-ply look-ahead as TD-Gammon does, making the performance of the two algorithms somewhat comparable.

Allowing the bot to use 1-ply look-ahead during play improves the win rate against GNU Backgammon by around 2%: the number of games won by the bot in a 10,000-game head-to-head against GNU Backgammon increased from 4,255 to 4,469 with this change.

### Coming soon...

- An experiment between 1-ply look-ahead and some form of Monte Carlo tree search guided by the output of the neural network

## Reference

[1] Richard S. Sutton and Andrew G. Barto. *Reinforcement Learning: An Introduction.*

[2]: http://www.bkgm.com/articles/tesauro/tdl.html
[3]: http://www.scholarpedia.org/article/User:Gerald_Tesauro/Proposed/Td-gammon
[4]: https://www.cs.cornell.edu/boom/2001sp/Tsinteris/gammon.htm