open Base
open Async

let td_init ~filename =
  Random.self_init ();
  let td = Td.create ~hidden_layer_sizes:[40] () in
  Sys.file_exists filename
  >>| function
  | `Yes -> Td.load td ~filename; td
  | `No | `Unknown -> td

let play ~players ~filename =
  td_init ~filename
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

let train ~games ~filename =
  td_init ~filename
  >>= fun td ->
  let trainer = Equity.minimax Equity.pip_count_ratio ~look_ahead:2 in
  let rec train' games =
    if Int.(games <= 0) then
      Deferred.unit
    else
      let players_and_boards_and_equities = ref [] in
      let equity = Equity.mapi trainer ~f:(fun player board f ->
        players_and_boards_and_equities := ((player, board), f) :: !players_and_boards_and_equities;
        f)
      in
      Game.winner ~display:false (Game.of_equity equity)
      >>= fun (winner, outcome, `Moves number_of_moves) ->
      Clock.after (Core.sec 0.01)
      >>= fun () ->
      printf "Game %i: player %c wins%s after %i moves. Training on %i observed equities.\n"
        games
        (Player.char winner)
        (match outcome with | `Game -> "" | `Gammon -> " a gammon" | `Backgammon -> " a backgammon")
        number_of_moves
        (List.length !players_and_boards_and_equities);
      Td.train td ~learning_rate:0.1 (Array.of_list !players_and_boards_and_equities);
      train' (games -1)
  in
  train' games
  >>= fun () ->
  Td.save td ~filename;
  Deferred.unit

let () =
  let filename_flag =
    let open Command in
    Param.flag "-save-file" (Flag.optional_with_default "td.ckpt" Param.file)
      ~doc:"PATH location of save file"
  in
  let play =
    let open Command.Let_syntax in
    Command.async'
      ~summary:"play against TD-Gammon"
      [%map_open
        let players =
          flag "-players" (optional_with_default 1 int) ~doc:"N number of human players"
        and filename = filename_flag
        in
        fun () ->
          play ~players ~filename
      ]
  in
  let train =
    let open Command.Let_syntax in
    Command.async'
      ~summary:"train TD-gammon"
      [%map_open
        let games =
          flag "-games" (optional_with_default 1 int) ~doc:"N number of games to play"
        and filename = filename_flag
        in
        fun () ->
          train ~games ~filename
      ]
  in
  Command.group
    ~summary:"backgammon"
    [ "play", play
    ; "train", train
    ]
  |> Command.run
