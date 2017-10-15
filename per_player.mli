type 'a t

val create : forwards:'a -> backwards:'a -> 'a t

val createi : (Player.t -> 'a) -> 'a t

val create_both : 'a -> 'a t

val get : 'a t -> Player.t -> 'a
