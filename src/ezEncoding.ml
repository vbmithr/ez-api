module Ezjsonm_direct = Ezjsonm
open Json_encoding

let json_of_string = ref Ezjsonm.from_string

module Ezjsonm : sig

  val from_string : string -> Json_repr.ezjsonm

  end = struct

  let from_string s = !json_of_string s
end

exception DestructError

let int64 =
  union [
    case
      int32
      (fun i ->
         let j = Int64.to_int32 i in
         if Int64.equal (Int64.of_int32 j) i then Some j else None)
      Int64.of_int32 ;
    case
      string
      (fun i -> Some (Int64.to_string i))
      Int64.of_string
  ]

(* Default behavior to destruct a json value *)
let destruct encoding buf =
  try
    let json = Ezjsonm.from_string buf in
    Json_encoding.destruct encoding json
  with Json_encoding.Cannot_destruct (path, exn)  ->
    Format.eprintf "Error during destruction path %a : %s\n\n %s\n%!"
      (Json_query.print_path_as_json_path ~wildcards:true) path
      (Printexc.to_string exn)
      buf ;
    raise DestructError
     | Json_encoding.Unexpected_field field ->
       Format.eprintf "Error during destruction path, unexpected field %S %s\n%!"
         field buf ;
       raise DestructError

let construct ?(compact=true) encoding data =
    let ezjson =
      (module Json_repr.Ezjsonm : Json_repr.Repr with type value = Json_repr.ezjsonm ) in
    Json_repr.pp
      ~compact
      ezjson
      Format.str_formatter
      (Json_encoding.construct encoding data) ;
    Format.flush_str_formatter ()

let unexpected_error ~kind ~expected =
  raise (Json_encoding.Cannot_destruct
           ([],
            Json_encoding.Unexpected (kind, expected)))

let encoded_string =
  conv
    (fun s -> Ezjsonm_direct.encode_string s)
    (fun enc ->
      match Ezjsonm_direct.decode_string enc with
          | None -> unexpected_error
                      ~kind:"raw string"
                      ~expected:"encoded string"
          | Some s -> s)
      any_ezjson_value

let () =
  Printexc.register_printer (fun exn ->
      match exn with
      | Json_encoding.Cannot_destruct (path, exn) ->
        let s = Printf.sprintf "Cannot destruct JSON (%s, %s)"
            (Json_query.json_pointer_of_path path)
            (Printexc.to_string exn)
        in
        Some s
      | _ -> None)

let obj11 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),x11)
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),x11)
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11)
    )
    (merge_objs
       (obj10
          f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (obj1 f11))

let obj12 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12)
    )
    (merge_objs
       (obj10
          f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (obj2 f11 f12)
    )

let obj13 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13)
    )
    (merge_objs
       (obj10
          f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (obj3 f11 f12 f13)
    )

let obj14 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13,x14))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13,x14))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14)
    )
    (merge_objs
       (obj10
          f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (obj4 f11 f12 f13 f14)
    )

let obj15 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15 =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13,x14,x15))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13,x14,x15))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15)
    )
    (merge_objs
       (obj10
          f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (obj5 f11 f12 f13 f14 f15)
    )

let obj16 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15 f16 =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13,x14,x15,x16))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13,x14,x15,x16))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16)
    )
    (merge_objs
       (obj10
          f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (obj6 f11 f12 f13 f14 f15 f16)
    )

let obj17 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15 f16 f17 =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13,x14,x15,x16,x17))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13,x14,x15,x16,x17))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17)
    )
    (merge_objs
       (obj10
          f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (obj7 f11 f12 f13 f14 f15 f16 f17)
    )

let obj18 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15 f16 f17 f18 =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17,x18)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13,x14,x15,x16,x17,x18))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13,x14,x15,x16,x17,x18))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17,x18)
    )
    (merge_objs
       (obj10
          f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (obj8 f11 f12 f13 f14 f15 f16 f17 f18)
    )

let obj19 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15 f16 f17 f18 f19 =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17,x18,x19)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13,x14,x15,x16,x17,x18,x19))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),(x11,x12,x13,x14,x15,x16,x17,x18,x19))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17,x18,x19)
    )
    (merge_objs
       (obj10 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (obj9 f11 f12 f13 f14 f15 f16 f17 f18 f19)
    )

let obj20 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15 f16 f17 f18 f19 f20 =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17,x18,x19,x20)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),
         (x11,x12,x13,x14,x15,x16,x17,x18,x19,x20))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),
       (x11,x12,x13,x14,x15,x16,x17,x18,x19,x20))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17,x18,x19,x20)
    )
    (merge_objs
       (obj10 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (obj10 f11 f12 f13 f14 f15 f16 f17 f18 f19 f20)
    )

let obj21
    f1 f2 f3 f4 f5 f6 f7 f8 f9 f10
    f11 f12 f13 f14 f15 f16 f17 f18 f19 f20
    f21
  =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,
       x11,x12,x13,x14,x15,x16,x17,x18,x19,x20,
       x21)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),
         (
           (x11,x12,x13,x14,x15,x16,x17,x18,x19,x20),
           (x21)
         ))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),
       ((x11,x12,x13,x14,x15,x16,x17,x18,x19,x20),
        (x21)
       ))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,
       x11,x12,x13,x14,x15,x16,x17,x18,x19,x20,
       x21)
    )
    (merge_objs
       (obj10 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (merge_objs
          (obj10 f11 f12 f13 f14 f15 f16 f17 f18 f19 f20)
          (obj1 f21)
       )
    )

let obj22
    f1 f2 f3 f4 f5 f6 f7 f8 f9 f10
    f11 f12 f13 f14 f15 f16 f17 f18 f19 f20
    f21 f22
  =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,
       x11,x12,x13,x14,x15,x16,x17,x18,x19,x20,
       x21,x22)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),
         (
           (x11,x12,x13,x14,x15,x16,x17,x18,x19,x20),
           (x21,x22)
         ))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),
       ((x11,x12,x13,x14,x15,x16,x17,x18,x19,x20),
        (x21,x22)
       ))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,
       x11,x12,x13,x14,x15,x16,x17,x18,x19,x20,
       x21,x22)
    )
    (merge_objs
       (obj10 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (merge_objs
          (obj10 f11 f12 f13 f14 f15 f16 f17 f18 f19 f20)
          (obj2 f21 f22)
       )
    )

let obj23
    f1 f2 f3 f4 f5 f6 f7 f8 f9 f10
    f11 f12 f13 f14 f15 f16 f17 f18 f19 f20
    f21 f22 f23
  =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,
       x11,x12,x13,x14,x15,x16,x17,x18,x19,x20,
       x21,x22,x23)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),
         (
           (x11,x12,x13,x14,x15,x16,x17,x18,x19,x20),
           (x21,x22,x23)
         ))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),
       ((x11,x12,x13,x14,x15,x16,x17,x18,x19,x20),
        (x21,x22,x23)
       ))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,
       x11,x12,x13,x14,x15,x16,x17,x18,x19,x20,
       x21,x22,x23)
    )
    (merge_objs
       (obj10 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (merge_objs
          (obj10 f11 f12 f13 f14 f15 f16 f17 f18 f19 f20)
          (obj3 f21 f22 f23)
       )
    )

let obj24
    f1 f2 f3 f4 f5 f6 f7 f8 f9 f10
    f11 f12 f13 f14 f15 f16 f17 f18 f19 f20
    f21 f22 f23 f24
  =
  conv
    (fun
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,
       x11,x12,x13,x14,x15,x16,x17,x18,x19,x20,
       x21,x22,x23,x24)
      ->
        ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),
         (
           (x11,x12,x13,x14,x15,x16,x17,x18,x19,x20),
           (x21,x22,x23,x24)
         ))
    )
    (fun
      ((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10),
       ((x11,x12,x13,x14,x15,x16,x17,x18,x19,x20),
        (x21,x22,x23,x24)
       ))
      ->
      (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,
       x11,x12,x13,x14,x15,x16,x17,x18,x19,x20,
       x21,x22,x23,x24)
    )
    (merge_objs
       (obj10 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10)
       (merge_objs
          (obj10 f11 f12 f13 f14 f15 f16 f17 f18 f19 f20)
          (obj4 f21 f22 f23 f24)
       )
    )

let init () = ()
