open Core

let main () =
  printf "%s\n" Board.(to_ascii starting);
  printf "%s\n" (Sexp.to_string (List.sexp_of_t (List.sexp_of_t Int.sexp_of_t) (List.map Roll.all_distances_with_probabilities ~f:fst)));
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
