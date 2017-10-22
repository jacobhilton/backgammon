open Async

type t

val create : (Player.t -> Board.t -> Roll.t -> Board.t Deferred.t) -> t

val human : stdin:Reader.t -> t

val minimax
  :  look_ahead:int
  -> evaluation:(Player.t -> Board.t -> float)
  -> t

val vs : t Per_player.t -> t

val vs_human : t -> stdin:Reader.t -> t

val winner
  :  ?show_pip_count:bool
  -> display:bool
  -> ?to_play:Player.t
  -> ?board:Board.t
  -> ?move_number:int
  -> t
  -> Player.t Deferred.t
