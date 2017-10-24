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
(* look ahead 0: constant
   look ahead 1: evaluate once
   look ahead 2: for each legal board and each possible roll, evaluate the opponent's boards
   look ahead 3: for each of the opponent's boards and each possible roll, evaluate the boards *)
let rec minimax t ~look_ahead player board =
  match look_ahead with
  | 0 -> 0.5
  | 1 -> t player board
  | _ -> 1. -. begin
    List.map Roll.all_with_probabilities ~f:(fun (roll, probability) ->
      Move.all_legal_turn_outcomes roll (Player.flip player) board
      |> Set.to_list
      |> List.map ~f:(fun new_board ->
        (* have another player variable and use that to decide whether to max or min
           just pass the same variable to minimax *)
        minimax t ~look_ahead:(look_ahead - 1) (Player.flip player) new_board)
      |> List.fold ~init:Float.min_value ~f:Float.max
      |> Float.scale probability)
    |> List.fold ~init:0. ~f:(+.) end

let pip_count_ratio player board =
  let pip_count = Board.pip_count board ~player in
  let opponent_pip_count = Board.pip_count board ~player:(Player.flip player) in
  (Int.to_float opponent_pip_count) /. (Int.to_float (pip_count + opponent_pip_count))
