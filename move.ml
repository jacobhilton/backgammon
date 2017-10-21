open Core

type t =
  { from : [ `Bar | `Position of int ]
  ; distance : int
  }

let create from ~distance = { from; distance }

let execute t player board =
  if Int.(t.distance <= 0) || Int.(t.distance > 6) then
    Or_error.errorf "a counter cannot be moved %i points in a single move" t.distance
  else
    let add_to_point_and_capture board ~position =
      let point = Board.point_exn board ~player ~position in
      match Option.map (Point.occupier point) ~f:(Player.equal player) with
      | None | Some true -> Ok (Board.add_to_point_exn board ~player ~position)
      | Some false ->
        match Point.count point with
        | 1 ->
          Board.remove_from_point_exn board ~player:(Player.flip player) ~position
          |> Board.add_to_bar ~player:(Player.flip player)
          |> Board.add_to_point_exn ~player ~position
          |> Or_error.return
        | _ ->
          Or_error.errorf "player %c has 2 or more counters on player %c's %i point"
            (Player.char (Player.flip player)) (Player.char player) position
    in
    match t.from, Int.(Board.bar board ~player > 0) with
    | `Bar, false -> Or_error.errorf "player %c has no counters on the bar" (Player.char player)
    | `Bar, true ->
      add_to_point_and_capture board ~position:(25 - t.distance)
      |> Or_error.map ~f:(Board.remove_from_bar_exn ~player)
    | `Position _, true -> Or_error.errorf "player %c has a counter on the bar" (Player.char player)
    | `Position position_from, false ->
      if Int.(position_from <= 0) || Int.(position_from > 24) then
        Or_error.errorf "player %c's %i point does not exist" (Player.char player) position_from
      else
        let point_from = Board.point_exn board ~player ~position:position_from in
        match Option.map (Point.occupier point_from) ~f:(Player.equal player) with
        | None | Some false ->
          Or_error.errorf "player %c has no counters on their %i point" (Player.char player)
            position_from
        | Some true ->
          let position_to = position_from - t.distance in
          if Int.(position_to <= 0) then
            let furthest_distance_from_off =
              match Board.furthest_from_off board ~player with
              | `Bar -> 25
              | `Position position -> position
              | `Off -> 0
            in
            let furthest_allowed_distance = if Int.equal position_to 0 then 6 else position_from in
            if Int.(furthest_distance_from_off <= furthest_allowed_distance) then
              Board.remove_from_point_exn board ~player ~position:position_from
              |> Board.add_to_off ~player
              |> Or_error.return
            else
              Or_error.errorf "player %c has a counter on their %i point" (Player.char player)
                furthest_distance_from_off
          else
            add_to_point_and_capture board ~position:position_to
            |> Or_error.map ~f:(Board.remove_from_point_exn ~player ~position:position_from)


let all_legal_turns roll player board =
  let all_legal_moves ~distance player board =
    let all =
      { from = `Bar; distance } :: List.init 24 ~f:(fun i -> { from = `Position (i + 1); distance })
    in
    List.filter_map all ~f:(fun t ->
      match execute t player board with
      | Error _ -> None
      | Ok b -> Some (t, b))
  in
  let all_legal_move_lists distances =
    List.fold distances ~init:[[[], board]] ~f:(fun acc distance ->
      (List.bind (List.hd_exn acc) ~f:(fun (moves_so_far, board_so_far) ->
         List.map (all_legal_moves ~distance player board_so_far) ~f:(fun (move, new_board) ->
           (move :: moves_so_far, new_board))))
      :: acc)
    |> List.map ~f:(List.map ~f:(fun (moves, new_board) -> (List.rev moves, new_board)))
  in
  let first_non_empty moves_and_boards =
    List.find moves_and_boards ~f:(fun l -> not (List.is_empty l))
    |> Option.value ~default:[[], board]
  in
  match roll with
  | Roll.Double distance ->
    first_non_empty (all_legal_move_lists (List.init 4 ~f:(fun _ -> distance)))
  | High_low (high, low) ->
    match all_legal_move_lists [high; low], all_legal_move_lists [low; high] with
    | [two_moves_high_first; high_move], [two_moves_low_first; low_move] ->
      first_non_empty [two_moves_high_first @ two_moves_low_first; high_move; low_move]
    | _ -> failwith "unreachable"
