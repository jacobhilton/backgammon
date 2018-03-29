open Async

type 'a t

val create : capacity:int option -> _ t

val capacity : _ t -> int option

val enqueued : _ t -> int

val size : _ t -> int

val enqueue : 'a t -> 'a -> unit

val save : 'a t -> filename:string -> ('a -> Sexp.t) -> unit Deferred.t

val load : 'a t -> filename:string -> (Sexp.t -> 'a) -> unit Deferred.t

val sample : 'a t -> int -> 'a list
