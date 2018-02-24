open Core
open Async

module Game_config = struct
  type t =
    | Human
    | Pip_count_ratio of { look_ahead : int }
    | Td of
        { look_ahead : int
        ; hidden_layer_sizes : int list
        ; representation : [ `Original | `Modified ] sexp_option
        ; ckpt_to_load : string option
        }
    | Same
  [@@deriving of_sexp]

  let flag player =
    let c = Player.char player in
    let open Command.Param in
    flag (sprintf "-%c" c) (required (sexp_conv t_of_sexp))
      ~doc:(sprintf "SEXP config for player %c" c)

  let unpack = function
    | Human ->
      let stdin = Lazy.force Reader.stdin in
      [], `Game (Game.human ~stdin)
    | Pip_count_ratio { look_ahead } ->
      [], `Equity (Equity.minimax Equity.pip_count_ratio ~look_ahead)
    | Td { look_ahead; hidden_layer_sizes; representation; ckpt_to_load } ->
      let representation = Option.value representation ~default:`Modified in
      let td = Td.create ~hidden_layer_sizes ~representation () in
      begin
        match ckpt_to_load with
        | None -> ()
        | Some filename -> Td.load td ~filename
      end;
      [td], `Equity (Equity.minimax' (Td.eval td) ~look_ahead)
    | Same -> failwith "Cannot unpack Same."
end

module Trainee_config = struct
  type t =
    | Td of
        { hidden_layer_sizes : int list
        ; representation : [ `Original | `Modified ] sexp_option
        ; ckpt_to_load : string option
        ; ckpt_to_save : string
        ; learning_rate_per_batch_item : float sexp_option
        }
    | Same of
        { ckpt_to_save : string
        ; learning_rate_per_batch_item : float sexp_option
        }
  [@@deriving of_sexp]

  let flag =
    let open Command.Param in
    flag "-train" (optional (sexp_conv t_of_sexp)) ~doc:"SEXP config for trainee"

  let unpack = function
    | Td
        { hidden_layer_sizes
        ; representation
        ; ckpt_to_load
        ; ckpt_to_save
        ; learning_rate_per_batch_item
        } ->
      let representation = Option.value representation ~default:`Modified in
      let td = Td.create ~hidden_layer_sizes ~representation () in
      begin
        match ckpt_to_load with
        | None -> ()
        | Some filename -> Td.load td ~filename
      end;
      Some td, ckpt_to_save, learning_rate_per_batch_item
    | Same
        { ckpt_to_save
        ; learning_rate_per_batch_item
        } -> None, ckpt_to_save, learning_rate_per_batch_item
end

module Trainee = struct
  type t =
    { td : Td.t
    ; ckpt_to_save : string
    ; learning_rate_per_batch_item : float option
    }
end

let main ~forwards ~backwards ~trainee_config ~games ~display ~show_pip_count =
  Random.self_init ();
  let setups_and_valuations = ref [] in
  let make_trainer =
    Equity.mapi ~f:(fun ~to_play player board valuation ->
      if Option.is_some trainee_config then
        setups_and_valuations :=
          ((`To_play to_play, player, board), valuation) :: !setups_and_valuations;
      valuation)
  in
  let tds, game_how =
    let unpack_and_make_trainer game_config =
      let tds, game_or_equity = Game_config.unpack game_config in
      let game_how =
        match game_or_equity with
        | `Game game -> `Game game
        | `Equity equity -> `Equity (make_trainer equity)
      in
      (tds, game_how)
    in
    match forwards, backwards with
    | Game_config.Same, Game_config.Same ->
      failwith "At least one player must be specified explicitly."
    | Same, game_config | game_config, Same ->
      unpack_and_make_trainer game_config
    | game_config_forwards, game_config_backwards ->
      let tds_forwards, game_how_forwards = unpack_and_make_trainer game_config_forwards in
      let tds_backwards, game_how_backwards = unpack_and_make_trainer game_config_backwards in
      (tds_forwards @ tds_backwards, `Vs (game_how_forwards, game_how_backwards))
  in
  let trainee =
    Option.map trainee_config ~f:(fun trainee_config_value ->
      let td_opt, ckpt_to_save, learning_rate_per_batch_item =
        Trainee_config.unpack trainee_config_value
      in
      let td =
        match td_opt with
        | Some td -> td
        | None ->
          match tds with
          | [td] -> td
          | [] | _ :: _ :: _ -> failwith "Trainee must be specified explicitly."
      in
      { Trainee.td; ckpt_to_save; learning_rate_per_batch_item })
  in
  let game =
    match game_how with
    | `Game game -> game
    | `Equity equity -> Game.of_equity equity
    | `Vs (game_or_equity_forwards, game_or_equity_backwards) ->
      let game_of_game_or_equity = function
        | `Game game -> game
        | `Equity equity -> Game.of_equity equity
      in
      Game.vs (Per_player.create (function
        | Forwards -> game_of_game_or_equity game_or_equity_forwards
        | Backwards -> game_of_game_or_equity game_or_equity_backwards))
  in
  let total_wins = ref (Per_player.create_both 0) in
  let gammons = ref (Per_player.create_both 0) in
  let backgammons = ref (Per_player.create_both 0) in
  let increment counter player =
    counter := Per_player.replace !counter player ((Per_player.get !counter player) + 1)
  in
  let rec run game_number =
    if Int.(game_number > games) then
      Deferred.unit
    else
      begin
        setups_and_valuations := [];
        Game.winner ~display ~show_pip_count game
        >>= fun (winner, outcome, `Moves number_of_moves) ->
        increment total_wins winner;
        let outcome_text =
          match outcome with
          | `Game -> ""
          | `Gammon -> increment gammons winner; " a gammon"
          | `Backgammon -> increment backgammons winner; " a backgammon"
        in
        let results_text player =
          let total_wins = Per_player.get !total_wins player in
          let describe s number =
            if Int.equal number 1 then sprintf "1 was a %s" s else sprintf "%i were %ss" number s
          in
          sprintf "Player %c has won %i game%s, of which %s and %s."
            (Player.char player)
            total_wins
            (if Int.equal total_wins 1 then "" else "s")
            (describe "gammon" (Per_player.get !gammons player))
            (describe "backgammon" (Per_player.get !backgammons player))
        in
        let training_text =
          match trainee with
          | None -> ""
          | Some { td; ckpt_to_save = _; learning_rate_per_batch_item } ->
            let learning_rate_per_batch_item =
              Option.value learning_rate_per_batch_item ~default:0.1
            in
            Td.train td ~learning_rate_per_batch_item (Array.of_list !setups_and_valuations);
            sprintf " Training on %i observed equity valuations." (List.length !setups_and_valuations)
        in
        printf "Game %i of %i: player %c wins%s after %i plies. %s %s%s\n"
          game_number
          games
          (Player.char winner)
          outcome_text
          number_of_moves
          (results_text Player.Backwards)
          (results_text Player.Forwards)
          training_text;
        Clock.after (sec 0.01)
        >>= fun () ->
        run (game_number + 1)
      end
  in
  run 1
  >>= fun () ->
  begin
    match trainee with
    | None -> ()
    | Some { td; ckpt_to_save; learning_rate_per_batch_item = _ } -> Td.save td ~filename:ckpt_to_save
  end;
  Deferred.unit

let () =
  let open Command.Let_syntax in
  Command.async'
    ~summary:"backgammon"
    [%map_open
      let games =
        flag "-games" (optional_with_default 1 int) ~doc:"N number of games to play\ndefault: 1"
      and forwards = Game_config.flag Player.Forwards
      and backwards = Game_config.flag Player.Backwards
      and trainee_config = Trainee_config.flag
      and display = flag "-show-boards" no_arg ~doc:" display boards"
      and show_pip_count = flag "-show-pip-count" no_arg ~doc:" display pip count on boards"
      in
      fun () ->
        main ~games ~forwards ~backwards ~trainee_config ~display ~show_pip_count
    ]
  |> Command.run
