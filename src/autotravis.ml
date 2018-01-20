let opams =
  let doc = "opam files to consider when generating the CI configurations. \
             By default, any .opam file in the current directory will be considered. \
             Specifying any opam file manually will restrict the set to those specified." in
  Cmdliner.Arg.(value & opt_all non_dir_file [] & info ["opam"] ~docv:"OPAM" ~doc)

let dir =
  let doc = "directory in which to search for files.  If both OPAM and TRAVIS \
	     have been specified by the user, this will have no effect." in
  Cmdliner.Arg.(value & opt dir "." & info ["C"; "directory"] ~docv:"DIRECTORY" ~doc)

let make_travis dir opams =
  let open Rresult.R in
  let dir = Fpath.v dir in (* straight outta Cmdliner.Arg.dir *)
  let opams = Opam.get_named_opams ~dir opams in
  let pins = List.map (fun opam ->
      (OpamFile.OPAM.name opam, (Some "."))) opams in
  (* for this opam, get all the valid compilers *)
  (* TODO: is it appropriate to have a little bit of intelligence in here, like,
     "if I see a jbuilder build dep, I know that the version must be at least
     4.02"? *)
  let tests opam : (Test.test_info list) =
    let package = Some (OpamPackage.Name.to_string @@ OpamFile.OPAM.name opam) in
    let depopts = Test.List (Opam.depopt_names_of_opam opam) in
    let compilers = List.map (fun a -> snd a |> OpamPackage.version_to_string) 
	(Opam.compilers_of_opam opam) in
    List.map (fun compiler ->
	Test.({revdeps = List [];
	  distro = None;
	  do_test = None;
	  compiler = Some (Ocaml_version compiler);
	  depopts;
	  package;
	 })) compilers
  in
  let globals = Test.({ revdeps = List [];
			  depopts = List [];
			  distro = Some "ubuntu-16.04";
			  do_test = None;
			  compiler = None;
			  package = None;}) in
  let tests = List.map tests opams |> List.flatten in
  let config = Test.({ pins; globals; tests; }) in
  let yaml = Travis.to_yaml config in
  Yaml.(yaml_to_string ~layout_style:`Block ~scalar_style:`Plain yaml) >>= fun str ->
  Ok str

let make_t = Cmdliner.Term.(const make_travis $ dir $ opams)
let make_info =
  let doc = "Make Travis CI configuration automatically by consulting opam file(s)." in
  Cmdliner.Term.(info ~version:"%%VERSION%%" ~doc "autotravis")

let () =
  let open Cmdliner.Term in
  match eval (make_t, make_info) with
      | `Ok (Error (`Msg e)) -> Printf.eprintf "%s\n%!" e; exit_status (`Ok 1)
      | `Ok (Ok s) -> Printf.printf "%s\n%!" s; exit_status (`Ok 0)
      | `Error _ as a -> exit_status a
      | `Version -> exit_status `Version
      | `Help -> exit_status `Help
