let switch_of_version t =
  let open Test in
  let with_opam_switch = function
  | None -> Ok None
  | Some (Opam_switch s) -> Ok (Some (Opam_switch s))
  | Some (Ocaml_version s) ->
    (* if we have a major-minor specification as in travis-opam,
       we need to convert to major-minor-patch *)
    match Astring.String.cuts ~sep:"." s with
    (* TODO: variants will break the logic here, if they are ever supported in travis *)
    | _major::_minor::_patch::_ -> Ok (Some (Opam_switch (s ^ "+mingw64c")))
    | major::minor::_ -> begin
      match List.assoc (major ^ "." ^ minor) Test.known_compilers with
        | exception Not_found -> Error (`Msg ("Could not figure out the correct OPAM_SWITCH for compiler " ^ s ^ " - perhaps it should be added to the known_compilers table"))
        | package -> Ok (Some (Opam_switch
                  ((OpamPackage.version_to_string package) ^ "+mingw64c")))
    end
    | _ -> Error (`Msg ("OCAML_VERSION " ^ s ^ " did not resemble any compiler version with a known conversion to OPAM_SWITCH"))
  in
  match with_opam_switch t.compiler with
  | Ok compiler -> Ok {t with compiler = compiler}
  | Error e -> Error e

let nullify_distro t = Test.({t with distro = None})

let make_appveyor travis =
  let open Rresult.R in
  Bos.OS.File.read (Fpath.v travis) >>= Yaml.yaml_of_string >>=
  Travis.of_yaml >>= fun config ->
  switch_of_version config.globals >>= fun globals ->
  let globals = nullify_distro globals in
  List.fold_left (fun acc test -> match acc, switch_of_version test with
      | Error (`Msg e), Error (`Msg f) -> Error (`Msg (e ^ "\n" ^ f))
      | Error e, _ -> Error e
      | Ok _, Error e -> Error e
      | Ok l, Ok i -> Ok (i::l)) (Ok []) config.tests >>= fun tests ->
  let tests = List.(map nullify_distro @@ rev tests) in
  let config = { Test.pins = config.pins; globals; tests; } in
  Appveyor.to_yaml config |> Yaml.yaml_to_string >>= fun yaml ->
  Ok yaml
