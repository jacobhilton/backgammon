type t

val create : Player.t -> int -> t

val empty : t

val player : t -> Player.t option

val number : t -> int

val remove_exn : t -> Player.t -> t

val add_exn : t -> Player.t -> t
