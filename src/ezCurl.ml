open EzRequest

include EzRequest.Make(struct

let writer_callback a d =
  Buffer.add_string a d;
  String.length d

let initialize_connection url =
  let r = Buffer.create 16384
  and c = Curl.init () in
  Curl.set_timeout c 30;      (* Timeout *)
  Curl.set_sslverifypeer c false;
  Curl.set_sslverifyhost c Curl.SSLVERIFYHOST_EXISTENCE;
  Curl.set_writefunction c (writer_callback r);
  Curl.set_tcpnodelay c true;
  Curl.set_verbose c false;
  Curl.set_post c false;
  Curl.set_url c url;
  r,c

let make prepare url ~headers f =
  let rc, data =
    try
      let r, c = initialize_connection url in
      prepare c;
      Curl.set_httpheader c (
                            List.map (fun (name, value) ->
                                Printf.sprintf "%s: %s" name value
                              ) headers);
      Curl.perform c;
      let rc = Curl.get_responsecode c in
      Curl.cleanup c;
      rc, Buffer.contents r
    with _ -> -1, ""
  in
  if rc = 200 then
    try f (CodeOk data) with _ -> ()
  else
    try f (CodeError (rc, Some data)) with _ -> ()

let xhr_get _msg url ?(headers=[]) f =
  make ~headers (fun c ->
      Curl.set_post c false) url f

let xhr_post ?(content_type = "application/json") ?(content="{}")
         _msg url ?(headers=[]) f =
  let headers = ("Content-Type", content_type) :: headers in
  make ~headers (fun c ->
      Curl.set_post c true;
      Curl.set_postfields c content;
      Curl.set_postfieldsize c (String.length content);
    ) url f

end)
