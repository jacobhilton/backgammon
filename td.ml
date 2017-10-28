open Base
open Tensorflow_core
open Tensorflow_fnn

type t =
  { model : (Fnn._1d, [ `float ], Tensor.float32_elt) Fnn.Model.t
  ; input_id : Fnn.Input_id.t
  }

let create ?(epsilon_init=0.1) ~hidden_layer_sizes () =
  let input, input_id = Fnn.input ~shape:(D1 196) in
  let model =
    List.fold (hidden_layer_sizes @ [1]) ~init:input ~f:(fun acc layer_size ->
      Fnn.dense ~w_init:(`normal epsilon_init) layer_size acc
      |> Fnn.sigmoid)
    |> Fnn.Model.create Float
  in
  { model; input_id }

let tensors_of_boards_and_players boards_and_players =
  let xs =
    Array.map boards_and_players ~f:(fun (player, board) ->
      Board.to_representation board ~to_play:player)
  in
  Tensor.of_float_array2 xs Float32

let fit { model; input_id } ~learning_rate boards_and_players equities =
  Fnn.Model.fit model
    ~loss:(Fnn.Loss.cross_entropy `mean)
    ~optimizer:(Fnn.Optimizer.gradient_descent ~learning_rate)
    ~epochs:1
    ~input_id
    ~xs:(tensors_of_boards_and_players boards_and_players)
    ~ys:(Tensor.of_float_array2 (Array.map equities ~f:(fun x -> [| x |])) Float32)

let predict { model; input_id } boards_and_players =
  Fnn.Model.predict model [(input_id, tensors_of_boards_and_players boards_and_players)]
  |> Tensor.to_float_array1

let equity t = Equity.create (fun player board -> Array.nget (predict t [| player, board |]) 0)
