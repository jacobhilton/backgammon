open Base
open Async

let td_init ~filename_to_load =
  Random.self_init ();
  let td = Td.create ~hidden_layer_sizes:[40] () in
  match filename_to_load with
  | None -> Deferred.return td
  | Some filename ->
    Sys.file_exists filename
    >>| function
    | `Yes -> Td.load td ~filename; td
    | `No | `Unknown -> td

let play ~players ~filename_to_load =
  td_init ~filename_to_load
  >>= fun td ->
  let machine = Game.of_equity (Equity.minimax (Td.equity td) ~look_ahead:2) in
  let stdin = Lazy.force Reader.stdin in
  let game =
    match players with
    | 0 -> machine
    | 1 -> Game.vs_human machine ~stdin
    | 2 -> Game.human ~stdin
    | _ -> Core.failwithf "You cannot play backgammon with %i human players." players ()
  in
  Game.winner ~show_pip_count:true ~display:true game
  >>= fun (_winner, _outcome, `Moves _number_of_moves) ->
  Deferred.unit

let train ~games ~learning_rate ~filename_to_load ~filename_to_save =
  td_init ~filename_to_load
  >>= fun td ->
  let trainer = Equity.minimax Equity.pip_count_ratio ~look_ahead:2 in
  let rec train' game_number =
    if Int.(game_number > games) then
      Deferred.unit
    else
      let setups_and_valuations = ref [] in
      let equity = Equity.mapi trainer ~f:(fun ~to_play player board valuation ->
        setups_and_valuations :=
          ((`To_play to_play, player, board), valuation) :: !setups_and_valuations;
        valuation)
      in
      Game.winner ~display:false (Game.of_equity equity)
      >>= fun (winner, outcome, `Moves number_of_moves) ->
      Clock.after (Core.sec 0.01)
      >>= fun () ->
      printf
        "Game %i of %i: player %c wins%s after %i moves. Training on %i observed equity valuations.\n"
        game_number
        games
        (Player.char winner)
        (match outcome with | `Game -> "" | `Gammon -> " a gammon" | `Backgammon -> " a backgammon")
        number_of_moves
        (List.length !setups_and_valuations);
      Td.train td ~learning_rate (Array.of_list !setups_and_valuations);
      train' (game_number + 1)
  in
  train' 1
  >>= fun () ->
  Td.save td ~filename:filename_to_save;
  Deferred.unit

let () =
  let filename_param flag_of_arg_type load_or_save ~default =
    let open Command.Param in
    flag (Core.sprintf "-%s-file" load_or_save) (flag_of_arg_type file)
      ~doc:(Core.sprintf "PATH location of ckpt file to %s\ndefault: %s" load_or_save default)
  in
  let play =
    let open Command.Let_syntax in
    Command.async'
      ~summary:"play against TD-Gammon"
      [%map_open
        let players =
          flag "-players" (optional_with_default 1 int) ~doc:"N number of human players\ndefault: 1"
        and filename_to_load = filename_param optional "load" ~default:"none"
        in
        fun () ->
          play ~players ~filename_to_load
      ]
  in
  let train =
    let default_filename_to_save = "td.ckpt" in
    let open Command.Let_syntax in
    Command.async'
      ~summary:"train TD-gammon"
      [%map_open
        let games =
          flag "-games" (optional_with_default 1 int) ~doc:"N number of games to play\ndefault: 1"
        and learning_rate =
          flag "-learning-rate" (optional_with_default 0.1 float)
            ~doc:"ALPHA learning rate\ndefault: 0.1"
        and filename_to_load = filename_param optional "load" ~default:"none"
        and filename_to_save =
          filename_param (optional_with_default default_filename_to_save) "save"
            ~default:default_filename_to_save
        in
        fun () ->
          train ~games ~learning_rate ~filename_to_load ~filename_to_save
      ]
  in
  Command.group
    ~summary:"backgammon"
    [ "play", play
    ; "train", train
    ]
  |> Command.run
