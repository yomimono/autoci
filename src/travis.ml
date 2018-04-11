let to_yaml t =
  let open Yaml in
  let default_install = "wget https://raw.githubusercontent.com/ocaml/ocaml-ci-scripts/master/.travis-docker.sh" in
  let default_script = "bash -ex .travis-docker.sh" in
  let no_anchor s = {anchor = None; value = s} in
  let language = (no_anchor "language", `String (no_anchor "c")) in
  let install = (no_anchor "install", `String (no_anchor default_install)) in
  let script = (no_anchor "script", `String (no_anchor default_script)) in
  let services = (no_anchor "services", `A [`String (no_anchor "docker")]) in
  let env_children name l =
    (no_anchor name, `A (List.map (fun s -> `String (no_anchor s)) l)) in
  let yaml_globals = env_children "global" @@
    Test.(Fmt.strf "%a" pp_pins t.pins) :: Test.(match test_info_to_var_string t.globals with
      | "" -> []
      | str -> str :: []) in
  let yaml_matrix = env_children "matrix" (List.map Test.test_info_to_var_string t.tests) in
  let env = (no_anchor "env"), `O [yaml_globals; yaml_matrix] in
  let top : yaml = `O [ language; install; script; services; env] in
  top

let of_yaml yaml =
  let open Rresult.R in
  (* TODO: TESTS should be set only once, but if it's set multiple times,
     we'll report true if *any* of the invocations are not explicitly "false".
     To reflect the actual behavior, the last writer should win. *)
  let extract_tests m =
    (* for any string other than "false", TESTS are true *)
    match Astring.String.Map.find "TESTS" m with
    | None -> None
    | Some v -> Some (not (Astring.String.equal v "false"))
  in
  let extract_revdepopts s m =
    match Astring.String.Map.find s m with
    | None -> Test.List []
    | Some depopts when 0 = Astring.String.compare depopts "*" -> All
    | Some depopts ->
      List (List.map OpamPackage.Name.of_string @@ Astring.String.fields depopts)
  in
  let extract_package m =
    match Astring.String.Map.find "PACKAGE" m with
    | None -> None
    | Some package -> match Astring.String.cut ~sep:"." package with
      | Some (name, _) -> Some name
      | None -> Some package
  in
  let test_of_entry e =
    {
      Test.distro = Astring.String.Map.find "DISTRO" e;
      do_test = extract_tests e;
      depopts = extract_revdepopts "DEPOPTS" e;
      revdeps = extract_revdepopts "REVDEPS" e;
      package = extract_package e;
      compiler =
        match Astring.String.Map.find "OCAML_VERSION" e, Astring.String.Map.find "OPAM_SWITCH" e with
        | None, None -> None
        | Some a, None -> Some (Ocaml_version a)
        | None, Some a -> Some (Opam_switch a)
        | Some a, Some _b -> Some (Ocaml_version a) (* them's the breaks *)
          ;
    }
  in
  let tests_of_matrix m =
    try Ok (List.map test_of_entry m)
    with Failure _ -> Error (`Msg "An OCAML_VERSION must be set for each entry in the matrix")
  in
  let find_list ~needle haystack =
    match
      List.find (fun (anchor, _) -> 0 = String.compare anchor.Yaml.value needle)
      haystack with
    | exception Not_found -> error_msg (Format.asprintf "%s must be provided" needle)
    | (_anchor, yaml) -> Ok yaml
  in
  let top_level_search ~needle top_level_yaml =
    match top_level_yaml with
    | `String _ | `Alias _ | `A _ -> error_msg "top level of YAML must be an object"
    | `O items ->
      find_list ~needle items
  in
  let get_env_strings ~section (top_level_yaml : Yaml.yaml) =
    top_level_search ~needle:"env" top_level_yaml >>= function
    | `String _ | `Alias _ | `A _ -> error_msg "env must have an object child"
    | `O env_contents -> find_list ~needle:section env_contents >>= function
      | `String _ | `Alias _ | `O _ ->
        error_msg (Format.asprintf "%s must have an array child" section)
      | `A contents -> Ok (List.fold_left (function acc -> function
          | `Alias _ | `A _ | `O _ -> acc
          | `String s ->
            match Parse_env.parse_env s.Yaml.value with
            | None -> []
            | Some map -> map :: acc) [] contents |> List.rev)
  in
  let extract_pins map =
    (* TODO: if PINS is set multiple times, this will take all of them.
       We should instead have the last setting override all previous ones. *)
    let package_name_of_pin_component s =
      match Astring.String.cut ~sep:"." s with
      | None -> OpamPackage.Name.of_string s
      | Some (name, _) -> OpamPackage.Name.of_string name
    in
    match Astring.String.Map.find "PINS" map with
    | None -> []
    | Some pins ->
      (* value is (we hope) a space-separated list of key-value pairs,
         with a pair expressed as name:pin_destination *)
      Astring.String.fields pins |> List.fold_left 
        (fun acc s ->
           match Astring.String.cut ~sep:":" s with
           | None -> (package_name_of_pin_component s, None)::acc
           | Some (name, loc) -> (package_name_of_pin_component name, Some loc)::acc
           | exception Failure _ -> acc 
        ) []
  in
  (* let get ~needle yaml =
    top_level_search ~needle yaml >>= function
    | `Alias _ | `A _ | `O _ -> error_msg (needle ^ " must be a string")
    | `String s -> Ok s.Yaml.value
     in *)
  get_env_strings ~section:"global" yaml >>= fun globals ->
  get_env_strings ~section:"matrix" yaml >>= fun matrix ->
  (* get ~needle:"script" yaml >>= fun script ->
  get ~needle:"install" yaml >>= fun install -> *)
  tests_of_matrix matrix >>= fun tests ->
  let globals = List.fold_left (fun acc m -> Astring.String.Map.merge
  (* merge strategy assumes that the last writer wins, which AFAICT is true *)
                                   (fun _name l r -> match l, r with
                                      | Some n, None -> Some n
                                      | None, Some n -> Some n
                                      | None, None -> None
                                      | Some _, Some r -> Some r)
                                   acc m)
      Astring.String.Map.empty globals in
  let pins = extract_pins globals in
  let globals = test_of_entry globals in
  Ok {Test.tests; pins; globals}
