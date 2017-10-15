open Core

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

let to_ascii ?(viewer=Player.Backwards) ?home { bar; points; off; to_play } =
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
    match viewer, home with
    | _, None | Player.Backwards, Some `left | Forwards, Some `right -> List.rev, Fn.id
    | Backwards, Some `right | Forwards, Some `left -> Fn.id, List.rev
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
  ; off_text (Player.flip viewer)
  ; " " ^ String.concat ~sep:"" (top_order top_numbers) ^ " "
  ; "-" ^ String.make 65 '-' ^ "-"
  ]
  @ transpose_and_add_border (top_order top_board) @
  [ "|" ^ String.make 30 '-' ^ "|   |" ^ String.make 30 '-' ^ "|" ]
  @ transpose_and_add_border (flip (bottom_order bottom_board)) @
  [ "-" ^ String.make 65 '-' ^ "-"
  ; " " ^ String.concat ~sep:"" (bottom_order bottom_numbers) ^ " "
  ; off_text viewer
  ]
  |> String.concat ~sep:"\n"
