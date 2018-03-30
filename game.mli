open Async

type t

val create
  :  (Player.t -> Board.t -> Roll.t -> history:string Per_player.t list -> Board.t Deferred.t)
  -> t

val eval
  :  t
  -> Player.t -> Board.t -> Roll.t -> history:string Per_player.t list -> Board.t Deferred.t

val of_equity : Equity.t -> t

val human : ?history_position:int -> stdin:Reader.t -> unit -> t

val vs : t Per_player.t -> t

val winner
  :  ?show_pip_count:bool
  -> display:bool
  -> ?to_play:Player.t
  -> ?board:Board.t
  -> ?history:string Per_player.t list
  -> ?move_number:int
  -> t
  -> (Player.t * Outcome.t * [ `Moves of int ]) Deferred.t
