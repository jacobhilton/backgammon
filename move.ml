open Core

type t =
  { from : [ `Bar | `Position of int ]
  ; distance : int
  }

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
            let highest_occupied = Board.highest_occupied_position board ~player in
            if Int.(highest_occupied <= if Int.equal position_to 0 then 6 else position_from) then
              Board.remove_from_point_exn board ~player ~position:position_from
              |> Board.add_to_off ~player
              |> Or_error.return
            else
              Or_error.errorf "player %c has a counter on their %i point" (Player.char player)
                highest_occupied
          else
            add_to_point_and_capture board ~position:position_to
            |> Or_error.map ~f:(Board.remove_from_point_exn ~player ~position:position_from)
