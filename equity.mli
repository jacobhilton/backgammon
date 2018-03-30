module Setup : sig
  type t =
    { player : Player.t
    ; to_play : Player.t
    ; board : Board.t
    }
end

type t

val create : (Setup.t -> float) -> t

val eval : t -> Setup.t -> float

val mapi : t -> f:(Setup.t -> float -> float) -> t

val minimax : t -> look_ahead:int -> Outcome.t -> t

val minimax' : (Setup.t array -> float array) -> look_ahead:int -> Outcome.t -> t

val pip_count_ratio : t
