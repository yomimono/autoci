let make_appveyor dir opams =
  let open Rresult.R in
  let dir = Fpath.v dir in
  let default_variants compiler = [{
      Appveyor.version = OpamPackage.version compiler;
      Appveyor.port = Mingw;
      width = SixtyFour;
      precompiled = true;
    }; {
      Appveyor.version = OpamPackage.version compiler;
      Appveyor.port = Mingw;
      width = ThirtyTwo;
      precompiled = true;
     }]
  in
  Opam.get_named_opams ~dir opams >>= function
  | [] -> Error (`Msg "No .opam files were found in the directory. Consider passing \
                          them, or the directory containing them, directly (see --help)")
  | opams ->
  let pins = List.map (fun opam -> (OpamFile.OPAM.name opam, (Some "."))) opams in
  let tests_of_opam o =
    let compilers = Opam.compilers_of_opam o |> List.map snd in
    let switches = List.map default_variants compilers |> List.flatten in
    let depopts = Test.List (Opam.depopt_names_of_opam o) in
    let test switch =
      { Test.depopts = depopts;
        revdeps = List [];
        distro = None;
        do_test = None;
        compiler = Some (Opam_switch (Format.asprintf "%a" Appveyor.pp_switch switch));
        package = Some (OpamPackage.Name.to_string @@ OpamFile.OPAM.name o)
      }
    in
    List.map test switches
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
