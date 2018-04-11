let lint debug dir travis opams : (unit, [`Msg of string]) result =
  let open Rresult.R in
  let pp_list_of_packages =
    Fmt.(list ~sep:comma (of_to_string OpamPackage.Name.to_string))
  in
  let dir = Fpath.v dir in (* straight outta Cmdliner.Arg.dir *)
  Opam.get_named_opams ~dir opams >>= fun opams ->
  if debug then begin
    Format.printf "found some opams: %a\n"
      Fmt.(list ~sep:sp (of_to_string OpamFile.OPAM.write_to_string)) opams
  end;
  Bos.OS.File.read (Fpath.(dir // v travis)) >>= Yaml.yaml_of_string
  >>= Travis.of_yaml >>= fun travis ->
  (* does each package in opams have a line in the test matrix? *)
  let packages_in_matrix =
    match Consistency.all_packages_in_matrix debug travis opams with
    | [] -> if debug then Printf.printf "All packages accounted for in matrix\n%!"; Ok ()
    | untested ->
      Error (`Msg (Format.asprintf
               "Packages whose installation is not tested (add them to the matrix): %a\n"
               pp_list_of_packages untested))
  in
  let packages_tested =
    match Consistency.all_test_having_packages_are_tested travis opams with
    | [] -> if debug then Printf.printf "All packages with test stanzas are tested\n%!";
      Ok ()
    | untested ->
      Error (`Msg (Format.asprintf "Packages whose tests aren't run (add them to the matrix): %a\n"
        pp_list_of_packages untested))
  in
  let test_deps_have_tests =
    match List.filter (fun o -> not (Consistency.test_deps_imply_buildable_test o)) opams with
    | [] -> if debug then Printf.printf "All opams with test deps have build stanzas for test\n%!"; Ok ()
    | non_buildable_tests ->
      Error (`Msg (Format.asprintf "Packages whose tests aren't built (add a with-test stanza to the opam file): %a\n"
        pp_list_of_packages (List.map OpamFile.OPAM.name non_buildable_tests)))
  in
  (* concatenate any error messages we've accumulated - don't fail to report
     any problems just because unrelated problems preceded them. *)
  List.fold_left (fun acc test -> match acc, test with
      | Error (`Msg e), Error (`Msg f) -> Error (`Msg (e ^ "\n" ^ f))
      | Error e, _ -> Error e
      | Ok (), Error e -> Error e
      | Ok (), Ok () -> Ok ()) (Ok ())
    [packages_in_matrix; packages_tested; test_deps_have_tests]

let term_ready debug dir travis opams =
  match lint debug dir travis opams with
  | Ok () -> Ok "No errors detected."
  | Error e -> Error e
