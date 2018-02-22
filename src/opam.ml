(* [find_constraints needle formula : does formula contain any constraints
   on the package needle? *)
let rec find_constraints ~needle = function
  | OpamFormula.Empty -> false
  | OpamFormula.Atom (name, _) when
      OpamPackage.Name.(compare needle name) = 0 ->
    true
  | OpamFormula.Atom _ -> false
  | OpamFormula.Block formula -> find_constraints ~needle formula
  | OpamFormula.Or (a, b) | OpamFormula.And (a, b) ->
    find_constraints ~needle a || find_constraints ~needle b

let filter_build_only =
  OpamFilter.filter_deps ~build:true ~post:false ~test:false ~doc:false ~dev:false ~default:false

let depopt_names_of_opam opam =
  try
    OpamFile.OPAM.depopts opam |>
    filter_build_only |>
    OpamFormula.atoms |>
    List.map fst
  with Failure _ -> []

let compilers_of_opam opam =
  let depends = OpamFile.OPAM.depends opam |> filter_build_only in
  (* first check to see whether any ocaml constraints exist at all. if there
       are none, `verifies` will always return false, so just filtering will
       incorrectly give the empty list in that case. *)
  if find_constraints ~needle:(OpamPackage.Name.of_string "ocaml") depends then
    List.filter (fun (_, vers) -> OpamFormula.verifies depends vers) Test.known_compilers
  else Test.known_compilers (* no constraints, so try them all *)

let has_build_tests opam =
  try
    let build = OpamFile.OPAM.build opam in
    (* build is a OpamTypes.command list, which means an (arg list * filter option) list.
       we're interested in whether any items have a filter called "test" or
       "with-test" or some such. *)
    List.exists (fun (_args, filter) -> match filter with
        | Some (OpamTypes.FIdent ([], var, _)) -> Astring.String.equal "with-test" @@
          OpamVariable.to_string var
        | _ -> false
      ) build
  with
  | Failure _ -> false (* no build stanza means no build tests *)

let opam_with_name ~fpath opam =
  match OpamFile.OPAM.name_opt opam with
  | Some _name -> Ok opam (* opam states a name, so use it *)
  | None -> (* nothing explicit, so use the filename *)
    (* we use Fpath.v on file because it's either already been through cmdliner's
       checks to make sure it's a valid file that exists or came from
       Bos.OS.Dir.contents,  so presumably it's valid *)
    let filename = Fpath.(basename fpath) in
    let package_name =
      if Astring.String.equal "opam" filename then
        (* maybe we're playing by opam-repository rules *)
        Fpath.(split_base fpath |> fst |> basename)
      else filename
    in
    (* whether something.opam or something.version/opam, we're interested in
       the first bit *)
    match Astring.String.cut ~sep:"." package_name with
    | None ->
      Error (`Msg ("Could not determine the name for the package given in " ^
                   (Fpath.to_string fpath) ^ ".  Please set one explicitly via the \"name\" field, \
                           or rename the opam file to have a \".opam\" suffix."))
    | Some (name, _) ->
      try Ok (OpamFile.OPAM.with_name (OpamPackage.Name.of_string name) opam)
      with | Failure s -> Error (`Msg s)

(* give a list of strings representing what you think are valid opam files.
   if you have none, the function will attempt to discover some in the current
   directory.
   get back a set of OpamFile.OPAM.t's which are guaranteed to have a populated
   `name` field.
   any string which could not be made to fulfill that guarantee is discarded.
*)
let get_named_opams ~dir given_opams =
  let opams = match given_opams with
    | [] -> Files.discover_opams ~dir
    | given_opams -> List.map Fpath.v given_opams
  in
  List.fold_left (fun acc fpath ->
    let named_opam =
      let open Rresult.R in
      Files.parse_opam fpath >>= fun opam ->
      OpamFormatUpgrade.opam_file opam |> opam_with_name ~fpath
    in
    match named_opam with
    | Ok named_opam -> named_opam :: acc
    | Error (`Msg s) ->
      Printf.eprintf "Ignoring opam file %s because of error %s" (Fpath.to_string fpath) s; acc
  ) [] opams
