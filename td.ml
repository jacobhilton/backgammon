open Core
open Tensorflow
open Tensorflow_core

type t =
  { representation : [ `Original | `Modified ]
  ; session : Session.t
  ; type_ : [ `float ] Node.Type.t
  ; input_placeholder : [ `float ] Ops.Placeholder.t
  ; vars : (string * [ `float ] Node.t) list
  ; model : [ `float ] Node.t
  ; output_placeholder : [ `float ] Ops.Placeholder.t
  ; check : [ `float ] Node.t
  ; optimizer : Node.p list
  }

let create ?(epsilon_init=0.1) ~hidden_layer_sizes ~representation () =
  let input_size =
    match representation with
    | `Original -> 196
    | `Modified -> 198
  in
  let output_size = 1 in
  let session = Session.create () in
  let type_ = Node.Type.Float in
  let input_placeholder = Ops.placeholder ~type_ [1; input_size] in
  let layer_size_pairs =
    List.zip_exn (input_size :: hidden_layer_sizes) (hidden_layer_sizes @ [output_size])
  in
  let model, connected_vars, labelled_vars, checked_vars =
    List.foldi layer_size_pairs ~init:(Ops.Placeholder.to_node input_placeholder, [], [], [])
      ~f:(fun i (node_so_far, connected_vars_so_far, labelled_vars_so_far, checked_vars_so_far)
           (size_from, size_to) ->
        let bias_var = Var.f_or_d [1; size_to] 0. ~type_ in
        let connected_var = Var.normal [size_from; size_to] ~stddev:epsilon_init ~type_ in
        let check s var =
          `Checked (Ops.checkNumerics ~message:(sprintf "Non-finite %s_%i variable." s i) var)
        in
        let label s var = (sprintf "%s_%i" s i, var) in
        ( Ops.(sigmoid ((node_so_far *^ connected_var) + bias_var))
        , connected_var :: connected_vars_so_far
        , label "connected" connected_var :: label "bias" bias_var :: labelled_vars_so_far
        , check "connected" connected_var :: check "bias" bias_var :: checked_vars_so_far
        ))
  in
  let output_placeholder = Ops.placeholder ~type_ [1; output_size] in
  let output_node = Ops.Placeholder.to_node output_placeholder in
  let one = Ops.f_or_d ~shape:[1; output_size] ~type_ 1. in
  let unregularised_loss =
    Ops.(neg (output_node * log model + (one - output_node) * log (one - model)))
    |> Ops.reduce_sum ~dims:[1]
  in
  let regularisation =
    List.map connected_vars ~f:(fun connected_var ->
      Ops.reshape connected_var (Ops.ci32 ~shape:[1] [-1]))
    |> Ops.concat (Ops.ci32 ~shape:[] [0])
    |> Ops.reduce_mean ~dims:[0]
    |> Ops.( * ) (Ops.f_or_d ~shape:[1] ~type_ 0.000001)
  in
  let loss =
    Ops.(unregularised_loss + regularisation)
    |> Ops.reduce_mean ~dims:[0]
  in
  let optimizer =
    Optimizers.adam_minimizer ~learning_rate:(Ops.f_or_d ~shape:[] ~type_ 0.001) loss
  in
  let check =
    `Checked (Ops.checkNumerics loss ~message:"Non-finite loss.") :: checked_vars
    |> List.rev
    |> List.map ~f:(fun (`Checked node) -> Ops.reshape node (Ops.ci32 ~shape:[1] [-1]))
    |> Ops.concat (Ops.ci32 ~shape:[] [0])
  in
  { representation
  ; session
  ; type_
  ; input_placeholder
  ; vars = List.rev labelled_vars
  ; model
  ; output_placeholder
  ; optimizer
  ; check
  }

let representation t = t.representation

module Setup = struct
  type t =
    { board : float array
    ; sign : float
    } [@@deriving sexp]

  let create { Equity.Setup.player; to_play; board } version =
    { board = Board.to_representation board version ~to_play
    ; sign = if Player.equal to_play player then 1. else -1.
    }

  let modifier ~sign valuation =
    Float.(+) 0.5 (Float.( * ) Float.(valuation - 0.5) sign)

  module And_valuation = struct
    type nonrec t = t * float [@@deriving sexp]
  end
end

let eval t equity_setups =
  let boards, signs =
    Array.map equity_setups ~f:(fun equity_setup ->
      let { Setup.board; sign } = Setup.create equity_setup t.representation in
      (board, sign))
    |> Array.unzip
  in
  let valuations =
    Session.run
      ~inputs:[Session.Input.float t.input_placeholder (Tensor.of_float_array2 boards Float32)]
      ~session:t.session
      (Session.Output.float t.model)
  in
  Array.map2_exn signs (Tensor.to_float_array2 valuations)
    ~f:(fun sign valuation -> Setup.modifier ~sign (Array.nget valuation 0))

let train t replay_memory ~minibatch_size ~minibatches_number =
  for _ = 1 to minibatches_number do
    let (boards, signs), valuations =
      Replay_memory.sample replay_memory minibatch_size
      |> List.map ~f:(fun ({ Setup.board; sign }, valuation) -> ((board, sign), valuation))
      |> Array.of_list
      |> Array.unzip
      |> Tuple2.map_fst ~f:Array.unzip
    in
    let modified_valuations =
      Array.map2_exn signs valuations ~f:(fun sign valuation -> [| Setup.modifier ~sign valuation |])
    in
    let _ =
      Session.run
        ~inputs:
          [ Session.Input.float t.input_placeholder (Tensor.of_float_array2 boards Float32)
          ; Session.Input.float t.output_placeholder
              (Tensor.of_float_array2 modified_valuations Float32)
          ]
        ~targets:t.optimizer
        ~session:t.session
        (Session.Output.float t.check)
    in
    ()
  done

let save t ~filename =
  let vars = List.map t.vars ~f:(Tuple2.map_snd ~f:(fun var -> Node.P var)) in
  Session.run
    ~session:t.session
    ~targets:[Node.P (Ops.save ~filename vars)]
    Session.Output.empty

let load t ~filename =
  let load_and_assign_nodes =
    List.map t.vars ~f:(fun (label, var) ->
      Ops.restore
        ~type_:(Node.output_type var)
        (Ops.const_string ~shape:[] [filename])
        (Ops.const_string ~shape:[] [label])
      |> Ops.assign var
      |> fun node -> Node.P node)
  in
  Session.run
    ~session:t.session
    ~targets:load_and_assign_nodes
    Session.Output.empty

let sexp_of_vars t =
  List.map t.vars ~f:(Tuple2.map_snd ~f:(fun var ->
    Session.run
      ~session:t.session
      (Session.Output.float var)
    |> Tensor.to_float_array2))
  |> [%sexp_of:(string * float array array) list]
