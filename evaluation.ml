open Core

type t = Player.t -> Board.t -> float

let create = Fn.id

let eval = Fn.id

(* tree search with pip count *)
(* probability of move has something to do with stability of likelihood of winning as well as the
   likelihood itself? *)
(* transposition table *)
(* mcts *)
(* Bellman equation i.e. TD with depth plus discount factor *)
(* TD *)
(* look ahead 0: choose a legal board at random
   look ahead 1: choose the best legal board (choose randomly between the best)
   look ahead 2: for each legal board and each possible roll, choose the opponent's best board
   look ahead 3: for each of the opponent's board choices and each possible roll, choose the best board *)
(* let rec minimax ~look_ahead ~evaluation:_ player board roll = *)
(*     match look_ahead with *)
(*     | 0 -> 0.5 *)
(*     | 1 -> evaluation player board *)

let minimax t ~look_ahead:_ = t

let pip_count_ratio player board =
  let pip_count = Board.pip_count board ~player in
  let opponent_pip_count = Board.pip_count board ~player:(Player.flip player) in
  (Int.to_float opponent_pip_count) /. (Int.to_float (pip_count + opponent_pip_count))
