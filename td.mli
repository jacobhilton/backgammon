type t

val create : ?epsilon_init:Base.float -> hidden_layer_sizes:int list -> unit -> t

val fit : t -> learning_rate:float -> (Player.t * Board.t) array -> float array -> unit

val predict : t -> (Player.t * Board.t) array -> float array

val equity : t -> Equity.t
