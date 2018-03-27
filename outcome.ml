type t =
  | Game
  | Gammon
  | Backgammon

let to_phrase = function
  | Game -> ""
  | Gammon -> " a gammon"
  | Backgammon -> " a backgammon"

let (<=) t1 t2 =
  match t1, t2 with
  | Game, _ | Gammon, Gammon | Gammon, Backgammon | Backgammon, Backgammon -> true
  | Gammon, Game | Backgammon, Game | Backgammon, Gammon -> false

