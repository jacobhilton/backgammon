open Core

module Player = struct
  type t =
    | Forwards
    | Backwards
end

module Per_player = struct
  type 'a t =
    { forwards : 'a
    ; backwards : 'a
    }

  let createi f =
    { forwards = f Player.Forwards
    ; backwards = f Backwards
    }

  let create_both x = createi (fun _ -> x)
end

module Point : sig
  type t

  val empty : t

  val create : Player.t -> int -> t

  val forwards : int -> t

  val backwards : int -> t

  val player : t -> Player.t option

  val number : t -> int
end = struct
  type t = int

  let empty = 0

  let create player number =
    match player with
    | Player.Forwards -> Int.abs number
    | Backwards -> - (Int.abs number)

  let forwards number = create Player.Forwards number

  let backwards number = create Player.Backwards number

  let player t =
    match Int.sign t with
    | Sign.Neg -> Some Player.Backwards
    | Zero -> None
    | Pos -> Some Player.Forwards

  let number t = Int.abs t
end

module Dice = struct
  type t = int * int
end

type t =
  { bar : int Per_player.t
  ; borne_off : int Per_player.t
  ; points : Point.t list
  }

let starting =
  { bar = Per_player.create_both 0
  ; borne_off = Per_player.create_both 0
  ; points =
      let open Point in
      [ forwards 2; empty; empty; empty; empty; backwards 5
      ; empty; backwards 3; empty; empty; empty; forwards 5
      ; backwards 5; empty; empty; empty; forwards 3; empty
      ; forwards 5; empty; empty; empty; empty; backwards 2
      ]
  }
