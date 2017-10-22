type t

val create : [ `Bar | `Position of int ] -> distance:int -> t

val from : t -> [ `Bar | `Position of int ]

val distance : t -> int

val execute : t -> Player.t -> Board.t -> Board.t Core.Or_error.t

val all_legal_turns : Roll.t -> Player.t -> Board.t -> (t list * Board.t) list

val all_legal_turn_outcomes : Roll.t -> Player.t -> Board.t -> Board.Set.t
