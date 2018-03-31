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
    | Random
    | Pip_count_ratio of { look_ahead : int }
    | Td of
        { td_config : Td_config.t
        ; look_ahead : int
        }
    | Same
  [@@deriving of_sexp]

  let is_human = function
    | Human -> true
    | _ -> false

  let flag player =
    let c = Player.char player in
    let open Command.Param in
    flag (sprintf "-%c" c) (required (sexp_conv t_of_sexp))
      ~doc:(sprintf "SEXP config for player %c" c)

  let unpack = function
    | Human ->
      let stdin = Lazy.force Reader.stdin in
      [], `Game (Game.human ~stdin ())
    | Random -> [], `Equity (Equity.random)
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
        Replay_memory.load replay_memory ~filename Td.Setup.And_valuation.t_of_sexp
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
    ; replay_memory : (Td.Setup.t * float) Replay_memory.t
    }
end

module Instructions = struct
  module Single = struct
    type t =
      | Games of int
      | Train of { minibatch_size : int; minibatches_number: int }
      | Save_ckpt of string
      | Save_play of string
      | Repeat of int * t list
    [@@deriving sexp]
  end

  type t = Single.t list [@@deriving sexp]

  let flag =
    let open Command.Param in
    flag "-instructions" (optional_with_default [Single.Games 1] (sexp_conv t_of_sexp))
      ~doc:"SEXP instructions for playing games and training\ndefault: play one game"
end

type t =
  { game : Game.t
  ; trainee : Trainee.t option
  ; instructions : Instructions.t
  ; display : bool
  ; show_pip_count : bool
  }

let create ~forwards ~backwards ~trainee_config ~instructions ~display_override ~show_pip_count =
  let tds, game_how =
    match forwards, backwards with
    | Game_config.Same, Game_config.Same ->
      failwith "At least one player must be specified explicitly."
    | Same, game_config | game_config, Same ->
      Game_config.unpack game_config
    | game_config_forwards, game_config_backwards ->
      let tds_forwards, games_or_equities_forwards = Game_config.unpack game_config_forwards in
      let tds_backwards, games_or_equities_backwards = Game_config.unpack game_config_backwards in
      (tds_forwards @ tds_backwards, `Vs (games_or_equities_forwards, games_or_equities_backwards))
  in
  begin
    match trainee_config with
    | None -> Deferred.return (None, None)
    | Some trainee_config_value ->
      Trainee_config.unpack trainee_config_value
      >>| fun (td_opt, replay_memory) ->
      td_opt, Some replay_memory
  end
  >>| fun (trainee_td_opt, replay_memory_opt) ->
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
  let make_trainer =
    Equity.mapi ~f:(fun { player; to_play; board } valuation ->
      Option.iter trainee ~f:(fun { td; replay_memory } ->
        Replay_memory.enqueue replay_memory
          (Td.Setup.create { Equity.Setup.player; to_play; board} (Td.representation td), valuation));
      valuation)
  in
  let game =
    match game_how with
    | `Game game -> game
    | `Equity equity -> Game.of_equity (make_trainer equity)
    | `Vs (game_or_equity_forwards, game_or_equity_backwards) ->
      let game_of_game_or_equity = function
        | `Game game -> game
        | `Equity equity -> Game.of_equity (make_trainer equity)
      in
      Game.vs (Per_player.create (function
        | Forwards -> game_of_game_or_equity game_or_equity_forwards
        | Backwards -> game_of_game_or_equity game_or_equity_backwards))
  in
  let display = Game_config.is_human forwards || Game_config.is_human backwards || display_override in
  { game; trainee; instructions; display; show_pip_count }

let play_games { game; trainee; instructions = _; display; show_pip_count } number_of_games =
  let total_wins = ref (Per_player.create_both 0) in
  let gammons = ref (Per_player.create_both 0) in
  let backgammons = ref (Per_player.create_both 0) in
  let increment counter player =
    counter := Per_player.replace !counter player ((Per_player.get !counter player) + 1)
  in
  let rec play game_number prev_replay_memory_enqueued =
    if Int.(game_number > number_of_games) then
      Deferred.unit
    else
      begin
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
        printf "Game %i of %i: player %c wins%s after %i moves. %s %s\n"
          game_number
          number_of_games
          (Player.char winner)
          outcome_text
          number_of_moves
          (results_text Player.Backwards)
          (results_text Player.Forwards);
        let replay_memory_enqueued_opt =
          Option.map trainee ~f:(fun { td = _; replay_memory } -> Replay_memory.enqueued replay_memory)
        in
        begin
          match replay_memory_enqueued_opt with
          | None -> ()
          | Some replay_memory_enqueued ->
            printf "Recording an additional %i equity valuations.\n"
              (replay_memory_enqueued - prev_replay_memory_enqueued)
        end;
        Clock.after (sec 0.01)
        >>= fun () ->
        play (game_number + 1) (Option.value replay_memory_enqueued_opt ~default:0)
      end
  in
  play 1 0

let main t =
  let get_trainee () =
    match t.trainee with
    | None -> failwith "No trainee specified."
    | Some trainee -> trainee
  in
  let rec replace_hashes_with_repetitions s repetitions =
    match repetitions with
    | [] -> s
    | repetition :: repetitions_remaining ->
      let s_new =
        String.rev s
        |> String.substr_replace_first ~pattern:"#" ~with_:(String.rev (Int.to_string repetition))
        |> String.rev
      in
      replace_hashes_with_repetitions s_new repetitions_remaining
  in
  let rec handle_instructions instructions repetitions =
    Deferred.List.iter instructions ~how:`Sequential ~f:(fun instruction ->
      begin
        match instruction with
        | Instructions.Single.Games number_of_games ->
          printf "Playing a sequence of %i games.\n" number_of_games;
          play_games t number_of_games
        | Train { minibatch_size; minibatches_number } ->
          let { Trainee.td; replay_memory } = get_trainee () in
          printf "Training on %i minibatches of size %i.\n" minibatches_number minibatch_size;
          Td.train td replay_memory ~minibatch_size ~minibatches_number;
          Deferred.unit
        | Save_ckpt ckpt_to_save ->
          let filename = replace_hashes_with_repetitions ckpt_to_save repetitions in
          printf "Saving trained parameters to %s.\n" filename;
          let { Trainee.td; replay_memory = _ } = get_trainee () in
          Td.save td ~filename;
          Deferred.unit
        | Save_play play_to_save ->
          let filename = replace_hashes_with_repetitions play_to_save repetitions in
          printf "Saving record of equity valuations to %s.\n" filename;
          let { Trainee.td = _; replay_memory } = get_trainee () in
          Replay_memory.save replay_memory ~filename Td.Setup.And_valuation.sexp_of_t
        | Repeat (number_of_times, inner_instructions) ->
          Deferred.List.iter (List.init number_of_times ~f:((+) 1)) ~how:`Sequential
            ~f:(fun iteration -> handle_instructions inner_instructions (iteration :: repetitions))
      end
      >>= fun () ->
      Clock.after (sec 0.01))
  in
  handle_instructions t.instructions []

let () =
  let open Command.Let_syntax in
  Command.async'
    ~summary:"backgammon"
    [%map_open
      let forwards = Game_config.flag Player.Forwards
      and backwards = Game_config.flag Player.Backwards
      and trainee_config = Trainee_config.flag
      and instructions = Instructions.flag
      and display_override =
        flag "-show-boards" no_arg ~doc:" display boards even if no humans are playing"
      and show_pip_count = flag "-show-pip-count" no_arg ~doc:" display pip count on boards"
      in
      fun () ->
        Random.self_init ();
        create ~forwards ~backwards ~trainee_config ~instructions ~display_override ~show_pip_count
        >>= main
    ]
  |> Command.run
