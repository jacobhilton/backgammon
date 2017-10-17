type t =
  { from : [ `Bar | `Position of int ]
  ; distance : int
  }

val execute : t -> Player.t -> Board.t -> Board.t Core.Or_error.t
