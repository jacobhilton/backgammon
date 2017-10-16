open Core

type t =
  { bar : int Per_player.t
  ; off : int Per_player.t
  ; points : Point.t list
  }

let bar t player = Per_player.get t.bar player

let off t player = Per_player.get t.off player

let index player ~position =
  match player with
  | Player.Backwards -> position - 1
  | Forwards -> 24 - position

let point_exn t player ~position =
  List.nth_exn t.points (index player ~position)

let replace_point t player ~position ~f =
  let points =
    List.mapi t.points ~f:(fun i p -> if Int.equal i (index player ~position) then f p else p)
  in
  { t with points }

let remove_from_bar_exn t player =
  match bar t player with
  | 0 -> failwithf "No counters of player %c on the bar to remove" (Player.char player) ()
  | count -> { t with bar = Per_player.replace t.bar player (count - 1) }

let add_to_bar t player =
  { t with bar = Per_player.replace t.bar player (bar t player + 1) }

let add_to_off t player =
  { t with off = Per_player.replace t.off player (off t player + 1) }

let remove_from_point_exn t player ~position =
  replace_point t player ~position ~f:(fun point -> Point.remove_exn point player)

let add_to_point_exn t player ~position =
  replace_point t player ~position ~f:(fun point -> Point.add_exn point player)

let starting =
  { bar = Per_player.create_both 0
  ; off = Per_player.create_both 0
  ; points = begin
      let empty = Point.empty in
      let forwards = Point.create Player.Forwards in
      let backwards = Point.create Player.Backwards in
      [ forwards 2; empty; empty; empty; empty; backwards 5
      ; empty; backwards 3; empty; empty; empty; forwards 5
      ; backwards 5; empty; empty; empty; forwards 3; empty
      ; forwards 5; empty; empty; empty; empty; backwards 2
      ]
    end
  }

let to_ascii ?(viewer=Player.Backwards) ?home { bar; off; points } =
  let off_text player =
    String.of_char (Player.char player) ^ "s borne off: " ^
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
          match Point.occupier point with
          | None -> String.make 5 ' '
          | Some player ->
            let height = i - 1 in
            let player_char = Player.char player in
            let first_column_char =
              if Int.(Point.count point >= height) then player_char else ' '
            in
            let second_column_char =
              if Int.(Point.count point - 8 >= height) then player_char else ' '
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
      let count = Per_player.get bar player in
      let player_char = Player.char player in
      let first_column_char =
        if Int.(count >= from_middle) then player_char else ' '
      in
      let second_column_char =
        if Int.(count - 10 >= from_middle) then player_char else ' '
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
  let positions_ascii quarter =
    List.init 6 ~f:(fun i ->
      let position = (quarter - 1) * 6 + i + 1 in
      (if Int.(position < 10) then "  " else " ") ^ Int.to_string position ^ "  ")
  in
  let top_positions = positions_ascii 3 @ [String.make 5 ' '] @ positions_ascii 4 |> List.rev in
  let bottom_positions = positions_ascii 1 @ [String.make 5 ' '] @ positions_ascii 2 in
  let positions_order =
    match viewer, home with
    | _, Some `left | Player.Backwards, None -> Fn.id
    | _, Some `right | Player.Forwards, None -> List.rev
  in
  [ off_text (Player.flip viewer)
  ; " " ^ String.concat ~sep:"" (positions_order top_positions) ^ " "
  ; "-" ^ String.make 65 '-' ^ "-"
  ]
  @ transpose_and_add_border (top_order top_board) @
  [ "|" ^ String.make 30 '-' ^ "|   |" ^ String.make 30 '-' ^ "|" ]
  @ transpose_and_add_border (flip (bottom_order bottom_board)) @
  [ "-" ^ String.make 65 '-' ^ "-"
  ; " " ^ String.concat ~sep:"" (positions_order bottom_positions) ^ " "
  ; off_text viewer
  ]
  |> String.concat ~sep:"\n"
