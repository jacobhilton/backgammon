type t [@@deriving compare,sexp]

include Core.Comparable.S with type t := t

val bar : t -> player:Player.t -> int

val off : t -> player:Player.t -> int

val point_exn : t -> player:Player.t -> position:int -> Point.t

val remove_from_bar_exn : t -> player:Player.t -> t

val add_to_bar : t -> player:Player.t -> t

val add_to_off : t -> player:Player.t -> t

val remove_from_point_exn : t -> player:Player.t -> position:int -> t

val add_to_point_exn : t -> player:Player.t -> position:int -> t

val furthest_from_off : t -> player:Player.t -> [ `Bar | `Position of int | `Off ]

val winner : t -> (Player.t * [ `Game | `Gammon | `Backgammon ]) option

val pip_count : t -> player:Player.t -> int

val starting : t

val to_ascii
  :  ?show_pip_count:bool
  -> ?viewer:Player.t
  -> ?home:[ `Left | `Right ]
  -> t
  -> string

val to_representation : t -> to_play:Player.t -> float array
