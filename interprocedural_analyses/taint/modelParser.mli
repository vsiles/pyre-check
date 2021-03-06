(*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open Pyre

module ClassDefinitionsCache : sig
  val invalidate : unit -> unit
end

module T : sig
  type breadcrumbs = Features.Simple.t list [@@deriving show, compare]

  type leaf_kind =
    | Leaf of {
        name: string;
        subkind: string option;
      }
    | Breadcrumbs of breadcrumbs

  type taint_annotation =
    | Sink of {
        sink: Sinks.t;
        breadcrumbs: breadcrumbs;
        path: Abstract.TreeDomain.Label.path;
        leaf_name_provided: bool;
      }
    | Source of {
        source: Sources.t;
        breadcrumbs: breadcrumbs;
        path: Abstract.TreeDomain.Label.path;
        leaf_name_provided: bool;
      }
    | Tito of {
        tito: Sinks.t;
        breadcrumbs: breadcrumbs;
        path: Abstract.TreeDomain.Label.path;
      }
    | AddFeatureToArgument of {
        breadcrumbs: breadcrumbs;
        path: Abstract.TreeDomain.Label.path;
      }

  type annotation_kind =
    | ParameterAnnotation of AccessPath.Root.t
    | ReturnAnnotation
  [@@deriving show, compare]

  module ModelQuery : sig
    type annotation_constraint = IsAnnotatedTypeConstraint [@@deriving compare, show]

    type parameter_constraint = AnnotationConstraint of annotation_constraint
    [@@deriving compare, show]

    type model_constraint =
      | NameConstraint of string
      | ReturnConstraint of annotation_constraint
      | AnyParameterConstraint of parameter_constraint
      | AnyOf of model_constraint list
    [@@deriving compare, show]

    type kind =
      | FunctionModel
      | MethodModel
    [@@deriving show, compare]

    type produced_taint =
      | TaintAnnotation of taint_annotation
      | ParametricSourceFromAnnotation of {
          source_pattern: string;
          kind: string;
        }
      | ParametricSinkFromAnnotation of {
          sink_pattern: string;
          kind: string;
        }
    [@@deriving show, compare]

    type production =
      | AllParametersTaint of produced_taint list
      | ParameterTaint of {
          name: string;
          taint: produced_taint list;
        }
      | PositionalParameterTaint of {
          index: int;
          taint: produced_taint list;
        }
      | ReturnTaint of produced_taint list
    [@@deriving show, compare]

    type rule = {
      query: model_constraint list;
      productions: production list;
      rule_kind: kind;
      name: string option;
    }
    [@@deriving show, compare]
  end

  type parse_result = {
    models: TaintResult.call_model Interprocedural.Callable.Map.t;
    queries: ModelQuery.rule list;
    skip_overrides: Ast.Reference.Set.t;
    errors: string list;
  }
end

val parse
  :  resolution:Analysis.Resolution.t ->
  ?path:Path.t ->
  ?rule_filter:int list ->
  source:string ->
  configuration:Configuration.t ->
  TaintResult.call_model Interprocedural.Callable.Map.t ->
  T.parse_result

val verify_model_syntax : path:Path.t -> source:string -> unit

val compute_sources_and_sinks_to_keep
  :  configuration:Configuration.t ->
  rule_filter:int list option ->
  Sources.Set.t option * Sinks.Set.t option

val create_model_from_annotations
  :  resolution:Analysis.Resolution.t ->
  callable:Interprocedural.Callable.real_target ->
  sources_to_keep:Sources.Set.t option ->
  sinks_to_keep:Sinks.Set.t option ->
  (T.annotation_kind * T.taint_annotation) list ->
  TaintResult.call_model option
