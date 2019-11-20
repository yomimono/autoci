(lang dune 1.11)
(name autoci)

(license MIT)

(generate_opam_files true)

(maintainers "Mindy Preston <meetup@yomimono.org>")
(authors "Mindy Preston <meetup@yomimono.org>")
(source (github yomimono/autoci))

(package
 (name autoci)
 (depends
  (dune (>= 1.11))
  astring
  bos
  cmdliner
  fmt
  fpath
  opam-format
  opam-state
  (yaml (>= 2.0)))
  (synopsis "Generate cloud-based CI config for OCaml projects")
  (description "Generate cloud-based CI config for OCaml projects"))
