open Core

type t =
  { from : [ `Bar | `Point of int ]
  ; distance : int
  }

let apply_legally t player board =
  match t.from, Board.bar board player with
  | `Bar, 0 -> Or_error.errorf "No counters of player %c on the bar" (Player.char player)
  | _ -> failwith "hi"
