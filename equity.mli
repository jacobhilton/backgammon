type t

val create : (to_play:Player.t -> Player.t -> Board.t -> float) -> t

val eval : t -> to_play:Player.t -> Player.t -> Board.t -> float

val mapi : t -> f:(to_play:Player.t -> Player.t -> Board.t -> float -> float) -> t

val minimax : t -> look_ahead:int -> Outcome.t -> t

val minimax'
  :  (([ `To_play of Player.t ] * Player.t * Board.t) array -> float array)
  -> look_ahead:int
  -> Outcome.t
  -> t

val pip_count_ratio : t
