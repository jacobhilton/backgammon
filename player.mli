type t =
  | Forwards
  | Backwards

val equal : t -> t -> bool

val flip : t -> t

val char : t -> char
