open Core
open Async

type t = Player.t -> Board.t -> Roll.t -> Board.t Deferred.t

let create = Fn.id

let human player board roll = ignore player; ignore board; ignore roll; failwith "hi"

let random player board roll =
  let choices = Set.to_list (Move.all_legal_turn_outcomes roll player board) in
  Deferred.return (List.nth_exn choices (Random.int (List.length choices)))

let vs ts player board roll = (Per_player.get ts player) player board roll

let vs_human t =
  vs (Per_player.create (function
    | Player.Backwards -> human
    | Forwards -> t))

let winner t ~display =
  let rec winner' to_play_option board move_number =
    let to_play, roll =
      match to_play_option with
      | None ->
        let starting_player = if Random.bool () then Player.Forwards else Backwards in
        if display then printf "Player %c to start.\n" (Player.char starting_player);
        starting_player, Roll.generate_starting ()
      | Some to_play_value -> to_play_value, Roll.generate ()
    in
    if display then printf "\n%s\n\n" (Board.to_ascii board ~viewer:to_play);
    match Board.winner board with
    | Some player ->
      if display then printf "Player %c wins.\n" (Player.char player);
      Deferred.return player
    | None ->
      if display then
        printf "Move %i: player %c rolls a %s.\n" move_number (Player.char to_play)
          (Roll.to_string roll);
      t to_play board roll
      >>= fun new_board ->
      winner' (Some (Player.flip to_play)) new_board (move_number + 1)
  in
  winner' None Board.starting 1
