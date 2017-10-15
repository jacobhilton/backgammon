open Core

module Player = struct
  type t =
    | Forwards
    | Backwards

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
    { bar = Per_player.create_both 0
    ; off = Per_player.create_both 0
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

  let to_ascii { bar; points; off; to_play } =
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
          | 0 -> "  ^  "
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
          (* if Int.(i >= 5) then 2 * (i - 4) else 2 * (4 - i) + 1 *)
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
    let bottom, top = List.split_n points_ascii 12 in
    let bottom_left, bottom_right = List.split_n (List.map bottom ~f:List.rev) 6 in
    let top_left, top_right = List.split_n (List.rev top) 6 in
    let bottom_with_bar =
      bottom_left @ [List.rev (bar_ascii Player.Forwards)] @ bottom_right
    in
    let top_with_bar =
      top_left @ [bar_ascii Player.Backwards] @ top_right
      |> List.map ~f:(List.map ~f:(String.tr ~target:'^' ~replacement:'v')) 
    in
    let transpose_and_add_border half =
      Option.value_exn (List.transpose half)
      |> List.map ~f:(fun l -> "|" ^ String.concat l ~sep:"" ^ "|")
    in
    let numbers_ascii l =
      List.map l ~f:(fun i ->
        (if Int.(i < 10) then "  " else " ") ^ Int.to_string i ^ "  ")
      |> String.concat ~sep:""
    in
    [ to_play_text
    ; off_text Player.Forwards
    ; " " ^ numbers_ascii [24; 23; 22; 21; 20; 19] ^ "     "
      ^ numbers_ascii [18; 17; 16; 15; 14; 13] ^ " "
    ; "-" ^ String.make 65 '-' ^ "-"
    ]
    @ transpose_and_add_border top_with_bar @
    [ "|" ^ String.make 30 '-' ^ "|   |" ^ String.make 30 '-' ^ "|" ]
    @ transpose_and_add_border bottom_with_bar @
    [ "-" ^ String.make 65 '-' ^ "-"
    ; " " ^ numbers_ascii [1; 2; 3; 4; 5; 6] ^ "     "
      ^ numbers_ascii [7; 8; 9; 10; 11; 12] ^ " "
    ; off_text Player.Backwards
    ]
    |> String.concat ~sep:"\n"

  let to_ascii_old { bar = _; points; off = _; to_play = _} =
    let labelled_points = List.mapi points ~f:(fun i p -> (i + 1, p)) in
    let first_half, second_half = List.split_n labelled_points 12 in
    let top_half, bottom_half =
      List.split_n (List.zip_exn first_half (List.rev second_half)) 6
    in
    let ascii_of_half half =
      let ascii_of_label label =
        Core_extended.Printc.lpad ~fill:' ' 2 (Int.to_string label)
      in
      let ascii_of_point point left_or_right =
        let char =
          Option.map (Point.player point) ~f:Player.to_char
          |> Option.value ~default:' '
        in
        let pad =
          let open Core_extended.Printc in
          match left_or_right with
          | `left -> rpad
          | `right -> lpad
        in
        let without_triangle =
          String.make (Point.number point) char
          |> pad ~fill:' ' 8
        in
        match left_or_right with
        | `left -> "> " ^ without_triangle
        | `right -> without_triangle ^ " <"
      in
      List.map half ~f:(fun ((left_label, left_point), (right_label, right_point)) ->
        [ [ String.make 13 ' '; String.make 13 ' ' ]
        ; [ String.make 13 ' '; String.make 13 ' ' ]
        ; [ String.make 13 ' '; String.make 13 ' ' ]
        ; [ String.make 13 ' '; String.make 13 ' ' ]
        ; [ ascii_of_label left_label ^ " " ^ ascii_of_point left_point `left
          ; ascii_of_point right_point `right ^ " " ^ ascii_of_label right_label
          ]
        ]
      )
      |> List.concat
      |> List.tl_exn
      |> List.map ~f:(String.concat ~sep:" | ")
      |> List.map ~f:(fun s -> "| " ^ s ^ " |")
    in
    [ String.make 33 '-' ]
    @ ascii_of_half top_half
    @ [ String.make 33 '-'; "|" ^ String.make 31 ' ' ^ "|"; "|" ^ String.make 31 ' ' ^ "|"; "|" ^ String.make 31 ' ' ^ "|"; String.make 33 '-' ]
    @ ascii_of_half bottom_half
    @ [ String.make 33 '-' ]

  let rotate ascii =
    List.map ascii ~f:(fun s -> String.to_list_rev s |> List.rev)
    |> List.map ~f:Array.of_list
    |> Array.of_list
    |> Array.transpose_exn
    |> Array.to_list
    |> List.map ~f:Array.to_list
    |> List.rev
    |> List.map ~f:String.of_char_list
    |> List.map ~f:(String.tr ~target:'|' ~replacement:'!')
    |> List.map ~f:(String.tr ~target:'-' ~replacement:'|')
    |> List.map ~f:(String.tr ~target:'!' ~replacement:'-')
    |> List.map ~f:(String.tr ~target:'>' ~replacement:'^')
    |> List.map ~f:(String.tr ~target:'<' ~replacement:'v')
end

module Dice = struct
  type t = int * int
end
