type t =
  | Game
  | Gammon
  | Backgammon

val to_phrase : t -> string

val (<=) : t -> t -> bool
