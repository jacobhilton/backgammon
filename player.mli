type t =
  | Forwards
  | Backwards
[@@deriving sexp]

val equal : t -> t -> bool

val flip : t -> t

val char : t -> char
