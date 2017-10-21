open Async

type t

val create : (Player.t -> Board.t -> Roll.t -> Board.t Deferred.t) -> t

val human : t

val random : t

val vs : t Per_player.t -> t

val vs_human : t -> t

val winner : t -> display:bool -> Player.t Deferred.t
