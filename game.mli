open Async

type t

val create : (Player.t -> Board.t -> Roll.t -> Board.t Deferred.t) -> t

val eval : t -> Player.t -> Board.t -> Roll.t -> Board.t Deferred.t

val of_equity : Equity.t -> t

val human : stdin:Reader.t -> t

val vs : t Per_player.t -> t

val vs_human : t -> stdin:Reader.t -> t

val winner
  :  ?show_pip_count:bool
  -> display:bool
  -> ?to_play:Player.t
  -> ?board:Board.t
  -> ?move_number:int
  -> t
  -> (Player.t * [ `Game | `Gammon | `Backgammon ] * [ `Moves of int ]) Deferred.t
