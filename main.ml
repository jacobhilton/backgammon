open Core
open Async

let main ~players =
  Random.self_init ();
  let pip_count_ratio =
    Game.of_evaluation (Evaluation.minimax (Evaluation.pip_count_ratio) ~look_ahead:2)
  in
  let stdin = Lazy.force Reader.stdin in
  let game =
    match players with
    | 0 -> pip_count_ratio
    | 1 -> Game.vs_human pip_count_ratio ~stdin
    | 2 -> Game.human ~stdin
    | _ -> failwithf "You cannot play backgammon with %i human players." players ()
  in
  Game.winner ~show_pip_count:true ~display:true game
  >>= fun _winner ->
  Deferred.unit

let () =
  let open Command.Let_syntax in
  Command.async'
    ~summary:"foo"
    [%map_open
      let players =
        flag "-players" (optional_with_default 1 int) ~doc:"N number of human players"
      in
      fun () ->
        main ~players
    ]
  |> Command.run
