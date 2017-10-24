type t

val create : (Player.t -> Board.t -> float) -> t

val eval : t -> Player.t -> Board.t -> float

val minimax : t -> look_ahead:int -> t

val pip_count_ratio : t
