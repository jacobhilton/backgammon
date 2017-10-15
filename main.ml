open Core

let main () =
  printf "%s\n" Board.(to_ascii starting);
  ()

let () =
  let open Command.Let_syntax in
  Command.basic'
    ~summary:"foo"
    [%map_open
      let () = return ()
      in
      fun () ->
        main ()
    ]
  |> Command.run
