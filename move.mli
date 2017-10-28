type t

val create : [ `Bar | `Position of int ] -> distance:int -> t

val from : t -> [ `Bar | `Position of int ]

val uncapped_distance : t -> int

val capped_distance : t -> int

val execute : t -> Player.t -> Board.t -> Board.t Base.Or_error.t

val all_legal_turns : Roll.t -> Player.t -> Board.t -> (t list * Board.t) list

val all_legal_turn_outcomes : Roll.t -> Player.t -> Board.t -> Board.Set.t
