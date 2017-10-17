open Core

let main () =
  let board =
    Move.execute { from = `Position 8; distance = 3 } Player.Backwards Board.starting
    |> Or_error.ok_exn
  in
  printf "%s\n" Board.(to_ascii board);
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
