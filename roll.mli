type t =
  | Double of int
  | High_low of int * int

val self_init : unit -> unit

val generate : unit -> t

val all_with_probabilities : (t * float) list
