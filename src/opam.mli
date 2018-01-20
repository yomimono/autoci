val depopt_names_of_opam : OpamFile.OPAM.t -> OpamPackage.Name.t list
(** [depopt_names_of_opam opam] returns the list of optional dependencies
    ("depopts") given in [opam].  It includes build-time dependencies but no
    other filters. *)

val compilers_of_opam : OpamFile.OPAM.t -> (string * OpamPackage.t) list
(** [compilers_of_opam] returns the list of OCaml compiler versions that [opam]
    indicates are supported by the package.  These are in the form
    (OCAML_VERSION, OpamPackage.t), where OCAML_VERSION is the text field for
    an environment variable in .travis.yml (as interpreted by ocaml-ci-scripts). *)

val has_build_tests : OpamFile.OPAM.t -> bool
(** [has_build_tests opam] attempts to determine whether [opam] has any tests
    declared in its build stanzas (in other words, any "with-test" sections). *)

val get_named_opams : dir:Fpath.t -> string list -> OpamFile.OPAM.t list
(** [get_named_opams ~dir given_opams] will use information in [dir] to ascribe
    correct names to [given_opams], if [given_opams] is not the empty list.
    If [get_named_opams ~dir] is called with an empty list argument, [dir] will
    be scanned for valid opam files, which will have names ascribed to them. *)
