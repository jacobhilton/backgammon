open Core

let main () =
  printf "%s\n" Game.Board.(to_ascii starting);
  ()

let () =
  let open Command.Let_syntax in
  Command.basic'
    ~summary:"foo"
    [%map_open
      let _ = flag "bar" (optional_with_default 0 int) ~doc:"N bar"
      in
      fun () ->
        main ()
    ]
  |> Command.run
