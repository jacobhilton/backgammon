type t

val create : [ `Bar | `Position of int ] -> distance:int -> t

val execute : t -> Player.t -> Board.t -> Board.t Core.Or_error.t

val all_legal_turns : Roll.t -> Player.t -> Board.t -> (t list * Board.t) list
