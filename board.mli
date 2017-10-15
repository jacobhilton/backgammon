type t

val starting : t

val to_ascii : ?viewer:Player.t -> ?home:[`left | `right] -> t -> string
