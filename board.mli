type t

val bar : t -> Player.t -> int

val off : t -> Player.t -> int

val point_exn : t -> int -> Point.t

val remove_from_bar_exn : t -> Player.t -> t

val add_to_bar : t -> Player.t -> t

val add_to_off : t -> Player.t -> t

val remove_from_point_exn : t -> int -> Player.t -> t

val add_to_point_exn : t -> int -> Player.t -> t

val starting : t

val to_ascii : ?viewer:Player.t -> ?home:[`left | `right] -> t -> string
