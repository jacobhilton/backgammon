open Core

module Player = struct
  type t =
    | Forwards
    | Backwards

  let flip = function
    | Forwards -> Backwards
    | Backwards -> Forwards

  let to_char = function
    | Forwards -> 'O'
    | Backwards -> 'X'
end

module Per_player : sig
  type 'a t

  val createi : (Player.t -> 'a) -> 'a t

  val create_both : 'a -> 'a t

  val get : 'a t -> Player.t -> 'a
end = struct
  type 'a t =
    { forwards : 'a
    ; backwards : 'a
    }

  let createi f =
    { forwards = f Player.Forwards
    ; backwards = f Backwards
    }

  let create_both x = createi (fun _ -> x)

  let get { forwards; backwards} player =
    match player with
    | Player.Forwards -> forwards
    | Backwards -> backwards
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
    let n = Int.abs number in
    match player with
    | Player.Forwards -> n
    | Backwards -> -n

  let forwards number = create Player.Forwards number

  let backwards number = create Player.Backwards number

  let player t =
    match Int.sign t with
    | Sign.Neg -> Some Player.Backwards
    | Zero -> None
    | Pos -> Some Player.Forwards

  let number t = Int.abs t
end

module Board = struct
  type t =
    { bar : int Per_player.t
    ; points : Point.t list
    ; off : int Per_player.t
    ; to_play : Player.t option
    }

  let starting =
    { bar = Per_player.create_both 1
    ; off = Per_player.create_both 1
    ; points = begin
        let open Point in
        [ forwards 2; empty; empty; empty; empty; backwards 5
        ; empty; backwards 3; empty; empty; empty; forwards 5
        ; backwards 5; empty; empty; empty; forwards 3; empty
        ; forwards 5; empty; empty; empty; empty; backwards 2
        ]
      end
    ; to_play = None
    }

  let to_ascii ?(viewer=Player.Backwards) ?(home=`left) { bar; points; off; to_play } =
    let to_play_text =
      match to_play with
      | None -> "Start of play."
      | Some player -> String.of_char (Player.to_char player) ^ " to play."
    in
    let off_text player =
      String.of_char (Player.to_char player) ^ "s borne off: " ^
      match Per_player.get off player with
      | 0 -> "none"
      | n -> Int.to_string n
    in
    let points_ascii =
      List.map points ~f:(fun point ->
        List.init 10 ~f:(fun i ->
          match i with
          | 0 -> "  v  "
          | 1 -> String.make 5 ' '
          | _ ->
            match Point.player point with
            | None -> String.make 5 ' '
            | Some player ->
              let height = i - 1 in
              let player_char = Player.to_char player in
              let first_column_char =
                if Int.(Point.number point >= height) then player_char else ' '
              in
              let second_column_char =
                if Int.(Point.number point - 8 >= height) then player_char else ' '
              in
              String.init 5 ~f:(function
                | 2 -> first_column_char
                | 3 -> second_column_char
                | _ -> ' ')))
    in
    let bar_ascii player =
      List.init 10 ~f:(fun i ->
        let from_middle =
          if Int.(i >= 5) then 2 * (i - 5) + 1 else 2 * (5 - i)
        in
        let number = Per_player.get bar player in
        let player_char = Player.to_char player in
        let first_column_char =
          if Int.(number >= from_middle) then player_char else ' '
        in
        let second_column_char =
          if Int.(number - 10 >= from_middle) then player_char else ' '
        in
        String.init 5 ~f:(function
          | 2 -> first_column_char
          | 3 -> second_column_char
          | 0 | 4 -> '|'
          | _ -> ' '))
    in
    let backwards_points, forwards_points = List.split_n points_ascii 12 in
    let backwards_home, backwards_outer = List.split_n backwards_points 6 in
    let forwards_outer, forwards_home = List.split_n forwards_points 6 in
    let backwards_board = backwards_home @ [bar_ascii Player.Forwards] @ backwards_outer in
    let forwards_board = forwards_outer @ [bar_ascii Player.Backwards] @ forwards_home in
    let top_board, bottom_board =
      match viewer with
      | Player.Backwards -> forwards_board, backwards_board
      | Forwards -> backwards_board, forwards_board
    in
    let top_order, bottom_order =
      match home with
      | `left -> List.rev, Fn.id
      | `right -> Fn.id, List.rev
    in
    let flip half =
      List.map half ~f:(fun l ->
        List.map l ~f:(String.tr ~target:'v' ~replacement:'^')
        |> List.rev)
    in
    let transpose_and_add_border half =
      Option.value_exn (List.transpose half)
      |> List.map ~f:(fun l -> "|" ^ String.concat l ~sep:"" ^ "|")
    in
    let numbers_ascii quarter =
      List.init 6 ~f:(fun i ->
        let number = (quarter - 1) * 6 + i + 1 in
        (if Int.(number < 10) then "  " else " ") ^ Int.to_string number ^ "  ")
    in
    let backwards_numbers = numbers_ascii 1 @ [String.make 5 ' '] @ numbers_ascii 2 in
    let forwards_numbers = numbers_ascii 3 @ [String.make 5 ' '] @ numbers_ascii 4 in
    let top_numbers, bottom_numbers =
      match viewer with
      | Player.Backwards -> forwards_numbers, backwards_numbers
      | Forwards -> backwards_numbers, forwards_numbers
    in
    [ to_play_text
    ; off_text Player.Forwards
    ; " " ^ String.concat ~sep:"" (top_order top_numbers) ^ " "
    ; "-" ^ String.make 65 '-' ^ "-"
    ]
    @ transpose_and_add_border (top_order top_board) @
    [ "|" ^ String.make 30 '-' ^ "|   |" ^ String.make 30 '-' ^ "|" ]
    @ transpose_and_add_border (flip (bottom_order bottom_board)) @
    [ "-" ^ String.make 65 '-' ^ "-"
    ; " " ^ String.concat ~sep:"" (bottom_order bottom_numbers) ^ " "
    ; off_text Player.Backwards
    ]
    |> String.concat ~sep:"\n"
end

module Dice = struct
  type t = int * int
end
