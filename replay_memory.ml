open Core

type 'a t =
  { queue : 'a option array
  ; capacity : int
  ; mutable size : int
  ; mutable newest : int
  ; mutable shuffled_items_remaining : 'a list option
  }

let capacity t = t.capacity

let size t = t.size

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
  Array.iter items ~f:(fun item ->
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

let shuffle l =
  List.map l ~f:(fun x -> (x, Random.bits ()))
  |> List.sort ~cmp:(fun (_, a) (_, b) -> Int.compare a b)
  |> List.map ~f:fst

let sample t sample_size =
  let rec sample_list t sample_size =
    if Int.(sample_size > 0) && (Int.equal t.size 0) then
      failwith "Nothing to sample."
    else
      let items =
        match t.shuffled_items_remaining with
        | Some x -> x
        | None -> shuffle (to_list_oldest_first t)
      in
      let number_of_items = List.length items in
      if Int.(number_of_items < sample_size) then
        begin
          t.shuffled_items_remaining <- None;
          items @ (sample_list t Int.(sample_size - number_of_items))
        end
      else
        begin
          let split_items = List.split_n items sample_size in
          t.shuffled_items_remaining <- Some (snd split_items);
          fst split_items
        end
  in
  Array.of_list (sample_list t sample_size)
