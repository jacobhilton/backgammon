open Core
open Async

type t =
  Player.t -> Board.t -> Roll.t -> history:string Per_player.t list -> Board.t Or_error.t Deferred.t

let of_equity equity player board roll ~history:_ =
  let boards_with_valuations =
    Move.all_legal_turn_outcomes roll player board
    |> Set.to_list
    |> List.map ~f:(fun board ->
      let valuation =
        Equity.eval equity { Equity.Setup.player; to_play = Player.flip player; board }
      in
      if not (Float.is_finite valuation) then
        failwithf "Equity valuation %f encountered." valuation ();
      (board, valuation))
  in
  let highest_valuation =
    List.fold boards_with_valuations ~init:Float.min_value
      ~f:(fun acc (_, valuation) -> Float.max acc valuation)
  in
  let highest_valuation_boards =
    List.filter_map boards_with_valuations ~f:(fun (board, valuation) ->
      if Float.equal valuation highest_valuation then Some board else None)
  in
  List.nth_exn highest_valuation_boards (Random.int (List.length highest_valuation_boards))
  |> Deferred.Or_error.return

let rec human ?history_position:history_position_opt ~stdin () player board roll ~history =
  printf "Your move (? for help): ";
  Reader.read_line stdin
  >>= fun user_input_read_result ->
  let user_input =
    match user_input_read_result with
    | `Ok user_input -> user_input
    | `Eof -> failwith "Program terminated by user."
  in
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
  let special_input =
    match String.to_list (String.lowercase user_input) with
    | [] -> if Result.is_ok new_board then `Move else `History `Reset_or_toggle
    | 'p' :: _ -> `History (`Step 1)
    | 'n' :: _ -> `History (`Step (-1))
    | ['h'; 'e'; 'l'; 'p'] | '?' :: _ -> `Help
    | ['q'; 'u'; 'i'; 't'] -> `Quit
    | _ -> `Move
  in
  match special_input with
  | `History action ->
    let new_history_position_or_error =
      match action with
      | `Reset_or_toggle ->
        if Int.equal (List.length history) 1 then
          Ok 0
        else if (Option.equal Int.equal) history_position_opt (Some 0) then
          Ok 1
        else
          Ok 0
      | `Step step ->
        match history_position_opt with
        | None -> Ok 0
        | Some history_position ->
          if Int.(history_position + step < 0) then
            Or_error.error_string "There is no next move."
          else if Int.(history_position + step > List.length history - 1) then
            Or_error.error_string "There was no previous move."
          else
            Ok (history_position + step)
    in
    begin
      match new_history_position_or_error with
      | Ok new_history_position ->
        begin
          match List.nth history new_history_position with
          | Some history_item ->
            printf "%i move%s ago:\n%s" new_history_position
              (if Int.equal new_history_position 1 then "" else "s")
              (Per_player.get history_item player)
          | None -> printf "No moves recorded.\n"
        end;
        human ~history_position:new_history_position ~stdin () player board roll ~history
      | Error err ->
        printf "%s\n" (Error.to_string_hum err);
        human ?history_position:history_position_opt ~stdin () player board roll ~history
    end
  | `Help ->
    printf
      "Enter the start and end positions, separated by a foward slash \
       (or any non-numeric character), of each counter you want to move.\n\
       Each position should be number from 1 to 24, \"bar\" or \"off\".\n\
       Unlike in standard notation, you should enter each counter movement individually. \
       For example:\n \
       24/18 18/13\n \
       bar/3 13/10 13/10 8/5\n \
       2/off 1/off\n\
       You can also enter these commands:\n \
       p - show the previous move\n \
       n - show the next move\n \
       <enter> - toggle between showing the current and last moves\n \
       help - show this help text\n \
       quit - abandon game\n";
    human ~stdin () player board roll ~history
  | `Quit ->
    Deferred.return (Or_error.errorf "abandoned by player %c" (Player.char player))
  | `Move ->
    match new_board with
    | Ok x -> Deferred.Or_error.return x
    | Error err ->
      printf "%s\n" (Error.to_string_hum err);
      human ~stdin () player board roll ~history

let vs ts player = (Per_player.get ts player) player

let rec play ?abandon_after_move ?stdout_flushed ?show_pip_count ~display ?to_play:to_play_opt
    ?(board=Board.starting) ?(history=[]) ?(move_number=1) t =
  if Option.value_map abandon_after_move ~default:false ~f:(Int.(>) move_number) then
    Deferred.return (Or_error.error_string "abandoned due to length", `Moves (move_number - 1))
  else
    begin
      let to_play, roll =
        match to_play_opt with
        | None ->
          let starting_player = if Random.bool () then Player.Forwards else Backwards in
          if display then printf "Player %c to start.\n" (Player.char starting_player);
          starting_player, Roll.generate_starting ()
        | Some to_play_value -> to_play_value, Roll.generate ()
      in
      match Board.winner board with
      | Some (player, outcome) -> Deferred.return (Ok (player, outcome), `Moves (move_number - 1))
      | None ->
        let board_text ~viewer = sprintf "\n%s\n\n" (Board.to_ascii board ?show_pip_count ~viewer) in
        let roll_text tense =
          sprintf "Move %i: player %c roll%s a %s.\n" move_number (Player.char to_play) tense
            (Roll.to_string roll)
        in
        begin
          if display then
            begin
              printf "%s%s" (board_text ~viewer:to_play) (roll_text "s");
              match stdout_flushed with
              | None -> Deferred.unit
              | Some f -> f ()
            end
          else
            Deferred.unit
        end
        >>= fun () ->
        let new_history =
          Per_player.create (fun viewer -> sprintf "%s%s" (board_text ~viewer) (roll_text "ed"))
          :: history
        in
        t to_play board roll ~history:new_history
        >>= function
        | Error err -> Deferred.return (Error err, `Moves (move_number - 1))
        | Ok new_board ->
          play ?abandon_after_move ?stdout_flushed ?show_pip_count ~display
            ~to_play:(Player.flip to_play) ~board:new_board ~history:new_history
            ~move_number:(move_number + 1) t
    end
