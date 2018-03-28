open Core

module Limited = struct
  type 'a t =
    { queue : 'a option array
    ; capacity : int
    ; mutable size : int
    ; mutable newest : int
    ; mutable shuffled_items_remaining : 'a list option
    }

  let create ~capacity =
    if Int.(capacity < 1) then
      failwith "Cannot create Replayer with non-positive capacity."
    else
      { queue = Array.create ~len:capacity None
      ; capacity
      ; size = 0
      ; newest = capacity - 1
      ; shuffled_items_remaining = Some []
      }

  let enqueue t items =
    List.iter items ~f:(fun item ->
      t.newest <- (t.newest + 1) % t.capacity;
      Array.set t.queue t.newest (Some item);
      t.size <- Int.min (t.size + 1) t.capacity);
    t.shuffled_items_remaining <- None

  let to_list_oldest_first t =
    if Int.equal t.size 0 then [] else
      let pos = ref t.newest in
      let result = ref [Option.value_exn (Array.get t.queue !pos)] in
      let oldest = if Int.(t.size < t.capacity) then 0 else (t.newest + 1) % t.capacity in
      while not (Int.equal !pos oldest) do
        pos := (!pos - 1) % t.capacity;
        result := Option.value_exn (Array.get t.queue !pos) :: !result
      done;
      !result
end

module Unlimited = struct
  type 'a t =
    { mutable queue : 'a list
    ; mutable size : int
    ; mutable shuffled_items_remaining : 'a list option
    }

  let create () =
    { queue = []
    ; size = 0
    ; shuffled_items_remaining = Some []
    }

  let enqueue t items =
    List.iter items ~f:(fun item ->
      t.queue <- item :: t.queue;
      t.size <- t.size + 1);
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

let size = function
  | Limited r -> r.size
  | Unlimited r -> r.size

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

let shuffle l =
  List.map l ~f:(fun x -> (x, Random.bits ()))
  |> List.sort ~cmp:(fun (_, a) (_, b) -> Int.compare a b)
  |> List.map ~f:fst

let rec sample t sample_size =
  if Int.(sample_size > 0) && (Int.equal (size t) 0) then
    failwith "Nothing to sample."
  else
    let items =
      match shuffled_items_remaining t with
      | Some x -> x
      | None -> shuffle (to_list_oldest_first t)
    in
    let number_of_items = List.length items in
    if Int.(number_of_items < sample_size) then
      begin
        set_shuffled_items_remaining t None;
        items @ (sample t Int.(sample_size - number_of_items))
      end
    else
      begin
        let split_items = List.split_n items sample_size in
        set_shuffled_items_remaining t (Some (snd split_items));
        fst split_items
      end
