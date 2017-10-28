type 'a t [@@deriving compare,sexp]

val create : (Player.t -> 'a) -> 'a t

val create_both : 'a -> 'a t

val get : 'a t -> Player.t -> 'a

val replace : 'a t -> Player.t -> 'a -> 'a t

val map : 'a t -> f:('a -> 'b) -> 'b t
