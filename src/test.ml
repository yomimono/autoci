type revdepopts =
  | List of OpamPackage.Name.t list
  | All

type compiler =
  | Ocaml_version of string
  | Opam_switch of string

type test_info = {
  depopts : revdepopts;
  revdeps : revdepopts;
  distro : string option;
  do_test : bool option;
  compiler : compiler option;
  package : string option;
}

type t = {
  pins : (OpamPackage.Name.t * string option) list;
  globals : test_info;
  tests : test_info list;
}

let known_compilers =
  (* known_compilers is a mirror of the set of OCaml compilers in
     ocaml-ci-scripts/.travis-ocaml.sh 's switch statement on OPAM versions and
     OCaml versions. The full versions are put here for correct comparison with
     the `ocaml` dependency in an opam file or generation for a test script
     which expects them to be fully specified. *)
  let ocaml = OpamPackage.Name.of_string "ocaml" in
  let package v = OpamPackage.(create ocaml (Version.of_string v)) in
  [
    "3.12", package "3.12.1"; (* possibly we should remove this *)
    "4.00", package "4.00.1";
    "4.01", package "4.01.0";
    "4.02", package "4.02.3"; (* another sensible line to draw would be
                                 not including this or any earlier versions *)
    "4.03", package "4.03.0";
    "4.04", package "4.04.2";
    "4.05", package "4.05.0";
    "4.06", package "4.06.0";
  ]

(* circumstances that can lead to a package being installed:
   a matrix entry including package in PACKAGE, DEPOPTS, REVDEPS, or (TODO) EXTRA_DEPS (ugh)
   a PACKAGE, DEPOPTS, or REVDEPS *explicitly* including package, and a matrix entry not overriding that
   a PACKAGE, DEPOPTS, or REVDEPS *explicitly* including package, and no matrix entries *)
(* these are easiest to evaluate per-matrix entry, so let's see what's in the matrix *)
let package_is_installed ~package ~config =
  let is_installed_from_global =
    match config.globals.package with
    | Some v when Astring.String.equal v (OpamPackage.Name.to_string package) -> true
    | _ -> match config.globals.depopts with
      | List depopts when List.mem package depopts -> true
      | _ -> match config.globals.revdeps with
	| List revdeps when List.mem package revdeps -> true
        | _ -> false
  in
  let is_installed_from_matrix_entry entry =
    let package_matches =
      match entry.package with
      | Some v when Astring.String.equal v (OpamPackage.Name.to_string package) -> true
      | Some _ -> false
      | None -> match config.globals.package with
	  | Some v when Astring.String.equal v (OpamPackage.Name.to_string package) -> true
          | _ -> false
    in
    let depopts_matches =
      match entry.depopts with
      | All -> false
      | List depopts when List.mem package depopts -> true
      | List (_::_) -> false
      | List [] -> match config.globals.depopts with
	| List depopts when List.mem package depopts -> true
        | _ -> false
    in
    let revdeps_matches =
      match entry.revdeps with
      | All -> false
      | List revdeps when List.mem package revdeps -> true
      | List (_::_) -> false
      | List [] -> match config.globals.revdeps with
	| List revdeps when List.mem package revdeps -> true
        | _ -> false
    in
    package_matches || depopts_matches || revdeps_matches
  in
  match config.tests with
  | [] -> is_installed_from_global
  | tests -> List.exists (is_installed_from_matrix_entry) tests

let package_is_tested ~package ~config ~test =
  match test.package, config.globals.package with
  | None, None -> false
  | None, Some v (* global package matters only when local is unset *)
  | Some v, _ when Astring.String.equal v (OpamPackage.Name.to_string package) ->
    begin
      match test.do_test with
      | Some true -> true
      | Some false -> false (* only if we were explicitly told not to
                                     test, will we not test *)
      | None ->
      (* tests not specified in the matrix; make sure they weren't disabled in
           globals *)
        match config.globals.do_test with
        | Some false -> false
        | Some true | None -> true (* the config scripts default to testing, so None
                                      should be a pass here *)
    end
  | Some _, _ | None, _ -> false

(* return all of the `test` definitions matching the package name where TESTS is
   not set to "false". *)
let tests_matching_package_name ~package ~config =
  let name_eq ~str n = Astring.String.equal str (OpamPackage.Name.to_string n) in
  let last_ditch_global ~package ~config =
    match config.tests with
    | _::_ -> false
    | [] -> match config.globals.do_test with
      | Some false -> false
      | Some true | None ->
	match config.globals.package with
	| None -> false
        | Some v -> Astring.String.equal (OpamPackage.Name.to_string package) v
  in
  let matches ~default =
    List.filter (fun test -> match test.package with
	| Some str -> name_eq ~str package
        | None -> default) config.tests
  in
  let hits = 
    match config.globals.package with
    | None -> matches ~default:false
    | Some str when not (name_eq ~str package) -> matches ~default:false
    | Some _ -> (* the tests are those in the matrix which have no name, or have a
		   name matching that passed in *)
      matches ~default:true
  in
  (* further filter by whether TESTS will be enabled when the test is run *)
  let test_base = match config.globals.do_test with
    | None | Some true -> true
    | Some false -> false
  in
  match List.filter (fun test -> match test.do_test with | None -> test_base | Some k -> k) hits with
  | (_::_) as l -> `Matrix l
  | [] -> if last_ditch_global ~package ~config then `Global else `Matrix []

let pp_package_list = Fmt.(list ~sep:sp (of_to_string OpamPackage.Name.to_string))
let pp_pin = Fmt.(pair ~sep:(const string ":") (of_to_string OpamPackage.Name.to_string) (option string))
let pp_pins fmt pins =
  match pins with
  | [] -> ()
  | l -> Fmt.pf fmt "PINS=@[\"%a\"@]" Fmt.(list ~sep:(const string " ") pp_pin) l

let str_of_pins = function
  | [] -> None
  | pins -> Some (List.map (Format.asprintf "%a" pp_pin) pins |> Astring.String.concat ~sep:" ")

let test_info_to_assoc_list info =
  let str_of_revdepopts ~name acc = function
    | List [] -> acc
    | All -> (name, "*")::acc
    | List l -> (name, Format.asprintf "@[\"%a\"] " pp_package_list l)::acc
  in
  let maybe_add ~name ~v_printer v l = match v with
    | None -> l
    | Some v -> (name, (v_printer v))::l
  in
  let l = str_of_revdepopts ~name:"DEPOPTS" [] info.depopts in
  let l = str_of_revdepopts ~name:"REVDEPS" l info.revdeps in
  let l = maybe_add ~name:"DISTRO" ~v_printer:(fun a -> a) info.distro l in
  let l = maybe_add ~name:"TESTS" ~v_printer:string_of_bool info.do_test l in
  let l = maybe_add ~name:"PACKAGE" ~v_printer:(fun a -> a) info.package l in
  match info.compiler with
  | None -> l
  | Some (Ocaml_version s) -> ("OCAML_VERSION", s)::l
  | Some (Opam_switch s) -> ("OPAM_SWITCH", s)::l

let test_info_to_var_string info =
  let pp_revdepopts_with_label ~label fmt = function
    | List [] -> ()
    | All -> Fmt.pf fmt "@[%s=\"*\"@] " label
    | List l -> Fmt.pf fmt "@[%s=\"%a\"@] " label pp_package_list l
  in
  let pp_revdeps = pp_revdepopts_with_label ~label:"REVDEPS" in
  let pp_depopts = pp_revdepopts_with_label ~label:"DEPOPTS" in
  let pp_env_option ~name fmt = function
    | None -> ()
    | Some value -> Fmt.pf fmt "@[%s=\"%s\"@] " name value
  in
  let pp_tests_option fmt = function
    | None -> ()
    | Some b -> Fmt.pf fmt "@[TESTS=\"%b\"@] " b
  in
  let pp_ocaml_version fmt = function
    | None -> ()
    | Some (Ocaml_version s) -> Fmt.pf fmt "@[%s=\"%s\"@] " "OCAML_VERSION" s
    | Some (Opam_switch s) -> Fmt.pf fmt "@[%s=\"%s\"@] " "OPAM_SWITCH" s
  in
  let pp_distro = pp_env_option ~name:"DISTRO" in
  let pp_package = pp_env_option ~name:"PACKAGE" in
  let pp fmt info = Fmt.pf fmt "@[%a%a%a%a%a%a@]"
      pp_package info.package
      pp_distro info.distro
      pp_ocaml_version info.compiler
      pp_tests_option info.do_test
      pp_depopts info.depopts
      pp_revdeps info.revdeps
  in
  Fmt.strf "%a" pp info |> Astring.String.trim (* TODO: :/ *)
