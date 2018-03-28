type 'a t

val create : capacity:int option -> _ t

val capacity : _ t -> int option

val size : _ t -> int

val enqueue : 'a t -> 'a list -> unit

val sample : 'a t -> int -> 'a list
