open Core

type t =
  | Double of int
  | High_low of int * int

let to_string = function
  | Double i -> sprintf "%i-%i" i i
  | High_low (i, j) -> sprintf "%i-%i" i j

let generate () =
  let i = Random.int 6 in
  let j = Random.int 6 in
  match Int.(sign (compare i j)) with
  | Sign.Neg -> High_low (j + 1, i + 1)
  | Zero -> Double (i + 1)
  | Pos -> High_low (i + 1, j + 1)

let rec generate_starting () =
  match generate () with
  | Double _ -> generate_starting ()
  | High_low (i, j) -> High_low (i, j)

let all_with_probabilities =
  List.init 6 ~f:(fun i ->
    List.init (i + 1) ~f:(fun j ->
      if Int.equal i j then
        Double (i + 1), 1. /. 36.
      else
        High_low (i + 1, j + 1), 1. /. 18.))
  |> List.concat
