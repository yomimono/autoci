let make_travis dir opams =
  let open Rresult.R in
  let dir = Fpath.v dir in (* straight outta Cmdliner.Arg.dir *)
  Opam.get_named_opams ~dir opams >>= function
  | [] -> Error (`Msg "No .opam files were found in the directory. Consider passing \
                          them, or the directory containing them, directly (see --help)")
  | opams ->
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
                        distro = Some "debian-stable";
                        do_test = None;
                        compiler = None;
                        package = None;}) in
  let tests = List.map tests opams |> List.flatten in
  let config = Test.({ pins; globals; tests; }) in
  let yaml = Travis.to_yaml config in
  Yaml.(yaml_to_string ~layout_style:`Block ~scalar_style:`Plain yaml) >>= fun str ->
  Ok str
