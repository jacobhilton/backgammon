open Base
open Tensorflow
open Tensorflow_core

type t =
  { session : Session.t
  ; type_ : [ `float ] Node.Type.t
  ; input_placeholder : [ `float ] Ops.Placeholder.t
  ; vars : [ `float ] Node.t list
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
    List.fold layer_size_pairs ~init:(Ops.Placeholder.to_node input_placeholder, [])
      ~f:(fun (node_so_far, vars_so_far) (size_from, size_to) ->
        let bias_vars = Var.f_or_d [1; size_to] 0. ~type_ in
        let connected_vars = Var.normal [size_from; size_to] ~stddev:epsilon_init ~type_ in
        ( Ops.(sigmoid ((node_so_far *^ connected_vars) + bias_vars))
        , connected_vars :: bias_vars :: vars_so_far
        ))
  in
  let output_placeholder = Ops.placeholder ~type_ [output_size] in
  let loss = Ops.(neg (reduce_mean (Placeholder.to_node output_placeholder * log model))) in
  { session; type_; input_placeholder; vars = List.rev vars; model; output_placeholder; loss }

let tensors_of_boards_and_players boards_and_players =
  let inputs =
    Array.map boards_and_players ~f:(fun (player, board) ->
      Board.to_representation board ~to_play:player)
  in
  Tensor.of_float_array2 inputs Float32

let eval t boards_and_players =
  let inputs = tensors_of_boards_and_players boards_and_players in
  let outputs =
    Session.run
      ~inputs:[Session.Input.float t.input_placeholder inputs]
      ~targets:(List.map t.vars ~f:(fun var -> Node.P var))
      ~session:t.session
      (Session.Output.float t.model)
  in
  Array.map (Tensor.to_float_array2 outputs) ~f:(fun output -> Array.nget output 0)

let equity t = Equity.create (fun player board -> Array.nget (eval t [| player, board |]) 0)

let train t ~learning_rate boards_and_players equities =
  let inputs = tensors_of_boards_and_players boards_and_players in
  let outputs = Tensor.of_float_array2 (Array.map equities ~f:(fun x -> [| x |])) Float32 in
  let optimizer =
    Optimizers.gradient_descent_minimizer
      ~learning_rate:(Var.f_or_d [1] learning_rate ~type_:t.type_)
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
      (Session.Output.float t.model)
  in
  ()
