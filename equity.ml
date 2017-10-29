open Base

type t = to_play:Player.t -> Player.t -> Board.t -> float

let create = Fn.id

let eval = Fn.id

let mapi t ~f ~to_play player board = f ~to_play player board (t ~to_play player board)

let rec minimax t ~look_ahead ~to_play player board =
  match look_ahead with
  | 0 -> 0.5
  | 1 -> t ~to_play player board
  | _ ->
    let min_or_max =
      if Player.equal to_play player then
        List.fold ~init:Float.min_value ~f:Float.max
      else
        List.fold ~init:Float.max_value ~f:Float.min
    in
    List.map Roll.all_with_probabilities ~f:(fun (roll, probability) ->
      Move.all_legal_turn_outcomes roll to_play board
      |> Set.to_list
      |> List.map ~f:(fun new_board ->
        minimax t ~look_ahead:(look_ahead - 1) ~to_play:(Player.flip to_play) player new_board)
      |> min_or_max
      |> Float.scale probability)
    |> List.fold ~init:0. ~f:Float.(+)

let pip_count_ratio ~to_play:_ player board =
  let pip_count = Board.pip_count board ~player in
  let opponent_pip_count = Board.pip_count board ~player:(Player.flip player) in
  Float.(/) (Int.to_float opponent_pip_count) (Int.to_float (pip_count + opponent_pip_count))
