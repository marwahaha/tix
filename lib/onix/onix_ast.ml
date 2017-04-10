type expression =
  | Access_path of access_path
  (*
   * x
   * x.y
   * x.y or e
   * *)
  | Constant of constant
  | String of str
  (* Not constant because of interpolation *)
  | Lambda of lambda
  | Fun_app of expression * expression
  | List of expression list
  | Record of record
  | With of expression * expression
  (* with e; e *)
  | Let of binding list * expression

and access_path =
  | Ap_var of string
  | Ap_field of string * field_desc * expression option
  (* x.f or e *)

and field_desc =
  | Fdesc_identifier of string
  | Fdesc_string of str
  | Fdesc_interpol of interpol

and constant =
  | Cst_int of int
  | Cst_path of string
  | Cst_url of string

and str = str_element list

and str_element =
  | Str_constant of string
  | Str_interpol of interpol

and lambda = pattern * expression

and pattern =
  | Pvar of string
  | Pnontrivial of nontrivial_pattern
  | Paliased of nontrivial_pattern * string

and nontrivial_pattern =
  | Precord of (string * expression option) list * closed_flag * string option
  (* fields * '...' * @a *)

and closed_flag =
  | Closed
  | Open

and record = {
  recursive : bool;
  fields : field list;
}

and field =
  | Field_definition of access_path * expression
  | Inherit of inherit_
  (* inherit x y z...;
   * inherit (e) x y z...;
   *)

and binding =
  | Bdef of access_path * expression
  | Binherit of inherit_

and inherit_ = expression option * string list

and interpol = expression
