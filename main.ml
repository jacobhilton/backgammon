open Core
open Async

module Td_config = struct
  type t =
    { hidden_layer_sizes : int list
    ; representation : [ `Original | `Modified ] sexp_option
    ; ckpt_to_load : string option
    } [@@deriving of_sexp]

  let unpack { hidden_layer_sizes; representation; ckpt_to_load } =
    let representation = Option.value representation ~default:`Modified in
    let td = Td.create ~hidden_layer_sizes ~representation () in
    begin
      match ckpt_to_load with
      | None -> ()
      | Some filename -> Td.load td ~filename
    end;
    td
end

module Game_config = struct
  type t =
    | Human
    | Pip_count_ratio of { look_ahead : int }
    | Td of
        { td_config : Td_config.t
        ; look_ahead : int
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
      [], `Equity (Equity.minimax Equity.pip_count_ratio ~look_ahead Game)
    | Td { look_ahead; td_config } ->
      let td = Td_config.unpack td_config in
      [td], `Equity (Equity.minimax' (Td.eval td) ~look_ahead Game)
    | Same -> failwith "Cannot unpack Same."
end

module Replay_memory_config = struct
  type t =
    { capacity : int option
    ; play_to_load : string option
    }
  [@@deriving of_sexp]

  let unpack { capacity; play_to_load } =
    let replay_memory = Replay_memory.create ~capacity in
    begin
      match play_to_load with
      | None -> Deferred.unit
      | Some filename ->
        Replay_memory.load replay_memory ~filename Equity.Setup.And_valuation.t_of_sexp
    end
    >>| fun () ->
    replay_memory
end

module Trainee_config = struct
  type t =
    | Td of
        { td_config : Td_config.t
        ; replay_memory_config : Replay_memory_config.t
        }
    | Same of { replay_memory_config : Replay_memory_config.t }
  [@@deriving of_sexp]

  let flag =
    let open Command.Param in
    flag "-train" (optional (sexp_conv t_of_sexp)) ~doc:"SEXP config for trainee"

  let unpack t =
    let td_opt =
      match t with
      | Td { td_config; replay_memory_config = _ } -> Some (Td_config.unpack td_config)
      | Same { replay_memory_config = _ } -> None
    in
    begin
      match t with
      | Td { td_config = _; replay_memory_config } | Same { replay_memory_config } ->
        Replay_memory_config.unpack replay_memory_config
    end
    >>| fun replay_memory ->
    td_opt, replay_memory
end

module Trainee = struct
  type t =
    { td : Td.t
    ; replay_memory : (Equity.Setup.t * float) Replay_memory.t
    }
end

let main ~forwards ~backwards ~trainee_config ~games ~display ~show_pip_count =
  Random.self_init ();
  begin
    match trainee_config with
    | None -> Deferred.return (None, None)
    | Some trainee_config_value ->
      Trainee_config.unpack trainee_config_value
      >>| fun (td_opt, replay_memory) ->
      td_opt, Some replay_memory
  end
  >>= fun (trainee_td_opt, replay_memory_opt) ->
  let valuation_count = ref 0 in
  let make_trainer =
    Equity.mapi ~f:(fun { player; to_play; board } valuation ->
      Option.iter replay_memory_opt ~f:(fun replay_memory ->
        Replay_memory.enqueue replay_memory ({ Equity.Setup.player; to_play; board}, valuation));
      valuation_count := !valuation_count + 1;
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
    Option.bind replay_memory_opt ~f:(fun replay_memory ->
      let td =
        match trainee_td_opt with
        | Some td -> td
        | None ->
          match tds with
          | [td] -> td
          | [] | _ :: _ :: _ -> failwith "Trainee must be specified explicitly."
      in
      Some { Trainee.td; replay_memory })
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
        valuation_count := 0;
        Game.winner ~display ~show_pip_count game
        >>= fun (winner, outcome, `Moves number_of_moves) ->
        increment total_wins winner;
        begin
          match outcome with
          | Outcome.Game -> ()
          | Gammon -> increment gammons winner
          | Backgammon -> increment backgammons winner
        end;
        let outcome_text = Outcome.to_phrase outcome in
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
          | Some _ -> sprintf " Recording additional %i observed equity valuations." !valuation_count
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
    | Some { td; replay_memory = _ } -> Td.save td ~filename:"test.ckpt" (* CR *)
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
