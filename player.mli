type t =
  | Forwards
  | Backwards

val flip : t -> t

val to_char : t -> char
