open Core

type t = int * int

let self_init () = Random.self_init ()

let generate () =
  let g () = (Random.int 6) + 1 in
  (g (), g ())

let rec generate_starting () =
  let i, j = generate () in
  match Int.(sign (compare i j)) with
  | Sign.Neg -> Player.Backwards, (i, j)
  | Zero -> generate_starting ()
  | Pos -> Player.Forwards, (i, j)

let distances (i, j) =
  match Int.(sign (compare i j)) with
  | Sign.Neg -> [j; i]
  | Zero -> [i; i; i; i]
  | Pos -> [i; j]

let all_distances_with_probabilities =
  List.init 6 ~f:(fun i ->
    List.init (i + 1) ~f:(fun j ->
      (distances (i + 1, j + 1), if Int.equal i j then 1. /. 36. else 1. /. 18.)))
  |> List.concat
