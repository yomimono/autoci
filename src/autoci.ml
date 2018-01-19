let travis_output =
  let doc = "Output file for Travis CI configuration." in
  Cmdliner.Arg.(value & opt file ".travis.yml" & info ["travis_out"]
                  ~docv:"TRAVIS_OUTPUT" ~doc)

let opams =
  let doc = "opam files to consider when generating the CI configurations. \
             By default, any .opam file in the current directory will be considered. \
             Specifying any opam file manually will restrict the set to those specified." in
  Cmdliner.Arg.(value & opt_all file [] & info ["opam"] ~docv:"OPAM" ~doc)

let make_travis opams _travis_output =
  let _travis_preamble = [
    "language: c";
    "install: wget https://raw.githubusercontent.com/ocaml/ocaml-ci-scripts/master/.travis-opam.sh";
    "script: bash -ex .travis-opam.sh";
  ] in
  (* known_compilers is a mirror of the set of OCaml compilers in
     ocaml-ci-scripts/.travis-ocaml.sh 's switch statement on OPAM versions and
     OCaml versions. *)
  let known_compilers = [
    "3.12"; (* possibly we should remove this *)
    "4.00";
    "4.01";
    "4.02"; (* another sensible line to draw would be not including this or any
            earlier versions *)
    "4.03";
    "4.04";
    "4.05";
    "4.06";
  ] in
  let filter_unparseables opams =
    List.fold_right (fun opam acc ->
        try (OpamParser.file opam) :: acc
        with Parsing.Parse_error ->
          Printf.eprintf "Could not parse the opam file %s - disregarding it\n%!" opam;
          acc
      ) opams []
  in
  (* TODO don't reparse the whole file every time, maybe *)
  let pos = OpamTypesBase.pos_null in
  let opams = filter_unparseables opams in
  (* what do we need from the opams? names, OCaml versions; later depopts probably *)
  let get_name opam =
    (* your name is what you say it is *)
    match fst @@ OpamPp.parse ~pos (OpamFormat.I.extract_field "name")
        opam.OpamParserTypes.file_contents with
    | Some (OpamTypes.String (_, name)) -> Ok name
    | Some _ | None -> (* if you didn't specify a name, fall back to filename *)
      let name = Fpath.(basename @@ v opam.file_name) in
      match Astring.String.cut ~sep:".opam" name with
      | None -> Error ("Could not infer package name from " ^ name ^
                       " - consider passing it explicitly")
      | Some (name, _) -> Ok name
  in
  let get_ocaml_version opam =
    let open OpamTypes in
    match fst @@ OpamPp.parse ~pos (OpamFormat.I.extract_field "depends")
        opam.OpamParserTypes.file_contents
    with
    | None | Some Bool _ | Some Int _ | Some String _ | Some Relop _
    | Some Prefix_relop _ | Some Logop _ | Some Pfxop _ | Some Ident _
    | Some Group _ | Some Option _ | Some Env_binding _ -> []
    | Some (List (_, l)) ->
      let extract_constraints o default =
        match o with
        | OpamTypes.Option (_, OpamTypes.String (_, name), constraints) when
            (0 = String.compare name "ocaml") -> constraints
        | _ -> default
      in
      (* is ocaml among the contents? *)
      try
        match List.fold_right extract_constraints l [] with
          | [] -> known_compilers (* no ocaml, no constraints *)
          | Option (_, _, constraints)::_ -> begin
            (* there are actual constraints here!! Maybe OpamFormula can help us? *)
            let version_constraint_of_value = function
              | Prefix_relop (_, relop, (OpamTypes.String (_, version))) ->
                Some (relop, OpamPackage.Version.of_string version)
              (* TODO: need to handle non-relative operations, more than one
                 operation, and loads of other possible formulas too;
                 it's rather annoying that this gets passed off to dose in opam
                 proper, so we can't copy it :/ *)
              | _ -> None
            in
            let satisfies_constraint ocaml_formula travis_string =
              OpamFormula.(check_version_formula
                           (Atom ocaml_formula)
                           (OpamPackage.Version.of_string travis_string))
            in
            List.map version_constraint_of_value constraints |> function
            | (Some c)::_ -> List.filter (satisfies_constraint c) known_compilers
            | _ -> known_compilers
          end
      with
      | Not_found -> known_compilers (* no constraints *)
  in
  let names = List.map get_name opams in
  (* assemble PINS *)
  (* for now, ignore any files we failed to extract information from, but
     TODO probably need to complain about them first, and perhaps have
     a --strict toggle or something *)
  (* TODO use fmt for this *)
  let pins = List.fold_left (fun acc name -> match name with
      | Error _ -> acc
      | Ok name -> (name ^ ":. ") ^ acc
    ) "" names in
  let pins = Printf.sprintf "PINS=\"%s\"" pins in
  let globals = [pins;] in
  let compilers = List.map get_ocaml_version opams in
  Printf.printf "%s\n%!" pins;
  List.iter (Printf.printf "%s\n%!") globals;
  List.iter (List.iter (Printf.printf "%s\n%!")) compilers;
  ()


let make_t = Cmdliner.Term.(const make_travis $ opams $ travis_output)
let make_info =
  let doc = "Make CI configuration automatically by consulting opam file(s)." in
  Cmdliner.Term.(info ~version:"%%VERSION%%" ~doc "autoci")

let () = Cmdliner.Term.(exit @@ eval (make_t, make_info))
