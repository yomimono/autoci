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
