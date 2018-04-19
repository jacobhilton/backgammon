open Core
open Async

type t

val of_equity : Equity.t -> t

val human : ?history_position:int -> stdin:Reader.t -> unit -> t

val gnubg : prog:string -> filename:string -> display:bool -> t Deferred.t

val vs : t Per_player.t -> t

val play
  :  ?abandon_after_move:int
  -> ?stdout_flushed:(unit -> unit Deferred.t)
  -> ?show_pip_count:bool
  -> display:bool
  -> ?to_play:Player.t
  -> ?board:Board.t
  -> ?history:string Per_player.t list
  -> ?move_number:int
  -> t
  -> ((Player.t * Outcome.t) Or_error.t * [ `Moves of int ]) Deferred.t
