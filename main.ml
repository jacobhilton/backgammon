open Core
open Async

let main ~players =
  Random.self_init ();
  let random = Game.minimax ~look_ahead:0 ~evaluation:(fun _ _ -> Random.float 1.) in
  let stdin = Lazy.force Reader.stdin in
  let game =
    match players with
    | 0 -> random
    | 1 -> Game.vs_human random ~stdin
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
