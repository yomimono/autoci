(* CI linter, aware of both opam files and travis configurations. *)
let opams =
  let doc = "opam files to consider when linting. \
             By default, any .opam file in the current directory will be considered. \
             Specifying any opam file manually will restrict the set to those specified." in
  Cmdliner.Arg.(value & opt_all file [] & info ["opam"] ~docv:"OPAM" ~doc)

let travis =
  let doc = "yaml file containing Test configuration to consider when linting." in
  Cmdliner.Arg.(value & opt file ".travis.yml" & info ["travis"]
                  ~docv:"TRAVIS" ~doc)

let dir =
  let doc = "directory in which to search for files.  If both OPAM and TRAVIS \
             have been specified by the user, this will have no effect." in
  Cmdliner.Arg.(value & opt dir "." & info ["C"; "directory"] ~docv:"DIRECTORY" ~doc)

let debug =
  let doc = "print messages about passing tests, as well as failing ones." in
  Cmdliner.Arg.(value & flag & info ["d"] ~doc)

let lint debug dir travis opams =
  let open Rresult.R in
  let pp_list_of_packages =
    Fmt.(list ~sep:comma (of_to_string OpamPackage.Name.to_string))
  in
  let dir = Fpath.v dir in (* straight outta Cmdliner.Arg.dir *)
  let opams = Opam.get_named_opams ~dir opams in
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

let lint_t = Cmdliner.Term.(const lint $ debug $ dir $ travis $ opams)
let lint_info =
  let doc = "Check CI configuration against opam, and warn on inconsistencies." in
  Cmdliner.Term.(info ~version:"%%VERSION%%" ~doc "lint")

let () =
  let open Cmdliner.Term in
  match eval (lint_t, lint_info) with
      | `Ok (Error (`Msg e)) -> Printf.eprintf "%s\n%!" e; exit_status (`Ok 1)
      | `Ok (Ok ()) -> exit_status (`Ok 0)
      | `Error _ as a -> exit_status a
      | `Version -> exit_status `Version
      | `Help -> exit_status `Help
