open Base
open Async

type t = Player.t -> Board.t -> Roll.t -> Board.t Deferred.t

let create = Fn.id

let eval = Fn.id

let of_equity equity player board roll =
  let boards_with_values =
    Move.all_legal_turn_outcomes roll player board
    |> Set.to_list
    |> List.map ~f:(fun board -> (board, Equity.eval equity player board))
  in
  let highest_value =
    List.fold boards_with_values ~init:Float.min_value
      ~f:(fun acc (_, value) -> Float.max acc value)
  in
  let highest_value_boards =
    List.filter_map boards_with_values ~f:(fun (board, value) ->
      if Float.equal value highest_value then Some board else None)
  in
  List.nth_exn highest_value_boards (Random.int (List.length highest_value_boards))
  |> Deferred.return

let rec human ~stdin player board roll =
  printf "Your move: ";
  Reader.read_line stdin
  >>= function
  | `Eof -> human ~stdin player board roll
  | `Ok user_input ->
    let pair l =
      let pairs, x_extra =
        List.fold l ~init:([], None) ~f:(fun (acc, x_even_option) x ->
          match x_even_option with
          | None -> acc, Some x
          | Some x_even -> (x_even, x) :: acc, None)
      in
      match x_extra with
      | None -> Some (List.rev pairs)
      | Some _ -> None
    in
    let moves_parsed =
      String.lowercase user_input
      |> String.substr_replace_all ~pattern:"bar" ~with_:" 25 "
      |> String.substr_replace_all ~pattern:"off" ~with_:" 0 "
      |> String.map ~f:(fun c -> if Char.is_digit c then c else ' ')
      |> String.split ~on:' '
      |> List.filter ~f:(fun s -> not (String.is_empty s))
      |> List.map ~f:(fun s -> Or_error.try_with (fun () -> Int.of_string s))
      |> Or_error.combine_errors
      |> Or_error.bind ~f:(fun l ->
        Result.of_option (pair l) ~error:(Error.of_string "odd number of board positions found"))
      |> Or_error.map ~f:(List.map ~f:(fun (i, j) ->
        Move.create (if Int.equal i 25 then `Bar else `Position i) ~distance:(i - j)))
      |> Result.map_error ~f:(fun err ->
        Error.of_string (Core.sprintf "Could not parse input: %s." (Error.to_string_hum err)))
    in
    let moves_valid_distances =
      Or_error.bind moves_parsed ~f:(fun moves ->
        let legal_turn_prefixes =
          List.map (Move.all_legal_turns roll player board) ~f:(fun (legal_turn, _) ->
            List.init (List.length legal_turn + 1) ~f:(fun n -> List.split_n legal_turn n |> fst))
          |> List.concat
        in
        if
          List.exists legal_turn_prefixes ~f:(fun legal_turn_prefix ->
            let sorted_distances l = List.sort (List.map l ~f:Move.capped_distance) ~cmp:Int.compare in
            List.equal (sorted_distances moves) (sorted_distances legal_turn_prefix) ~equal:Int.equal)
        then
          Ok moves
        else
          Or_error.error_string
            "Illegal move: does not match the roll. \
             If you are moving one counter more than once, please enter each move separately.")
    in
    let moves_legal_sequence =
      Or_error.bind moves_valid_distances ~f:(List.fold ~init:(Ok board) ~f:(fun acc move ->
        Or_error.bind acc ~f:(fun board_so_far ->
          let new_board_so_far = Move.execute move player board_so_far in
          Result.map_error new_board_so_far ~f:(fun err ->
            Error.of_string (Core.sprintf "Illegal move: %s." (Error.to_string_hum err))))))
    in
    let new_board =
      Or_error.bind moves_legal_sequence ~f:(fun new_board_maybe_illegal ->
        if Set.mem (Move.all_legal_turn_outcomes roll player board) new_board_maybe_illegal then
          Ok new_board_maybe_illegal
        else
          Or_error.error_string "Illegal move: it is possible to move more.")
    in
    match new_board with
    | Error err ->
      printf "%s\n" (Error.to_string_hum err);
      human ~stdin player board roll
    | Ok x -> Deferred.return x

let vs ts player board roll = (Per_player.get ts player) player board roll

let vs_human t ~stdin =
  vs (Per_player.create (function
    | Player.Backwards -> human ~stdin
    | Forwards -> t))

let rec winner ?show_pip_count ~display ?to_play:to_play_option ?(board=Board.starting)
    ?(move_number=1) t =
  let to_play, roll =
    match to_play_option with
    | None ->
      let starting_player = if Random.bool () then Player.Forwards else Backwards in
      if display then printf "Player %c to start.\n" (Player.char starting_player);
      starting_player, Roll.generate_starting ()
    | Some to_play_value -> to_play_value, Roll.generate ()
  in
  if display then printf "\n%s\n\n" (Board.to_ascii board ?show_pip_count ~viewer:to_play);
  match Board.winner board with
  | Some (player, outcome) ->
    if display then
      printf "Player %c wins%s.\n" (Player.char player)
        (match outcome with | `Game -> "" | `Gammon -> " a gammon" | `Backgammon -> " a backgammon");
    Deferred.return player
  | None ->
    if display then
      printf "Move %i: player %c rolls a %s.\n" ((move_number + 1) / 2) (Player.char to_play)
        (Roll.to_string roll);
    t to_play board roll
    >>= fun new_board ->
    winner ?show_pip_count ~display ~to_play:(Player.flip to_play) ~board:new_board
      ~move_number:(move_number + 1) t
