type 'a t =
  { forwards : 'a
  ; backwards : 'a
  }

let create f =
  { forwards = f Player.Forwards
  ; backwards = f Backwards
  }

let create_both x =
  { forwards = x
  ; backwards = x
  }

let get { forwards; backwards } player =
  match player with
  | Player.Forwards -> forwards
  | Backwards -> backwards

let replace { forwards; backwards } player x =
  match player with
  | Player.Forwards -> { forwards = x; backwards }
  | Backwards -> { forwards; backwards = x }
