open Async

type t

val create : (Player.t -> Board.t -> Roll.t -> Board.t Deferred.t) -> t

val random : t

val winner : t -> display:bool -> Player.t Deferred.t
