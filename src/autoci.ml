open Cmdliner

let version="%%VERSION%%"

let opams =
  let doc = "opam files to consider when generating the CI configurations. \
             By default, any .opam file in the current directory will be considered. \
             Specifying any opam file manually will restrict the set to those specified." in
  Arg.(value & opt_all non_dir_file [] & info ["opam"] ~docv:"OPAM" ~doc)

let dir =
  let doc = "directory in which to search for files.  If both OPAM and TRAVIS \
             have been specified by the user, this will have no effect." in
  Arg.(value & opt dir "." & info ["C"; "directory"] ~docv:"DIRECTORY" ~doc)

let travis =
  let doc = "yaml file containing Travis configuration to consider when linting." in
  Arg.(value & opt file ".travis.yml" & info ["travis"]
                  ~docv:"TRAVIS" ~doc)

let lint_debug =
  let doc = "print messages about passing tests, as well as failing ones." in
  Arg.(value & flag & info ["d"] ~doc)

let travis_t = Term.(term_result (const Autotravis.make_travis $
                                           dir $ opams))
let travis_info =
  let doc = "Make Travis CI configuration automatically by consulting opam file(s)." in
  Term.(info ~version ~doc "travis")

let lint_t = Term.(term_result (const Lint.term_ready $
                                         lint_debug $ dir $ travis $ opams))
let lint_info =
  let doc =
    "Check CI configuration against opam, and warn on inconsistencies."
  in Term.(info ~version ~doc "lint")

let appveyor_t = Term.(term_result (const Autoappveyor.make_appveyor $
                                             dir $ opams))
let appveyor_info =
  let doc = "Make Appveyor configuration automatically by consulting opam file(s)." in
  Term.(info ~version ~doc "appveyor")

let travis_to_appveyor_t =
  let doc = "Travis file to consult for configuration.  If not provided, look for \
               a .travis.yml in the current directory." in
  let travis =
    Arg.(value & opt non_dir_file ".travis.yml" & info ["travis"] ~docv:"TRAVIS" ~doc) in
  Term.(term_result (const Travis_to_appveyor.make_appveyor $ travis))

let travis_to_appveyor_info =
  Term.(info ~version
                   ~doc:"Make Appveyor configuration automatically from an existing travis configuration" "travis_to_appveyor")

let autoci_t =
  let always_help : type k.k Term.ret =
    Term.(Manpage.(`Help (`Auto, Some "autoci")))
  in
  Term.(ret @@ const @@ always_help)

let autoci_info =
  Term.(info ~version ~doc:"Generate and automatically check CI configurations against .opam files." "autoci")

let () =
  let print_success = function
    | `Ok str -> Printf.printf "%s%!" str
    | _ -> ()
  in
  let result = Term.eval_choice (autoci_t, autoci_info)
          [appveyor_t, appveyor_info;
           lint_t, lint_info;
           travis_t, travis_info;
           travis_to_appveyor_t, travis_to_appveyor_info;
          ] in
  print_success result;
  Term.exit @@ result
