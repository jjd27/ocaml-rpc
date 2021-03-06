(*
 * Copyright (c) 2006-2009 Citrix Systems Inc.
 * Copyright (c) 2006-2014 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*)

let debug = ref false
let set_debug x = debug := x
let get_debug () = !debug
let lower = String.lowercase

type t =
  | Int of int64
  | Int32 of int32
  | Bool of bool
  | Float of float
  | String of string
  | DateTime of string
  | Enum of t list
  | Dict of (string * t) list
  | Null

exception Runtime_error of string * t
exception Runtime_exception of string * string

open Printf
let map_strings sep fn l = String.concat sep (List.map fn l)
let rec to_string t = match t with
  | Int i      -> sprintf "I(%Li)" i
  | Int32 i    -> sprintf "I32(%li)" i
  | Bool b     -> sprintf "B(%b)" b
  | Float f    -> sprintf "F(%g)" f
  | String s   -> sprintf "S(%s)" s
  | DateTime s -> sprintf "D(%s)" s
  | Enum ts    -> sprintf "[%s]" (map_strings ";" to_string ts)
  | Dict ts    -> sprintf "{%s}" (map_strings ";" (fun (s,t) -> sprintf "%s:%s" s (to_string t)) ts)
  | Null       -> "N"


let rpc_of_t x = x
let rpc_of_int64 i = Int i
let rpc_of_int32 i = Int (Int64.of_int32 i)
let rpc_of_int i = Int (Int64.of_int i)
let rpc_of_bool b = Bool b
let rpc_of_float f = Float f
let rpc_of_string s = String s
let rpc_of_dateTime s = DateTime s
let rpc_of_unit () = Null

let t_of_rpc x = x
let int64_of_rpc = function
  | Int i    -> i
  | String s -> Int64.of_string s
  | _ -> failwith "int64_of_rpc"
let int32_of_rpc = function
  | Int i    -> Int64.to_int32 i
  | String s -> Int32.of_string s
  | _ -> failwith "int32_of_rpc"
let int_of_rpc = function
  | Int i    -> Int64.to_int i
  | String s -> int_of_string s
  | _ -> failwith "int_of_rpc"
let bool_of_rpc = function Bool b -> b | _ -> failwith "bool_of_rpc"
let float_of_rpc = function
  | Float f  -> f
  | String s -> float_of_string s
  | _ -> failwith "float_of_rpc"
let string_of_rpc = function String s -> s | _ -> failwith "string_of_rpc"
let dateTime_of_rpc = function DateTime s -> s | _ -> failwith "dateTime_of_rpc"
let unit_of_rpc = function Null -> () | _ -> failwith "unit_of_rpc"

let lowerfn = function | String s -> String (lower s) | Enum (String s::ss) -> Enum ((String (lower s))::ss) | x -> x

let struct_extend rpc default_rpc =
  match rpc, default_rpc with
  | Dict real, Dict default_fields ->
    Dict (List.fold_left (fun real (f, default) ->
      if List.mem_assoc f real
      then real
      else (f, default) :: real) real default_fields)
  | _, _ -> rpc

type callback = string list -> t -> unit

type call = {
  mutable id: int64 option;
  name: string;
  params: t list;
}

let call id name params = { id = id; name = name; params = params }

let string_of_call call =
  sprintf "-> %s(%s)" call.name (String.concat "," (List.map to_string call.params))

type response = {
  mutable id: int64 option;
  success: bool;
  contents: t;
}

let string_of_response response =
  sprintf "<- %s(%s)" (if response.success then "success" else "failure") (to_string response.contents)

let success id v = { success = true; id = id; contents = v }
let failure id v = { success = false; id = id; contents = v }
