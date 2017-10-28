open Base

type t = int [@@deriving compare,sexp]

let empty = 0

let create occupier count =
  let count = Int.max 0 count in
  match occupier with
  | Player.Forwards -> count
  | Backwards -> - count

let occupier t =
  match Int.sign t with
  | Sign.Neg -> Some Player.Backwards
  | Zero -> None
  | Pos -> Some Player.Forwards

let count t player =
  match player with
  | Player.Forwards -> Int.max 0 t
  | Backwards -> Int.max 0 (-t)

let remove_exn t player =
  match Option.map (occupier t) ~f:(Player.equal player) with
  | None | Some false ->
    Core.failwithf "No counters of player %c on point to remove" (Player.char player) ()
  | Some true -> t - create player 1

let add_exn t player =
  match Option.map (occupier t) ~f:(Player.equal player) with
  | Some false ->
    Core.failwithf "Counters of player %c prevent addition of counters of player %c"
      (Player.char (Player.flip player)) (Player.char player) ()
  | None | Some true -> t + create player 1

let to_representation t =
  let forwards_representation t =
    ( (if Int.equal t 1 then 1. else 0.)
    , (if Int.(t >= 2) then 1. else 0.)
    , (if Int.equal t 3 then 1. else 0.)
    , (if Int.(t >= 4) then Float.(/) (Int.to_float (t - 3)) 2. else 0.)
    )
  in
  Per_player.create (function
    | Player.Forwards -> forwards_representation t
    | Backwards -> forwards_representation (-t))
