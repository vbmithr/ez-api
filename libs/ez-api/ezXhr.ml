open EzRequest

let get msg url ?(headers=[]) f =
  if msg <> "" then
    Js_utils.log "[>%s GET %s]" msg url;
  let xhr = XmlHttpRequest.create () in
  xhr##_open (Js.string "GET", Js.string url, Js._true) ;
  List.iter (fun (name, value) ->
      xhr##setRequestHeader
        (Js.string name, Js.string value) ;
    ) headers;
  xhr##onreadystatechange <-
    Js.wrap_callback (fun _ ->
        if xhr##readyState = XmlHttpRequest.DONE then
          let status = xhr##status in
          if msg <> "" then
            Js_utils.log "[>%s RECV %d %s]" msg status url;
          if status = 200 then
            f (CodeOk (Js.to_string xhr##responseText))
          else
            f (CodeError status)
      ) ;
  xhr##send (Js.null)

let post ?(content_type="application/json") ?(content="{}") msg url
         ?(headers=[]) f =
  if msg <> "" then
    Js_utils.log "[>%s POST %s]" msg url;
  let xhr = XmlHttpRequest.create () in
  xhr##_open (Js.string "POST", Js.string url, Js._true) ;
  xhr##setRequestHeader
    (Js.string "Content-Type", Js.string content_type) ;
  List.iter (fun (name, value) ->
      xhr##setRequestHeader
        (Js.string name, Js.string value) ;
    ) headers;
  xhr##onreadystatechange <-
    Js.wrap_callback (fun _ ->
        if xhr##readyState = XmlHttpRequest.DONE then
          let status = xhr##status in
          if msg <> "" then
            Js_utils.log "[>%s RECV %d %s]" msg status url;
          if status = 200 then
            f (CodeOk (Js.to_string xhr##responseText))
          else
            f (CodeError status)
      ) ;
  xhr##send (Js.some @@ Js.string content)

(* Use our own version of Ezjsonm.from_string to avoid errors *)
let init () =
  EzEncodingJS.init ();
  EzDebugJS.init ();
  EzRequest.xhr_get := get;
  EzRequest.xhr_post := post;
  EzRequest.log := (fun s -> Js_utils.log "%s" s);
  ()

let () =
  init ()

include EzRequest.ANY
