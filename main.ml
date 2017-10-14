open Core

let main () =
  let _ = Board.Point.create in
  printf "hi"

let () =
  let open Command.Let_syntax in
  Command.basic'
    ~summary:"foo"
    [%map_open
      let _ = flag "bar" (required int) ~doc:"N bar"
      in
      fun () ->
        main ()
    ]
  |> Command.run
