type t

val create
  :  ?epsilon_init:float
  -> hidden_layer_sizes:int list
  -> representation:[ `Original | `Modified ]
  -> unit
  -> t

val eval : t -> ([ `To_play of Player.t ] * Player.t * Board.t) array -> float array

val train
  :  t
  -> (([ `To_play of Player.t ] * Player.t * Board.t) * float) Replay_memory.t
  -> minibatch_size:int
  -> minibatches_number:int
  -> unit

val save : t -> filename:string -> unit

val load : t -> filename:string -> unit
