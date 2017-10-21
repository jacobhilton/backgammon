open Core
open Async

let main () =
  Random.self_init ();
  Game.winner Game.random ~display:true
  >>= fun _winner ->
  Deferred.unit

let () =
  let open Command.Let_syntax in
  Command.async'
    ~summary:"foo"
    [%map_open
      let () = return ()
      in
      fun () ->
        main ()
    ]
  |> Command.run
