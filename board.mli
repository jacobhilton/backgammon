type t

val bar : t -> player:Player.t -> int

val off : t -> player:Player.t -> int

val point_exn : t -> player:Player.t -> position:int -> Point.t

val remove_from_bar_exn : t -> player:Player.t -> t

val add_to_bar : t -> player:Player.t -> t

val add_to_off : t -> player:Player.t -> t

val remove_from_point_exn : t -> player:Player.t -> position:int -> t

val add_to_point_exn : t -> player:Player.t -> position:int -> t

val highest_occupied_position : t -> player:Player.t -> int

val starting : t

val to_ascii : ?viewer:Player.t -> ?home:[ `Left | `Right ] -> t -> string
