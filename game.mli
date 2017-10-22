open Async

type t

val create : (Player.t -> Board.t -> Roll.t -> Board.t Deferred.t) -> t

val human : stdin:Reader.t -> t

val random : t

val vs : t Per_player.t -> t

val vs_human : t -> stdin:Reader.t -> t

val winner
  :  ?to_play:Player.t
  -> ?board:Board.t
  -> ?move_number:int
  -> t
  -> display:bool
  -> Player.t Deferred.t
