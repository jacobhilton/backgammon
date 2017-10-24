open Core

type t = Player.t -> Board.t -> float

let create = Fn.id

let eval = Fn.id

(* probability of move has something to do with stability of likelihood of winning as well as the
   likelihood itself? *)
(* transposition table *)
(* mcts *)
(* Bellman equation i.e. TD with depth plus discount factor *)
(* TD *)
let minimax t ~look_ahead player board =
  let apply min_or_max =
    match min_or_max with
    | `Min -> List.fold ~init:Float.max_value ~f:Float.min
    | `Max -> List.fold ~init:Float.min_value ~f:Float.max
  in
  let flip min_or_max =
    match min_or_max with
    | `Min -> `Max
    | `Max -> `Min
  in
  let rec minimax' look_ahead board min_or_max =
    match look_ahead with
    | 0 -> 0.5
    | 1 -> t player board
    | _ ->
      List.map Roll.all_with_probabilities ~f:(fun (roll, probability) ->
        Move.all_legal_turn_outcomes roll (Player.flip player) board
        |> Set.to_list
        |> List.map ~f:(fun new_board -> minimax' (look_ahead - 1) new_board (flip min_or_max))
        |> apply min_or_max
        |> Float.scale probability)
      |> List.fold ~init:0. ~f:(+.)
  in
  minimax' look_ahead board `Min

let pip_count_ratio player board =
  let pip_count = Board.pip_count board ~player in
  let opponent_pip_count = Board.pip_count board ~player:(Player.flip player) in
  (Int.to_float opponent_pip_count) /. (Int.to_float (pip_count + opponent_pip_count))
