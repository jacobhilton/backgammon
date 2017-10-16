open Core

type t = int

let empty = 0

let create player number =
  let n = Int.abs number in
  match player with
  | Player.Forwards -> n
  | Backwards -> -n

let player t =
  match Int.sign t with
  | Sign.Neg -> Some Player.Backwards
  | Zero -> None
  | Pos -> Some Player.Forwards

let number t = Int.abs t

let remove_exn t occupier =
  match Option.map (player t) ~f:(Player.equal occupier) with
  | None | Some false ->
    failwithf "No counters of player %c on point to remove" (Player.char occupier) ()
  | Some true -> t - create occupier 1

let add_exn t occupier =
  match Option.map (player t) ~f:(Player.equal occupier) with
  | Some false ->
    failwithf "Counters of player %c prevent addition of counters of player %c"
      (Player.char (Player.flip occupier)) (Player.char occupier) ()
  | None | Some true -> t + create occupier 1
