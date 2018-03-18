open Core

type t = to_play:Player.t -> Player.t -> Board.t -> float

let create = Fn.id

let eval = Fn.id

let mapi t ~f ~to_play player board = f ~to_play player board (t ~to_play player board)

module Tree = struct
  type t =
    | Atom of [ `To_play of Player.t ] * Board.t
    | List of [ `To_play of Player.t ] * (float * t list) list
end

let minimax' pre_equity ~look_ahead ~to_play player board =
  match look_ahead with
  | 0 -> 0.5
  | _ ->
    let boards_ref = ref (Per_player.create_both []) in
    let rec build_tree ~look_ahead ~to_play board =
      match look_ahead with
      | 1 ->
        boards_ref :=
          Per_player.mapi !boards_ref ~f:(fun player_key boards ->
            if Player.equal player_key to_play then board :: boards else boards);
        Tree.Atom (`To_play to_play, board)
      | _ ->
        let probabilities_and_children =
          List.map Roll.all_with_probabilities ~f:(fun (roll, probability) ->
            let children =
              Move.all_legal_turn_outcomes roll to_play board
              |> Set.to_list
              |> List.map ~f:(fun new_board ->
                build_tree ~look_ahead:(look_ahead - 1) ~to_play:(Player.flip to_play) new_board)
            in
            (probability, children))
        in
        List (`To_play to_play, probabilities_and_children)
    in
    let tree = build_tree ~look_ahead ~to_play board in
    let boards_and_valuations =
      Per_player.mapi !boards_ref ~f:(fun to_play boards ->
        List.map boards ~f:(fun board -> (`To_play to_play, player, board))
        |> Array.of_list
        |> (fun setups -> if Array.is_empty setups then [| |] else pre_equity setups)
        |> Array.to_list
        |> List.zip_exn boards
        |> Board.Map.of_alist_reduce ~f:(fun x _ -> x))
    in
    let rec result tree =
      match tree with
      | Tree.Atom (`To_play to_play, board) ->
        Map.find_exn (Per_player.get boards_and_valuations to_play) board
      | List (`To_play to_play, probabilities_and_children) ->
        let min_or_max =
          if Player.equal to_play player then
            List.fold ~init:Float.min_value ~f:Float.max
          else
            List.fold ~init:Float.max_value ~f:Float.min
        in
        List.map probabilities_and_children ~f:(fun (probability, children) ->
          List.map children ~f:result
          |> min_or_max
          |> Float.scale probability)
        |> List.fold ~init:0. ~f:Float.(+)
    in
    result tree

let minimax t =
  minimax' (fun setups ->
    Array.map setups ~f:(fun (`To_play to_play, player, board) -> t ~to_play player board))

let pip_count_ratio ~to_play:_ player board =
  let pip_count = Board.pip_count board ~player in
  let opponent_pip_count = Board.pip_count board ~player:(Player.flip player) in
  Float.(/) (Int.to_float opponent_pip_count) (Int.to_float (pip_count + opponent_pip_count))
