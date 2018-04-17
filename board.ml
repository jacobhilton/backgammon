open Core

module T = struct
  type t =
    { bar : int Per_player.t
    ; off : int Per_player.t
    ; points : Point.t list
    }
  [@@deriving compare,sexp]
end
include T
include Comparable.Make(T)

let bar t ~player = Per_player.get t.bar player

let off t ~player = Per_player.get t.off player

let index_of_position ~player ~position =
  match player with
  | Player.Backwards -> position - 1
  | Forwards -> 24 - position

let position_of_index ~player ~index =
  match player with
  | Player.Backwards -> index + 1
  | Forwards -> 24 - index

let point_exn t ~player ~position =
  List.nth_exn t.points (index_of_position ~player ~position)

let replace_point t ~player ~position ~f =
  let points =
    List.mapi t.points ~f:(fun i p ->
      if Int.equal i (index_of_position ~player ~position) then f p else p)
  in
  { t with points }

let remove_from_bar_exn t ~player =
  match bar t ~player with
  | 0 -> failwithf "No counters of player %c on the bar to remove" (Player.char player) ()
  | count -> { t with bar = Per_player.replace t.bar player (count - 1) }

let add_to_bar t ~player =
  { t with bar = Per_player.replace t.bar player (bar t ~player + 1) }

let add_to_off t ~player =
  { t with off = Per_player.replace t.off player (off t ~player + 1) }

let remove_from_point_exn t ~player ~position =
  replace_point t ~player ~position ~f:(fun point -> Point.remove_exn point player)

let add_to_point_exn t ~player ~position =
  replace_point t ~player ~position ~f:(fun point -> Point.add_exn point player)

let order player =
  match player with
  | Player.Forwards -> Fn.id
  | Backwards -> List.rev

let furthest_from_off t ~player =
  if Int.(Per_player.get t.bar player > 0) then
    `Bar
  else
    List.findi (order player t.points) ~f:(fun _ point ->
      Option.map (Point.occupier point) ~f:(Player.equal player)
      |> Option.value ~default:false)
    |> Option.map ~f:(fun (index, _) -> `Position (position_of_index ~player:Player.Forwards ~index))
    |> Option.value ~default:`Off

let winner t =
  let outcome_if_none_borne_off loser =
    match furthest_from_off t ~player:loser with
    | `Bar -> Outcome.Backgammon
    | `Position position -> if Int.(position > 18) then Backgammon else Gammon
    | `Off -> Gammon
  in
  match Per_player.get t.off Forwards, Per_player.get t.off Backwards with
  | 15, 15 -> None
  | 15, 0 -> Some (Player.Forwards, outcome_if_none_borne_off Backwards)
  | 15, _ -> Some (Forwards, Game)
  | 0, 15 -> Some (Backwards, outcome_if_none_borne_off Forwards)
  | _, 15 -> Some (Backwards, Game)
  | _, _ -> None

let pip_count t ~player =
  25 * Per_player.get t.bar player +
  begin
    List.mapi t.points ~f:(fun index point ->
      position_of_index ~player ~index * Point.count point player)
    |> List.fold ~init:0 ~f:(+)
  end

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

let to_ascii ?(show_pip_count=false) ?(viewer=Player.Backwards) ?home t =
  let off_text player =
    sprintf "%cs borne off: %s" (Player.char player)
      begin
        match Per_player.get t.off player with
        | 0 -> "none"
        | n -> Int.to_string n
      end
  in
  let pip_count_text player =
    if show_pip_count then
      sprintf "Player %c pip count: %i" (Player.char player) (pip_count t ~player)
    else
      ""
  in
  let off_and_pip_count_text player =
    let off_text_string = off_text player in
    let pip_count_text_string = pip_count_text player in
    let number_of_spaces =
      Int.max 1 (67 - String.length (off_text_string) - String.length (pip_count_text_string))
    in
    off_text_string ^ String.make number_of_spaces ' ' ^ pip_count_text_string
  in
  let points_ascii =
    List.map t.points ~f:(fun point ->
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
              if Int.(Point.count point player >= height) then player_char else ' '
            in
            let second_column_char =
              if Int.(Point.count point player - 8 >= height) then player_char else ' '
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
      let count = Per_player.get t.bar player in
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
    | _, None | Player.Backwards, Some `Left | Forwards, Some `Right -> List.rev, Fn.id
    | Backwards, Some `Right | Forwards, Some `Left -> Fn.id, List.rev
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
  let top_positions = positions_ascii 3 @ [String.make 5 ' '] @ positions_ascii 4 in
  let bottom_positions = positions_ascii 1 @ [String.make 5 ' '] @ positions_ascii 2 in
  let top_positions_order, bottom_positions_order =
    match viewer, home with
    | _, Some `Left | Player.Backwards, None -> List.rev, Fn.id
    | _, Some `Right | Player.Forwards, None -> Fn.id, List.rev
  in
  [ off_and_pip_count_text (Player.flip viewer)
  ; " " ^ String.concat ~sep:"" (top_positions_order top_positions) ^ " "
  ; "-" ^ String.make 65 '-' ^ "-"
  ]
  @ transpose_and_add_border (top_order top_board) @
  [ "|" ^ String.make 30 '-' ^ "|   |" ^ String.make 30 '-' ^ "|" ]
  @ transpose_and_add_border (flip (bottom_order bottom_board)) @
  [ "-" ^ String.make 65 '-' ^ "-"
  ; " " ^ String.concat ~sep:"" (bottom_positions_order bottom_positions) ^ " "
  ; off_and_pip_count_text viewer
  ]
  |> String.concat ~sep:"\n"

let to_representation t version ~to_play =
  let bar_representation =
    Per_player.map t.bar ~f:(fun count ->
      match version with
      | `Original -> [Int.to_float count /. 2.]
      | `Modified ->
        [ if Int.(count >= 1) then 1. else 0.
        ; if Int.(count >= 2) then Float.(/) (Int.to_float (count - 1)) 2. else 0.
        ]
      | `Expanded ->
        [ if Int.(count >= 1) then 1. else 0.
        ; if Int.(count >= 2) then 1. else 0.
        ; if Int.(count >= 3) then 1. else 0.
        ; if Int.(count >= 4) then Float.(/) (Int.to_float (count - 3)) 2. else 0.
        ])
  in
  let off_representation =
    Per_player.map t.off ~f:(fun count ->
      match version with
      | `Original | `Modified -> [Int.to_float count /. 15.]
      | `Expanded -> List.init 15 ~f:(fun i -> if Int.(count >= i + 1) then 1. else 0.))
  in
  let points_representation =
    List.map t.points ~f:(fun point -> Point.to_representation point version)
  in
  let representation player =
    Per_player.get bar_representation player
    @ Per_player.get off_representation player
    @ List.concat (List.map (order player points_representation) ~f:(fun x -> Per_player.get x player))
  in
  representation Forwards @ (List.rev (representation Backwards))
  |> order to_play


(* From import.c in the gnubg source code:
 *
 * Snowie .txt files
 *
 * The files are a single line with fields separated by
 * semicolons. Fields are numeric, except for player names.
 *
 * Field no    meaning
 * 0           length of match (0 in money games)
 * 1           1 if Jacoby enabled, 0 in match play or disabled
 * 2           Don't know, all samples had 0. Maybe it's Nack gammon or
 *            some other variant?
 * 3           Don't know. It was one in all money game samples, 0 in
 *            match samples
 * 4           Player on roll 0 = 1st player
 * 5,6         Player names
 * 7           1 = Crawford game
 * 8,9         Scores for player 0, 1
 * 10          Cube value
 * 11          Cube owner 1 = player on roll, 0 = centred, -1 opponent
 * 12          Chequers on bar for player on roll
 * 13..36      Points 1..24 from player on roll's point of view
 *            0 = empty, positive nos. for player on roll, negative
 *            for opponent
 * 37          Chequers on bar for opponent
 * 38.39       Current roll (0,0 if not rolled)
 *
 *)

let to_snowie t ~to_play roll =
  let str = List.map ~f:Int.to_string in
  begin
    str [1; 0; 0; 0; 0]
    @ List.map [Player.char to_play; Player.char (Player.flip to_play)] ~f:String.of_char
    @ str [0; 0; 0; 1; 0]
    @ str [Per_player.get t.bar to_play]
    @ begin
      List.map t.points ~f:(fun point ->
        Int.(Point.count point to_play - Point.count point (Player.flip to_play)))
      |> order (Player.flip to_play)
      |> str
    end
    @ str [Per_player.get t.bar (Player.flip to_play)]
    @ str begin
      match roll with
      | Some (Roll.Double i) -> [i; i]
      | Some (High_low (i, j)) -> [i; j]
      | None -> [0; 0]
    end
  end
  |> String.concat ~sep:";"

let of_snowie s =
  Or_error.try_with (fun () ->
    let fields = String.split s ~on:';' in
    if Int.(List.length fields < 40) then failwith "not enough fields";
    let to_play_field = List.nth_exn fields 5 in
    let to_play =
      match String.to_list to_play_field with
      | [c] when Char.equal c Player.(char Forwards) -> Player.Forwards
      | [c] when Char.equal c Player.(char Backwards) -> Player.Backwards
      | _ -> failwithf "invalid player on roll %s" to_play_field ()
    in
    let board_fields, roll_fields =
      List.split_n fields 12
      |> snd
      |> (fun l -> List.split_n l 26)
      |> Tuple2.map_snd ~f:(fun l -> List.split_n l 2 |> fst)
      |> Tuple2.map_fst ~f:(List.map ~f:Int.of_string)
      |> Tuple2.map_snd ~f:(List.map ~f:Int.of_string)
    in
    let roll =
      match roll_fields with
      | [0; 0] -> None
      | [first_roll; second_roll] ->
        begin
          if Int.(first_roll < 1 || first_roll > 6 || second_roll < 1 || second_roll > 6) then
            failwithf "invalid roll %i-%i" first_roll second_roll ();
          if Int.equal first_roll second_roll then
            Some (Roll.Double first_roll)
          else if Int.(first_roll > second_roll) then
            Some (High_low (first_roll, second_roll))
          else
            Some (High_low (second_roll, first_roll))
        end
      | _ -> failwith "unreachable"
    in
    let bar_to_play_field, (points_fields, bar_not_to_play_field) =
      List.split_n board_fields 1
      |> Tuple2.map_fst ~f:List.hd_exn
      |> Tuple2.map_snd ~f:(fun l -> List.split_n l 24)
      |> Tuple2.map_snd ~f:(Tuple2.map_snd ~f:List.hd_exn)
    in
    let check_bar_field i =
      if Int.(i < 0) then failwithf "negative number of counters on the bar %i" i ()
    in
    check_bar_field bar_to_play_field;
    check_bar_field bar_not_to_play_field;
    let bar =
      Per_player.create (fun player ->
        if Player.equal player to_play then bar_to_play_field else bar_not_to_play_field)
    in
    let points =
      List.map points_fields ~f:(fun point_field ->
        if Int.(point_field >= 0) then
          Point.create to_play point_field
        else
          Point.create (Player.flip to_play) (Int.abs point_field)
      )
      |> order (Player.flip to_play)
    in
    let off =
      Per_player.create (fun player ->
        let total_not_off =
          Int.(
            Per_player.get bar player
            + List.fold points ~init:0 ~f:(fun total point -> total + Point.count point player))
        in
        if Int.(total_not_off > 15) then
          failwithf "too many counters of player %c in play %i" (Player.char player) total_not_off ();
        Int.(15 - total_not_off))
    in
    { bar; off; points }, `To_play to_play, roll)
