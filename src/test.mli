type revdepopts =
  | List of OpamPackage.Name.t list
  | All
(** revdeps or depopts.  Both are interpreted by ocaml-ci-scripts similarly:
    either nothing, a list of specific package names, or "*" to let opam
    figure out the full set based on the opam file for the package and 
    the current state of any opam repositories that it might know about. *)

type compiler =
  | Ocaml_version of string
  | Opam_switch of string
(** Somewhat clumsily, OCAML_VERSION for Travis config and OPAM_SWITCH for
    Appveyor.  OPAM_SWITCH encompasses more information. *)

type test_info = {
  depopts : revdepopts;
  revdeps : revdepopts;
  distro : string option; (* distro is only meaningful for travis tests *)
  do_test : bool option;
  compiler : compiler option;
  package : string option;
}
(** configuration for a specific test. *)

type t = {
  pins : (OpamPackage.Name.t * string option) list;
  globals : test_info;
  tests : test_info list;
}
(** top-level configuration of the tests.  Any specific [test_info] may be
    evaluated in the context of this configuration. *)

val known_compilers : (string * OpamPackage.t) list
(** [known_compilers] is an associative list of strings recognized as
    valid OCAML_VERSION parameters by travis-ocaml.sh and their corresponding
    full OpamPackage.t definitions (including patch version).  Looking up
    "4.02" will get the package corresponding to "ocaml.4.02.3". *)

val str_of_pins : (OpamPackage.Name.t * string option) list -> string option
(** [str_of_pins pins] will format [pins], if nonempty, as a single string suitable
    for inclusion in an assoc list.  There is no initial PINS written.  An empty
    [pins] returns None.*)

val pp_pins : Format.formatter -> (OpamPackage.Name.t * string option) list -> unit
(** [pp_pins fmt pins] will format [pins] as a single string suitable
    for inclusion in a set of environment variables.  The initial PINS= is included
    in the output of pp_pins. *)

val test_info_to_var_string : test_info -> string
(** [test_info_to_var_string test_info] prepares [test_info] for inclusion
    in a test matrix by reducing it to a single string representing all
    populated values in [test_info]. *)

val test_info_to_assoc_list : test_info -> (string * string) list
(** [test_info_to_assoc_list] prepares [test_info] for inclusion in a test
    matrix by expressing the populated fields of [test_info] and their values
    as a list of name-value pairs. *)

val package_is_tested : package:OpamPackage.Name.t -> config:t
  -> test:test_info -> bool
(** [package_is_tested ~package ~config ~test] is true if [test] will install
    [package] and run any tests it might have when evaulated in the context of
    [config]. *)

val package_is_installed : package:OpamPackage.Name.t -> config:t -> bool
(** [package_is_installed ~package ~config ~test] is true [test] will install
    [package] at any point, whether it is because [package] is being tested or
    as a dependency of another test (an explicit entry in REVDEPS or DEPOPTS).*)

val tests_matching_package_name : package:OpamPackage.Name.t -> config:t ->
  [ `Matrix of test_info list | `Global ]
(** [tests_matching_package package travis] gives the (potentially empty)
    list of packages in [travis]'s test matrix which are executed on [package].
    If the matrix is empty but [package] will be tested as part of a global run,
    [`Global] will be returned, and the user is encouraged to refer to
    [travis.globals] for further details about the test matching [package]. *)

val of_yaml : Yaml.yaml -> (t, [> `Msg of string]) result
(** [of_yaml yaml] does its best to interpret [yaml] as a set of Travis build
    instructions. *)

(* the expected to_yaml is missing. The intended end user matters, so it is
   expected that a particular configuration generator will implement this
   themselves (e.g. autotravis, autoappveyor in the same repository). *)
