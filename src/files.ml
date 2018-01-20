let discover_opams ~(dir : Fpath.t) =
  let aux () =
    let open Rresult.R in
    Bos.OS.Dir.contents dir >>= fun c ->
    (* TODO: this doesn't traverse directories.  I didn't think this mattered until
       I saw ocaml-tftp, which has a directory `tftp.opam` which then contains
       descr, opam, and install files :/ *)
    (* this slightly weird-looking call to `exists` is here to make sure what we
       operate on is a file, not a directory; `exists` is more like
       `exists_and_is_a_file` *)
    let c = List.filter (fun c -> Bos.OS.File.exists c |> Rresult.R.get_ok) c in
    Ok (List.filter (fun path ->
	Bos.Pat.(matches (v "$(name).opam") (Fpath.basename path))) c)
  in
  match aux () with
  | Ok l -> l
  | Error _ -> []

let parse_opam fpath =
  let open Rresult.R in
  Bos.OS.File.read fpath >>= fun str ->
  try Ok (OpamFile.OPAM.read_from_string str)
  with Failure s -> Error (`Msg s)
