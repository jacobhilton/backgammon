type 'a t

val create : (Player.t -> 'a) -> 'a t

val create_both : 'a -> 'a t

val get : 'a t -> Player.t -> 'a

val replace : 'a t -> Player.t -> 'a -> 'a t