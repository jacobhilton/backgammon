open Core

let main () =
  printf "%s\n" Board.(to_ascii starting);
  let _ = Move.apply_legally in
  List.iter Roll.all_with_probabilities ~f:(fun (roll, _) ->
    match roll with
    | Roll.Double i -> printf "(%i %i %i %i)\n" i i i i
    | High_low (i, j) -> printf "(%i %i)\n" i j);
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
