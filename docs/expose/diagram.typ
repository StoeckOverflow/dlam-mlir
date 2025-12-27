#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

#set page(width: auto, height: auto, margin: 5mm, fill: white)

#diagram(
  node-stroke: luma(80%),
  edge-corner-radius: none,
  spacing: (10pt, 20pt),

  node(
    (1.5, 0),
    [
      *S -- Situation* \
      Symbolic, value-dependent properties (shapes, bounds, dimension relations) \
      matter for correctness and performance, but are not preserved as type-level invariants in MLIR.
    ],
    name: <S>,
  ),

  node(
    (0.5, 1),
    [
      *C1 -- Complication (Core MLIR)* \
      MLIR types are uniqued, structural descriptors and cannot depend on SSA values or regional scope; \
      value-dependent invariants therefore cannot be carried in types across passes.
    ],
    name: <C1>,
  ),

  node(
    (2.5, 1),
    [
      *C2 -- Complication (Tensor/Shapes)* \
      Shape/bounds constraints live operationally (SSA + attributes + analyses), so tensor passes \
      must repeatedly re-derive and re-check legality conditions.
    ],
    name: <C2>,
  ),

  node(
    (0.5, 2),
    [
      *Q1 -- Question (MLIR Core)* \
      How can value-dependent information be represented at the type level in MLIR while respecting \
      its SSA-based structure and remaining stable under IR transformations?
    ],
    name: <Q1>,
  ),

  node(
    (2.5, 2),
    [
      *Q2 -- Question (Tensor Dialect)* \
      How can value-dependent types be used to express and preserve tensor shape invariants that are \
      relevant for correctness and optimization across tensor transformations?
    ],
    name: <Q2>,
  ),

  node(
    (0.5, 3),
    [
      *A1 -- Answer (Core Approach)* \
      Stage the design in ScaIR: \
      (1) type variables for parametric polymorphism; \
      (2) generalize to value parameters by allowing SSA values as type arguments with scoping \
      and substitution under transformations.
    ],
    name: <A1>,
  ),

  node(
    (2.5, 3),
    [
      *A2 -- Answer (Tensor Case Study)* \
      Define value-indexed tensor/vector and index types (e.g., `tensor<%n x f32>`, `Idx(%n)`) \
      to carry symbolic shape/bounds parameters as stable type-level metadata for legality checks.
    ],
    name: <A2>,
  ),

  node(
    (0.5, 4),
    [
      *V1 -- Value (Core)* \
      Clarifies minimal mechanisms and MLIR constraints for type-level parameters, \
      and what must hold for transformation-stable value-dependent typing.
    ],
    name: <V1>,
  ),

  node(
    (2.5, 4),
    [
      *V2 -- Value (Tensor)* \
      Preserves symbolic shape/bounds information across passes, improving early error detection \
      and robustness of shape-sensitive transformations.
    ],
    name: <V2>,
  ),

  // Edges (simple, robust)
  edge(<S>, <C1>, "-|>"),
  edge(<S>, <C2>, "-|>"),
  edge(<C1>, <Q1>, "-|>"),
  edge(<C2>, <Q2>, "-|>"),
  edge(<Q1>, <A1>, "-|>"),
  edge(<Q2>, <A2>, "-|>"),
  edge(<A1>, <V1>, "-|>"),
  edge(<A2>, <V2>, "-|>"),
)
