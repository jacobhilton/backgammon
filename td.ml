open Base
open Tensorflow
open Tensorflow_core

type t =
  { session : Session.t
  ; type_ : [ `float ] Node.Type.t
  ; input_placeholder : [ `float ] Ops.Placeholder.t
  ; vars : (string * Node.p) list
  ; model : [ `float ] Node.t
  ; output_placeholder : [ `float ] Ops.Placeholder.t
  ; loss : [ `float ] Node.t
  }

let create ?(epsilon_init=0.1) ~hidden_layer_sizes () =
  let input_size = 196 in
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
        let label s var = (Core.sprintf "%s_%i" s i, Node.P var) in
        ( Ops.(sigmoid ((node_so_far *^ connected_var) + bias_var))
        , label "connected" connected_var :: label "bias" bias_var :: vars_so_far
        ))
  in
  let output_placeholder = Ops.placeholder ~type_ [output_size] in
  let loss = Ops.(neg (reduce_mean (Placeholder.to_node output_placeholder * log model))) in
  { session; type_; input_placeholder; vars = List.rev vars; model; output_placeholder; loss }

let tensors_and_transforms setups =
  let inputs, transforms =
    Array.map setups ~f:(fun (`To_play to_play, player, board) ->
      ( Board.to_representation board ~to_play:player
      , if Player.equal to_play player then Fn.id else fun x -> Float.(1. - x)
      ))
    |> Array.unzip
  in
  (Tensor.of_float_array2 inputs Float32, transforms)

let eval t setups =
  let inputs, transforms = tensors_and_transforms setups in
  let outputs =
    Session.run
      ~inputs:[Session.Input.float t.input_placeholder inputs]
      ~session:t.session
      (Session.Output.float t.model)
  in
  Array.map2_exn (Tensor.to_float_array2 outputs) transforms ~f:(fun output transform ->
    transform (Array.nget output 0))

let equity t =
  Equity.create (fun ~to_play player board ->
    Array.nget (eval t [| `To_play to_play, player, board |]) 0)

let train t ~learning_rate setups_and_valuations =
  let setups, valuations = Array.unzip setups_and_valuations in
  let inputs, transforms = tensors_and_transforms setups in
  let transformed_valuations =
    Array.map2_exn valuations transforms ~f:(fun valuation transform -> [| transform valuation |])
  in
  let outputs = Tensor.of_float_array2 transformed_valuations Float32 in
  let optimizer =
    Optimizers.gradient_descent_minimizer
      ~learning_rate:(Var.f_or_d [] learning_rate ~type_:t.type_)
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