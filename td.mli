open Core

type t

val create
  :  ?epsilon_init:float
  -> hidden_layer_sizes:int list
  -> activation:[ `Sigmoid | `Relu ]
  -> representation:[ `Original | `Modified | `Expanded ]
  -> unit
  -> t

val representation : t -> [ `Original | `Modified | `Expanded ]

val eval : t -> Equity.Setup.t array -> float array

module Setup : sig
  type t [@@deriving sexp]

  val create : Equity.Setup.t -> [ `Original | `Modified | `Expanded ] -> t

  module And_valuation : sig
    type nonrec t = t * float [@@deriving sexp]
  end
end

val train
  :  t
  -> (Setup.t * float) Replay_memory.t
  -> minibatch_size:int
  -> minibatches_number:int
  -> unit

val save : t -> filename:string -> unit

val load : t -> filename:string -> unit

val sexp_of_vars : t -> Sexp.t
