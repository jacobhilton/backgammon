type t

val create : ?epsilon_init:Base.float -> hidden_layer_sizes:int list -> unit -> t

val eval : t -> ([ `To_play of Player.t ] * Player.t * Board.t) array -> float array

val equity : t -> Equity.t

val train
  :  t
  -> learning_rate:float
  -> (([ `To_play of Player.t ] * Player.t * Board.t) * float) array
  -> unit

val save : t -> filename:string -> unit

val load : t -> filename:string -> unit