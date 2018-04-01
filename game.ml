open Core
open Async

type t = Player.t -> Board.t -> Roll.t -> history:string Per_player.t list -> Board.t Deferred.t

let of_equity equity player board roll ~history:_ =
  let boards_with_values =
    Move.all_legal_turn_outcomes roll player board
    |> Set.to_list
    |> List.map ~f:(fun board ->
      (board, Equity.eval equity { Equity.Setup.player; to_play = Player.flip player; board }))
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

let rec human ?history_position:history_position_opt ~stdin () player board roll ~history =
  let history_position = Option.value history_position_opt ~default:0 in
  if Option.is_some history_position_opt then
      printf "%i move%s ago:\n%s" history_position (if Int.equal history_position 1 then "" else "s")
        (Per_player.get (List.nth_exn history history_position) player);
  printf "Your move (? for help): ";
  Reader.read_line stdin
  >>= function
  | `Eof -> human ~stdin () player board roll ~history
  | `Ok user_input ->
    let input_kind =
      match String.to_list (String.lowercase user_input) with
      | [] -> if Int.equal history_position 0 then `History (`Step 1) else `History `Reset
      | 'p' :: _ -> `History (`Step 1)
      | 'n' :: _ -> `History (`Step (-1))
      | '?' :: _ -> `Help
      | _ -> `Move
    in
    match input_kind with
    | `History action ->
      let new_history_position =
        match action with
        | `Reset -> 0
        | `Step step -> history_position + step
      in
      let new_valid_history_position =
        if Int.(new_history_position < 0) || Int.(new_history_position > List.length history - 1) then
          begin
            printf "There %s move.\n"
              (if Int.(new_history_position < 0) then "is no next" else "was no previous");
            history_position
          end
        else
          new_history_position
      in
      human ~history_position:new_valid_history_position ~stdin () player board roll ~history
    | `Help ->
      printf
        "Enter the start and end positions, separated by a foward slash \
         (or any non-numeric character), of each counter you want to move.\n\
         Each position should be number from 1 to 24, \"bar\" or \"off\".\n\
         Unlike in standard notation, you should enter each counter movement individually, \
         as in these examples:\n \
         24/18 18/13\n \
         bar/3 13/10 13/10 8/5\n \
         2/off 1/off\n\
         You can also navigate through past moves using:\n \
         p - show the previous move\n \
         n - show the next move\n \
         <enter> - toggle between showing the current and last moves\n";
      human ~stdin () player board roll ~history
    | `Move ->
      let pair l =
        let pairs, x_extra =
          List.fold l ~init:([], None) ~f:(fun (acc, x_even_opt) x ->
            match x_even_opt with
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
          Error.of_string (sprintf "Could not parse input: %s." (Error.to_string_hum err)))
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
              let sorted_distances l =
                List.sort (List.map l ~f:Move.capped_distance) ~cmp:Int.compare
              in
              List.equal (sorted_distances moves) (sorted_distances legal_turn_prefix)
                ~equal:Int.equal)
          then
            Ok moves
          else
            Or_error.error_string
              "Illegal move: does not match the roll. \
               If you are moving one counter more than once, \
               please enter each counter movement individually.")
      in
      let moves_legal_sequence =
        Or_error.bind moves_valid_distances ~f:(List.fold ~init:(Ok board) ~f:(fun acc move ->
          Or_error.bind acc ~f:(fun board_so_far ->
            let new_board_so_far = Move.execute move player board_so_far in
            Result.map_error new_board_so_far ~f:(fun err ->
              Error.of_string (sprintf "Illegal move: %s." (Error.to_string_hum err))))))
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
        human ~stdin () player board roll ~history
      | Ok x -> Deferred.return x

let vs ts player = (Per_player.get ts player) player

let rec play ?show_pip_count ~display ?to_play:to_play_opt ?(board=Board.starting) ?(history=[])
    ?(move_number=1) t =
  let to_play, roll =
    match to_play_opt with
    | None ->
      let starting_player = if Random.bool () then Player.Forwards else Backwards in
      if display then printf "Player %c to start.\n" (Player.char starting_player);
      starting_player, Roll.generate_starting ()
    | Some to_play_value -> to_play_value, Roll.generate ()
  in
  let board_text ~viewer = sprintf "\n%s\n\n" (Board.to_ascii board ?show_pip_count ~viewer) in
  if display then print_string (board_text ~viewer:to_play);
  match Board.winner board with
  | Some (player, outcome) ->
    if display then printf "Player %c wins%s.\n" (Player.char player) (Outcome.to_phrase outcome);
    Deferred.return (player, outcome, `Moves (move_number - 1))
  | None ->
    let roll_text tense =
      sprintf "Move %i: player %c roll%s a %s.\n" move_number (Player.char to_play) tense
        (Roll.to_string roll)
    in
    if display then print_string (roll_text "s");
    let new_history =
        (Per_player.create (fun viewer -> board_text ~viewer ^ roll_text "ed")) :: history
    in
    t to_play board roll ~history:new_history
    >>= fun new_board ->
    play ?show_pip_count ~display ~to_play:(Player.flip to_play) ~board:new_board ~history:new_history
      ~move_number:(move_number + 1) t
