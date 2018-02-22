(* to use lint/autoci in a library-y/unikernel-y way, need their functions
   split out somewhere that really will never be concerned with files etc *)
let all_packages_in_matrix _debug config opams =
  match List.map OpamFile.OPAM.name opams with
  | [_package] -> [] (* just one package should always be OK *)
  | packages ->
    List.find_all (fun package -> not @@ Test.package_is_installed ~package ~config) packages

(* if there are opam files with test dependencies but no tests in the opam file,
   travis won't build and run any tests via opam, so that seems like a problem *)
let test_deps_imply_buildable_test opam =
  (* are there any dependencies tagged with a `test` filter? *)
  let has_test_dep opam =
    let depends = OpamFile.OPAM.depends opam in
    OpamFilter.variables_of_filtered_formula depends |> List.exists (fun variable ->
        Astring.String.equal (OpamVariable.Full.to_string variable) "with-test")
  in
  (* if so, is there a with-test stanza in the build instructions? *)
  match has_test_dep opam with
  | false -> true (* no test deps, so we can't infer that there are tests *)
  | true -> Opam.has_build_tests opam

let all_test_having_packages_are_tested config opams =
  (* any opam file that has a `build-test` line should also have an entry in the
     test matrix for which TESTS is true *)
  let test_bearing_opams = List.fold_left (fun acc opam ->
      match Opam.has_build_tests opam with
      | false -> acc
      | true -> opam :: acc
    ) [] opams in
  let config_tests_package opam = match
      Test.tests_matching_package_name ~package:(OpamFile.OPAM.name opam) ~config
    with
    | `Global -> true
    | `Matrix [] -> (* this will still work if there's only one opam file *) 1 = (List.length opams)
    | `Matrix _ -> true
  in
  List.filter (fun o -> not (config_tests_package o)) test_bearing_opams |>
  List.map OpamFile.OPAM.name
