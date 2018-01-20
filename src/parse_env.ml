(*---------------------------------------------------------------------------
   Copyright (c) 2015 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   %%NAME%% %%VERSION%%
  ---------------------------------------------------------------------------*)

(* This example code from Astring's documentation happens to do exactly what we
   need, so use it directly and thank dbuenzli for generous licensing :) *)

open Astring

let parse_env : string -> string String.map option =
fun s -> try
  let skip_white s = String.Sub.drop ~sat:Char.Ascii.is_white s in
  let parse_key s =
    let id_char c = Char.Ascii.is_letter c || c = '_' in
    match String.Sub.span ~min:1 ~sat:id_char s with
    | (key, _) when String.Sub.is_empty key -> raise Exit
    | (key, rem) -> (String.Sub.to_string key), rem
  in
  let parse_eq s = match String.Sub.head s with
  | Some '=' -> String.Sub.tail s
  | Some _ | None -> raise Exit
  in
  let parse_value s = match String.Sub.head s with
  | Some '"' -> (* quoted *)
      let is_data = function '\\' | '"' -> false | _ -> true in
      let rec loop acc s =
        let data, rem = String.Sub.span ~sat:is_data s in
        match String.Sub.head rem with
        | Some '"' ->
            let acc = List.rev (data :: acc) in
            String.Sub.(to_string @@ concat acc), (String.Sub.tail rem)
        | Some '\\' ->
            let rem = String.Sub.tail rem in
            begin match String.Sub.head rem with
            | Some ('"' | '\\' as c) ->
                let acc = String.(sub (of_char c)) :: data :: acc in
                loop acc (String.Sub.tail rem)
            | Some _ | None -> raise Exit
            end
        | None | Some _ -> raise Exit
      in
      loop [] (String.Sub.tail s)
  | Some _ ->
      let is_data c = not (Char.Ascii.is_white c) in
      let data, rem = String.Sub.span ~sat:is_data s in
      String.Sub.to_string data, rem
  | None -> "", s
  in
  let rec parse_bindings acc s =
    if String.Sub.is_empty s then acc else
    let key, s = parse_key s in
    let value, s = s |> skip_white |> parse_eq |> skip_white |> parse_value in
    parse_bindings (String.Map.add key value acc) (skip_white s)
  in
  Some (String.sub s |> skip_white |> parse_bindings String.Map.empty)
with Exit -> None

(*---------------------------------------------------------------------------
   Copyright (c) 2015 Daniel C. Bünzli

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
