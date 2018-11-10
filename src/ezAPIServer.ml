open StringCompat
open Lwt
open EzAPI.TYPES

type 'a directory = {
  meth_GET :'a RestoDirectory1.directory;
  meth_OPTIONS :'a RestoDirectory1.directory;
}

type 'output answer = 'output RestoDirectory1.Answer.answer

let empty = {
  meth_GET = RestoDirectory1.empty;
  meth_OPTIONS = RestoDirectory1.empty;
}

let return x = RestoDirectory1.Answer.return x

let verbose =
  try
    let s = Sys.getenv "EZAPISERVER" in
    try
      int_of_string s
    with _ -> 2
  with _ -> 1

module Header = Cohttp.Header
module Request = Cohttp.Request
module Server = Cohttp_lwt_unix.Server

exception EzRawReturn of string
exception EzRawError of int

(* Remove empty strings from a list of string *)
let list_trim l = List.filter (fun s -> s <> "") l


let t0 = GMTime.time ()
let req_time = ref t0
let set_req_time () =
  req_time := GMTime.time ()
let req_time () = !req_time

type timings = {
   mutable timings_ok : Timings.t array;
   mutable timings_fail : Timings.t array;
  }

let timings = {
    timings_ok = [||];
    timings_fail = [||];
  }

let add_timing n ok t dt =
  if ok then
    Timings.add timings.timings_ok.(n) t dt
  else
    Timings.add timings.timings_fail.(n) t dt

let init_timings nservices =
  timings.timings_ok <-Array.init nservices
                              (fun _ -> Timings.create t0);
  timings.timings_fail <- Array.init nservices
                                (fun _ -> Timings.create t0);
  ()

let req_ips = Hashtbl.create 1111

let register_ip ip =
  try
    let s = Hashtbl.find req_ips ip in
    s.ip_last <- req_time();
    s.ip_nb <- s.ip_nb + 1
  with Not_found ->
    let gi = Geoip.init_exn Geoip.GEOIP_MEMORY_CACHE in
    let country_name =
      match Geoip.country_name_by_name gi ip with
      | None -> ""
      | Some s -> s
    in
    let country_code =
      match Geoip.country_code_by_name gi ip with
      | None -> ""
      | Some s -> s
    in
    Geoip.close gi;
    let s = {
        ip_ip = ip;
        ip_last = req_time();
        ip_nb = 1;
        ip_country = (country_name, country_code);
      } in
    Hashtbl.add req_ips ip s

exception EzReturnOPTIONS of (string * string) list

let register ?(options_headers=[]) service handler dir =
  let handler_GET a b =
    try
      handler a b
    with
    | (EzRawReturn _ | EzRawError _) as exn -> Lwt.fail exn
    | exn ->
      Printf.eprintf "*** exception %s in handler ***\n%!"
                     (Printexc.to_string exn);
      Lwt.fail EzAPI.ResultNotfound
  in

  let handler_GET a b =
    let t0 = req_time () in
    let add_timing_wrap b =
      let t1 = Unix.gettimeofday () in
      add_timing (EzAPI.id service) b t0 (t1-.t0)
    in
    Lwt.catch
      (function () ->
                handler_GET a b >>=
                function res ->
                  add_timing_wrap true;
                  Lwt.return res)
      (function
        | (EzRawReturn _ | EzRawError _) as exn ->
          add_timing_wrap true;
         Lwt.fail exn
        | exn ->
         add_timing_wrap false;
         Lwt.fail exn)
  in
  let handler_OPTIONS _a _b =
    Lwt.fail (EzReturnOPTIONS options_headers)
  in
  let service_GET, service_OPTIONS = EzAPI.register service in
  {
      meth_GET =
        RestoDirectory1.register dir.meth_GET service_GET handler_GET;
      meth_OPTIONS =
        RestoDirectory1.register dir.meth_OPTIONS service_OPTIONS
          handler_OPTIONS;
  }

let json_root = function
  | `O ctns -> `O ctns
  | `A ctns -> `A ctns
  | `Null -> `O []
  | oth -> `A [ oth ]

type reply =
  | ReplyNone
  | ReplyJson of Json_repr.Ezjsonm.value
  | ReplyString of (* content-type *) string * (* content *) string

type server_kind =
  | API of EzAPI.request directory
  | Root of string * string option

type server = {
    server_port : int;
    server_kind : server_kind;
  }

let reply_none code = Lwt.return (code, ReplyNone)
let reply_json code json = Lwt.return (code, ReplyJson json)
let reply_raw_json code json = Lwt.return (code, ReplyString ("application/javascript",json))
let reply_answer
      { RestoDirectory1.Answer.code; RestoDirectory1.Answer.body } =
  match body with
  | RestoDirectory1.Answer.Empty ->
     reply_none code
  | RestoDirectory1.Answer.Single json ->
     reply_json code json
  | RestoDirectory1.Answer.Stream _ ->
     reply_none 500

let split_on_char c s = OcpString.split s c

let rev_extensions filename =
  List.rev (split_on_char '.'
                                 (String.lowercase
                                    (Filename.basename filename)))

let normalize_path path =
  let rec normalize_path path revpath =
    match path, revpath with
    | [],_ -> List.rev revpath
    | ("" | ".") :: path, _ -> normalize_path path revpath
    | ".." :: path, _ :: revpath -> normalize_path path revpath
    | ".." :: path, [] -> normalize_path path []
    | dir :: path, revpath -> normalize_path path (dir :: revpath)
  in
  normalize_path path []

let content_type_of_file file =
  let exts = rev_extensions file in
  if verbose > 2 then
    EzDebug.printf "content_type_of_file: [%s]"
                    (String.concat "," exts);
  match exts with
  | "js" :: _ -> "application/javascript"
  | "pdf" :: _ -> "application/pdf"
  | "json" :: _ -> "application/json"
  | "xml" :: _ -> "application/xml"
  | "zip" :: _ -> "application/zip"

  | ("html" | "htm") :: _ -> "text/html"

  | "map" :: "css" :: _
  | "css" :: _ -> "text/css"

  | "png" :: _ -> "image/png"
  | "jpg" :: _ -> "image/jpeg"
  | "gif" :: _ -> "image/gif"
  | "svg" :: _ -> "image/svg+xml"

  | _ -> "application/octet-stream"

module FileString = struct
  let size = 16_000
  let s = Bytes.make size '\000'
  let b = Buffer.create size

  let read_file ic =
    Buffer.clear b;
    let rec iter ic b s =
      let nread = input ic s 0 size in
      if nread > 0 then begin
          Buffer.add_subbytes b s 0 nread;
          iter ic b s
        end
    in
    iter ic b s;
    Buffer.contents b

  let read_file filename =
    let ic = open_in_bin filename in
    try
      let s = read_file ic in
      close_in ic;
      s
    with e ->
      close_in ic;
      raise e
end

let rec reply_file ?(meth=`GET) ?default root path =
  let path = normalize_path path in
  let file = Filename.concat root (String.concat "/" path) in
  try
    let content_type = content_type_of_file file in
    match meth with
    | `OPTIONS ->
      if Sys.file_exists file then
        Lwt.return (200, ReplyNone)
      else raise Not_found
    | _ ->
      let content = FileString.read_file file in
      Printf.eprintf "Returning file %S of len %d\n%!" file
        (String.length content);
      Lwt.return (200, ReplyString (content_type, content))
  with _exn ->
       match default with
       | None ->
          raise Not_found
       | Some file ->
          reply_file ~meth root
                     (split_on_char '/' file)

(* Resolve handler matching request and run it *)
let dispatch s (io, _conn) req body =
  set_req_time ();
  begin
    match io with
    | Conduit_lwt_unix.TCP tcp ->
       begin
         match[@warning "-42"] Lwt_unix.getpeername
                               tcp.Conduit_lwt_unix.fd with
        | Lwt_unix.ADDR_INET (ip,_port) ->
           let ip = Ipaddr.to_string (Ipaddr_unix.of_inet_addr ip) in
           let ip =
             match Header.get (Cohttp.Request.headers req) "x-forwarded-for"
             with
             | None -> ip
             | Some ip -> ip
           in
           register_ip ip
        | Lwt_unix.ADDR_UNIX _path -> ()
      end
    | Conduit_lwt_unix.Domain_socket _
    | Conduit_lwt_unix.Vchan _ -> ()
  end;
  Lwt_log.Section.set_level Lwt_log.Section.main Lwt_log.Debug;
  let local_path =
    req
    |> Cohttp.Request.uri
    |> Uri.path
  in
  let path =
    local_path
    |> split_on_char '/'
    |> list_trim
  in
  let req_params = req |> Request.uri |> Uri.query in
  let headers =
    let headers = ref StringMap.empty in
    Header.iter (fun s v ->
        headers :=
          StringMap.add (String.lowercase s) v !headers)
                (Request.headers req);
    !headers
  in
  let version = match Request.version req with
    | `HTTP_1_0 -> HTTP_1_0
    | `Other _ | `HTTP_1_1 -> HTTP_1_1
  in
  Cohttp_lwt.Body.to_string body >>= fun content ->
  let content_type =
    try
      match StringMap.find "content-type" headers with
      | s :: _ -> Some s
      | [] -> None
    with _ -> None
  in
  let body = BodyString (content_type, content) in
  let request = EzAPI.request ~version
                              ~headers
                              ~body
                              req_params
  in
  if verbose > 0 then
    Printf.eprintf "REQUEST: %s %S\n%!"
                   (req |> Cohttp.Request.meth |> Cohttp.Code.string_of_method)
                   local_path;
  if verbose > 1 then
    StringMap.iter (fun s v ->
        List.iter (fun v ->
            Printf.eprintf "  %s: %s\n%!" s v;
          ) v
      ) headers;
  let meth = Cohttp.Request.meth req in
  Lwt.catch
    (fun () ->
      if path = ["debug"] then
        reply_json 200
                   (`A
                     (Cohttp.Request.headers req
                      |> Header.to_lines
                      |> List.map
                           (fun s -> `String s)))
      else
        match s.server_kind, meth with
        | API dir, `OPTIONS ->
          RestoDirectory1.lookup dir.meth_OPTIONS request path
          >>= fun handler -> handler None >>= fun _answer ->
          (* Note: this path always fails with EzReturnOPTIONS *)
          reply_none 200
        | API dir, _ ->
           let content =
             match request.req_body with
             | BodyString (Some "application/x-www-form-urlencoded", content) ->
                EzAPI.add_params request ( EzUrl.decode_args content );
                None
             | BodyString (Some "application/json", content) ->
                Some (Ezjsonm.from_string content)
             | BodyString (_, content) ->
                try
                  Some (Ezjsonm.from_string content)
                with _ -> None
           in
           RestoDirectory1.lookup dir.meth_GET request path >>= fun handler ->
           handler content
           >>= reply_answer
        | Root (root, default), meth ->
          reply_file ~meth root ?default path
    )
    (fun exn ->
       Printf.eprintf "Exception %s\n%!" (Printexc.to_string exn);
       match exn with
      | EzReturnOPTIONS headers ->
        request.rep_headers <- headers @ request.rep_headers;
        reply_none 200
     | EzRawReturn s -> reply_raw_json 200 s
     | EzRawError code -> reply_none code
     | Not_found -> reply_none 404
     | exn ->
        Printf.eprintf "In %s: exception %s\n%!"
                       local_path (Printexc.to_string exn);
        reply_none 500)
  >>= fun (code, reply) ->
  let headers =
    Header.add_list
      (Header.add_list
         (Header.init_with
            "access-control-allow-origin" "*")
         [
           ("access-control-allow-headers", "Accept, Content-Type");
           ("access-control-allow-methods", "POST, GET, OPTIONS")
      ]) request.rep_headers in
  let status = Cohttp.Code.status_of_code code in
  if verbose > 1 then
    Printf.eprintf "Reply computed %d\n%!" code;
  let body, headers = match reply with
    | ReplyNone ->
       Cohttp_lwt__Body.empty, headers
    | ReplyJson json ->
      let content = Ezjsonm.to_string (json_root json) in
      if verbose > 2 then
        Printf.eprintf "Content:\n%s\n%!" content;
      Cohttp_lwt__Body.of_string content,
      Header.add headers "Content-Type" "application/json"
    | ReplyString (content_type, content) ->
      if verbose > 2 then
        Printf.eprintf "Content:\n%s\n%!" content;
      Cohttp_lwt__Body.of_string content,
      Header.add headers "Content-Type" content_type
  in
  Cohttp_lwt__Body.to_string body >>= fun body ->
  Server.respond_string ~headers ~status ~body ()

(*********************************************************************)
(* HTTP Server                                                       *)
(*********************************************************************)

let server servers =
  let create_server port kind =
    let s = { server_port = port;
              server_kind = kind;
            } in
    if not (EzAPI.all_services_registered ()) then (* exit 2 *) ();
    init_timings (EzAPI.nservices());
    let callback conn req body = dispatch s conn req body in
    let dont_crash_on_exn exn =
      try
        raise exn
      with
      (* Broken Pipe -> do nothing *)
      | Unix.Unix_error (Unix.EPIPE, _, _) -> ()
      | exn ->
         Printf.eprintf "Server Error: %s\n%!" (Printexc.to_string exn)
    in
    (*  Cache.set_error_handler (fun e -> return @@ dont_crash_on_exn e); *)
    Server.create
      ~on_exn:dont_crash_on_exn
      ~mode:(`TCP (`Port port))
      (Server.make ~callback ())
  in
  Lwt.join (List.map (fun (port,kind) ->
                create_server port kind) servers)

let return_error code = raise (EzRawError code)
