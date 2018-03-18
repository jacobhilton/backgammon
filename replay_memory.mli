type 'a t

val create : capacity:int -> _ t

val capacity : _ t -> int

val size : _ t -> int

val enqueue : 'a t -> 'a array -> unit

val sample : 'a t -> int -> 'a array