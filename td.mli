type t

val create : ?epsilon_init:Base.float -> hidden_layer_sizes:int list -> unit -> t

val eval : t -> (Player.t * Board.t) array -> float array

val equity : t -> Equity.t

val train : t -> learning_rate:float -> (Player.t * Board.t) array -> float array -> unit

val save : t -> filename:string -> unit

val load : t -> filename:string -> unit
