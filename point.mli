type t [@@deriving compare,sexp]

val empty : t

val create : Player.t -> int -> t

val occupier : t -> Player.t option

val count : t -> Player.t -> int

val remove_exn : t -> Player.t -> t

val add_exn : t -> Player.t -> t
