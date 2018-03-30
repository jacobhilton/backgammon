open Core
open Tensorflow
open Tensorflow_core

type t =
  { representation : [ `Original | `Modified ]
  ; session : Session.t
  ; type_ : [ `float ] Node.Type.t
  ; input_placeholder : [ `float ] Ops.Placeholder.t
  ; vars : (string * Node.p) list
  ; model : [ `float ] Node.t
  ; output_placeholder : [ `float ] Ops.Placeholder.t
  ; loss : [ `float ] Node.t
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
  let model, vars =
    List.foldi layer_size_pairs ~init:(Ops.Placeholder.to_node input_placeholder, [])
      ~f:(fun i (node_so_far, vars_so_far) (size_from, size_to) ->
        let bias_var = Var.f_or_d [1; size_to] 0. ~type_ in
        let connected_var = Var.normal [size_from; size_to] ~stddev:epsilon_init ~type_ in
        let label s var = (sprintf "%s_%i" s i, Node.P var) in
        ( Ops.(sigmoid ((node_so_far *^ connected_var) + bias_var))
        , label "connected" connected_var :: label "bias" bias_var :: vars_so_far
        ))
  in
  let output_placeholder = Ops.placeholder ~type_ [output_size] in
  let output_node = Ops.Placeholder.to_node output_placeholder in
  let one = Var.f_or_d [output_size] 1. ~type_ in
  let loss =
    Ops.(neg (reduce_mean (output_node * log model + (one - output_node) * log (one - model))))
  in
  let optimizer = Optimizers.adam_minimizer ~learning_rate:(Var.f_or_d [] 0.001 ~type_) loss in
  { representation
  ; session
  ; type_
  ; input_placeholder
  ; vars = List.rev vars
  ; model
  ; output_placeholder
  ; loss
  ; optimizer
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
  let inputs, signs =
    Array.map equity_setups ~f:(fun equity_setup ->
      let { Setup.board; sign } = Setup.create equity_setup t.representation in
      (board, sign))
    |> Array.unzip
  in
  let output_tensors =
    Session.run
      ~inputs:[Session.Input.float t.input_placeholder (Tensor.of_float_array2 inputs Float32)]
      ~session:t.session
      (Session.Output.float t.model)
  in
  Array.map2_exn (Tensor.to_float_array2 output_tensors) signs
    ~f:(fun output sign -> Setup.modifier ~sign (Array.nget output 0))

let train t replay_memory ~minibatch_size ~minibatches_number =
  for _ = 1 to minibatches_number do
    let (inputs, signs), valuations =
      Replay_memory.sample replay_memory minibatch_size
      |> List.map ~f:(fun ({ Setup.board; sign }, valuation) -> ((board, sign), valuation))
      |> Array.of_list
      |> Array.unzip
      |> (fun (x, y) -> (Array.unzip x, y))
    in
    let input_tensors =  Tensor.of_float_array2 inputs Float32 in
    let modified_valuations =
      Array.map2_exn valuations signs ~f:(fun valuation sign -> [| Setup.modifier ~sign valuation |])
    in
    let output_tensors = Tensor.of_float_array2 modified_valuations Float32 in
    let _ =
      Session.run
        ~inputs:
          [ Session.Input.float t.input_placeholder input_tensors
          ; Session.Input.float t.output_placeholder output_tensors
          ]
        ~targets:t.optimizer
        ~session:t.session
        (Session.Output.float t.loss)
    in
    ()
  done

let save t ~filename =
  Session.run
    ~session:t.session
    ~targets:[Node.P (Ops.save ~filename t.vars)]
    Session.Output.empty

let load t ~filename =
  let load_and_assign_nodes =
    List.map t.vars ~f:(fun (label, (Node.P var)) ->
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
