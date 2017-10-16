open Core

type t = int

let empty = 0

let create player number =
  let n = Int.abs number in
  match player with
  | Player.Forwards -> n
  | Backwards -> -n

let occupier t =
  match Int.sign t with
  | Sign.Neg -> Some Player.Backwards
  | Zero -> None
  | Pos -> Some Player.Forwards

let number t = Int.abs t

let remove_exn t player =
  match Option.map (occupier t) ~f:(Player.equal player) with
  | None | Some false ->
    failwithf "No counters of player %c on point to remove" (Player.char player) ()
  | Some true -> t - create player 1

let add_exn t player =
  match Option.map (occupier t) ~f:(Player.equal player) with
  | Some false ->
    failwithf "Counters of player %c prevent addition of counters of player %c"
      (Player.char (Player.flip player)) (Player.char player) ()
  | None | Some true -> t + create player 1
