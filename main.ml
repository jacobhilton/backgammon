open Core
open Async

let main ~two_player =
  Random.self_init ();
  let stdin = Lazy.force Reader.stdin in
  let other = if two_player then Game.random else Game.human ~stdin in
  Game.winner (Game.vs_human other ~stdin) ~display:true
  >>= fun _winner ->
  Deferred.unit

let () =
  let open Command.Let_syntax in
  Command.async'
    ~summary:"foo"
    [%map_open
      let two_player = flag "-two-player" no_arg ~doc:" human-vs-human mode" in
      fun () ->
        main ~two_player
    ]
  |> Command.run
