type t

val empty : t

val create : Player.t -> int -> t

val forwards : int -> t

val backwards : int -> t

val player : t -> Player.t option

val number : t -> int
