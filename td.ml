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
  let loss = Ops.(neg (reduce_mean (Placeholder.to_node output_placeholder * log model))) in
  { representation
  ; session
  ; type_
  ; input_placeholder
  ; vars = List.rev vars
  ; model
  ; output_placeholder
  ; loss
  }

let tensors_and_transforms setups version =
  let inputs, transforms =
    Array.map setups ~f:(fun (`To_play to_play, player, board) ->
      ( Board.to_representation board version ~to_play:player
      , if Player.equal to_play player then Fn.id else fun x -> Float.(1. - x)
      ))
    |> Array.unzip
  in
  (Tensor.of_float_array2 inputs Float32, transforms)

let eval t setups =
  let inputs, transforms = tensors_and_transforms setups t.representation in
  let outputs =
    Session.run
      ~inputs:[Session.Input.float t.input_placeholder inputs]
      ~session:t.session
      (Session.Output.float t.model)
  in
  Array.map2_exn (Tensor.to_float_array2 outputs) transforms ~f:(fun output transform ->
    transform (Array.nget output 0))

module Training_data = struct
  module Config = struct
    type t =
      { replay_memory_capacity : int
      ; minibatch_size : int
      ; minibatches_number : int
      ; adam_learning_rate : float
      } [@@deriving of_sexp]

    let default =
      { replay_memory_capacity = 100000
      ; minibatch_size = 128
      ; minibatches_number = 100
      ; adam_learning_rate = 0.001
      }
  end

  type t =
    { config : Config.t
    ; replay_memory : (([ `To_play of Player.t ] * Player.t * Board.t) * float) Replay_memory.t
    }

  let create ?(config=Config.default) () =
    { config
    ; replay_memory = Replay_memory.create ~capacity:config.replay_memory_capacity
    }
end

let train t ~(training_data : Training_data.t) setups_and_valuations =
  Replay_memory.enqueue training_data.replay_memory setups_and_valuations;
  for _ = 1 to training_data.config.minibatches_number do
    let setups, valuations =
      Replay_memory.sample training_data.replay_memory training_data.config.minibatch_size
      |> Array.unzip
    in
    let inputs, transforms = tensors_and_transforms setups t.representation in
    let transformed_valuations =
      Array.map2_exn valuations transforms ~f:(fun valuation transform -> [| transform valuation |])
    in
    let outputs = Tensor.of_float_array2 transformed_valuations Float32 in
    let optimizer =
      Optimizers.adam_minimizer
        ~learning_rate:(Var.f_or_d [] training_data.config.adam_learning_rate ~type_:t.type_)
        t.loss
    in
    let _ =
      Session.run
        ~inputs:
          [ Session.Input.float t.input_placeholder inputs
          ; Session.Input.float t.output_placeholder outputs
          ]
        ~targets:optimizer
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
