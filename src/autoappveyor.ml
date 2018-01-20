let opams =
  let doc = "opam files to consider when generating the CI configurations. \
             By default, any .opam file in the current directory will be considered. \
             Specifying any opam file manually will restrict the set to those specified." in
  Cmdliner.Arg.(value & opt_all non_dir_file [] & info ["opam"] ~docv:"OPAM" ~doc)

let dir =
  let doc = "directory in which to search for files.  If OPAM \
	     has specified by the user, this will have no effect." in
  Cmdliner.Arg.(value & opt dir "." & info ["C"; "directory"] ~docv:"DIRECTORY" ~doc)

let make_appveyor dir opams =
  let open Rresult.R in
  let dir = Fpath.v dir in
  let opams = Opam.get_named_opams ~dir opams in
  let pins = List.map (fun opam -> (OpamFile.OPAM.name opam, (Some "."))) opams in
  let tests_of_opam o =
    let compilers = Opam.compilers_of_opam o |> List.map snd in
    let test compiler =
      let switch = {
        Appveyor.version = OpamPackage.version compiler;
        Appveyor.port = Mingw; (* default from ocaml-ci-scripts *)
        width = SixtyFour; (* also default *)
        precompiled = true; (* I presume this is the case? *)
      } in
      { Test.depopts = List [];
        revdeps = List [];
        distro = None;
        do_test = None;
        compiler = Some (Opam_switch (Format.asprintf "%a" Appveyor.pp_switch switch));
        package = Some (OpamPackage.Name.to_string @@ OpamFile.OPAM.name o)
      }
    in
    List.map test compilers
  in
  let tests = List.map tests_of_opam opams |> List.flatten in
  let config = Test.{ pins;
                      tests;
                      globals = { depopts = List [];
                                  revdeps = List [];
                                  distro = None;
                                  do_test = None;
                                  compiler = None;
                                  package = None;
                                }
                    }
  in
  Yaml.yaml_to_string (Appveyor.to_yaml config) >>= fun yaml ->
  Ok yaml

let make_t = Cmdliner.Term.(const make_appveyor $ dir $ opams)
let make_info =
  let doc = "Make Appveyor configuration automatically by consulting opam file(s)." in
  Cmdliner.Term.(info ~version:"%%VERSION%%" ~doc "autoappveyor")

let () =
  let open Cmdliner.Term in
  match eval (make_t, make_info) with
      | `Ok (Error (`Msg e)) -> Printf.eprintf "%s\n%!" e; exit_status (`Ok 1)
      | `Ok (Ok s) -> Printf.printf "%s\n%!" s; exit_status (`Ok 0)
      | `Error _ as a -> exit_status a
      | `Version -> exit_status `Version
      | `Help -> exit_status `Help
