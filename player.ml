type t =
  | Forwards
  | Backwards

let flip = function
  | Forwards -> Backwards
  | Backwards -> Forwards

let to_char = function
  | Forwards -> 'O'
  | Backwards -> 'X'
