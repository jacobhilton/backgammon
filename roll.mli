type t =
  | Double of int
  | High_low of int * int

val to_string : t -> string

val distances : t -> int list

val generate : unit -> t

val generate_starting : unit -> t

val all_with_probabilities : (t * float) list
