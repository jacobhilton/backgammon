open Core

let main () =
  Roll.self_init ();
  let roll = Roll.generate () in
  let roll_string =
    match roll with
    | Double distance -> sprintf "%i-%i" distance distance
    | High_low (high, low) -> sprintf "%i-%i" high low
  in
  printf "All legal starting turns on a roll of %s:\n\n" roll_string;
  List.iter (Move.all_legal_turns roll Player.Backwards Board.starting)
    ~f:(fun (_moves, board) -> printf "%s\n\n" (Board.to_ascii board));
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
