open Core

type t = int

let empty = 0

let create player number =
  let n = Int.abs number in
  match player with
  | Player.Forwards -> n
  | Backwards -> -n

let forwards number = create Player.Forwards number

let backwards number = create Player.Backwards number

let player t =
  match Int.sign t with
  | Sign.Neg -> Some Player.Backwards
  | Zero -> None
  | Pos -> Some Player.Forwards

let number t = Int.abs t
