open Async

type t

val of_equity : Equity.t -> t

val human : ?history_position:int -> stdin:Reader.t -> unit -> t

val vs : t Per_player.t -> t

val play
  :  ?show_pip_count:bool
  -> display:bool
  -> ?to_play:Player.t
  -> ?board:Board.t
  -> ?history:string Per_player.t list
  -> ?move_number:int
  -> ?abandon_after_move:int
  -> t
  -> ((Player.t * Outcome.t) option * [ `Moves of int ]) Deferred.t
