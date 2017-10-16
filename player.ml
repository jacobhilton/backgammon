type t =
  | Forwards
  | Backwards

let equal t1 t2 =
  match t1, t2 with
  | Forwards, Forwards | Backwards, Backwards -> true
  | Forwards, Backwards | Backwards, Forwards -> false

let flip = function
  | Forwards -> Backwards
  | Backwards -> Forwards

let char = function
  | Forwards -> 'O'
  | Backwards -> 'X'
