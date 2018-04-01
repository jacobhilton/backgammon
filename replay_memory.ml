open Core
open Async

module Limited = struct
  type 'a t =
    { queue : 'a option array
    ; capacity : int
    ; mutable enqueued : int
    ; mutable newest : int
    ; mutable shuffled_items_remaining : 'a list option
    }

  let create ~capacity =
    if Int.(capacity < 1) then
      failwith "Cannot create replay memory with non-positive capacity."
    else
      { queue = Array.create ~len:capacity None
      ; capacity
      ; enqueued = 0
      ; newest = capacity - 1
      ; shuffled_items_remaining = Some []
      }

  let enqueue t item =
    t.newest <- (t.newest + 1) % t.capacity;
    Array.set t.queue t.newest (Some item);
    t.enqueued <- t.enqueued + 1;
    t.shuffled_items_remaining <- None

  let to_list_oldest_first t =
    if Int.equal t.enqueued 0 then [] else
      let pos = ref t.newest in
      let result = ref [Option.value_exn (Array.get t.queue !pos)] in
      let oldest = if Int.(t.enqueued < t.capacity) then 0 else (t.newest + 1) % t.capacity in
      while not (Int.equal !pos oldest) do
        pos := (!pos - 1) % t.capacity;
        result := Option.value_exn (Array.get t.queue !pos) :: !result
      done;
      !result
end

module Unlimited = struct
  type 'a t =
    { mutable queue : 'a list
    ; mutable enqueued : int
    ; mutable shuffled_items_remaining : 'a list option
    }

  let create () =
    { queue = []
    ; enqueued = 0
    ; shuffled_items_remaining = Some []
    }

  let enqueue t item =
    t.queue <- item :: t.queue;
    t.enqueued <- t.enqueued + 1;
    t.shuffled_items_remaining <- None

  let to_list_oldest_first t =
    List.rev t.queue
end

type 'a t =
  | Limited of 'a Limited.t
  | Unlimited of 'a Unlimited.t

let create ~capacity:capacity_opt =
  match capacity_opt with
  | Some capacity -> Limited (Limited.create ~capacity)
  | None -> Unlimited (Unlimited.create ())

let capacity = function
  | Limited r -> Some r.capacity
  | Unlimited _ -> None

let enqueued = function
  | Limited r -> r.enqueued
  | Unlimited r -> r.enqueued

let size = function
  | Limited r -> Int.min r.enqueued r.capacity
  | Unlimited r -> r.enqueued

let shuffled_items_remaining = function
  | Limited r -> r.shuffled_items_remaining
  | Unlimited r -> r.shuffled_items_remaining

let set_shuffled_items_remaining t v =
  match t with
  | Limited r -> r.shuffled_items_remaining <- v
  | Unlimited r -> r.shuffled_items_remaining <- v

let enqueue = function
  | Limited r -> Limited.enqueue r
  | Unlimited r -> Unlimited.enqueue r
  
let to_list_oldest_first = function
  | Limited r -> Limited.to_list_oldest_first r
  | Unlimited r -> Unlimited.to_list_oldest_first r

let save t ~filename to_sexp =
  let sexps = List.map (to_list_oldest_first t) ~f:to_sexp in
  Writer.save_sexps filename sexps

let load t ~filename of_sexp =
  Reader.load_sexps_exn filename of_sexp
  >>| List.iter ~f:(enqueue t)

let shuffle l =
  List.map l ~f:(fun x -> (x, Random.bits ()))
  |> List.sort ~cmp:(fun (_, a) (_, b) -> Int.compare a b)
  |> List.map ~f:fst

let rec sample t sample_size =
  if Int.(sample_size > 0) && (Int.equal (enqueued t) 0) then
    failwith "Nothing to sample."
  else
    let items =
      match shuffled_items_remaining t with
      | Some x -> x
      | None -> shuffle (to_list_oldest_first t)
    in
    let sampled_items, unsampled_items = List.split_n items sample_size in
    let number_of_sampled_items = List.length sampled_items in
    if Int.(number_of_sampled_items < sample_size) then
      begin
        set_shuffled_items_remaining t None;
        sampled_items @ (sample t Int.(sample_size - number_of_sampled_items))
      end
    else
      begin
        set_shuffled_items_remaining t (Some unsampled_items);
        sampled_items
      end
