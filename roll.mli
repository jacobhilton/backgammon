type t

val self_init : unit -> unit

val generate : unit -> t

val generate_starting : unit -> Player.t * t

val distances : t -> int list

val all_distances_with_probabilities : (int list * float) list
