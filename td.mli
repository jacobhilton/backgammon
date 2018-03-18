type t

val create
  :  ?epsilon_init:float
  -> hidden_layer_sizes:int list
  -> representation:[ `Original | `Modified ]
  -> unit
  -> t

val eval : t -> ([ `To_play of Player.t ] * Player.t * Board.t) array -> float array

module Training_data : sig
  module Config : sig
    type t [@@deriving of_sexp]
  end

  type t

  val create : ?config:Config.t -> unit -> t
end

val train
  :  t
  -> training_data:Training_data.t
  -> (([ `To_play of Player.t ] * Player.t * Board.t) * float) array -> unit

val save : t -> filename:string -> unit

val load : t -> filename:string -> unit
