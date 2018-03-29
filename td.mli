type t

val create
  :  ?epsilon_init:float
  -> hidden_layer_sizes:int list
  -> representation:[ `Original | `Modified ]
  -> unit
  -> t

val eval : t -> Equity.Setup.t array -> float array

val train
  :  t
  -> (Equity.Setup.t * float) Replay_memory.t
  -> minibatch_size:int
  -> minibatches_number:int
  -> unit

val save : t -> filename:string -> unit

val load : t -> filename:string -> unit
