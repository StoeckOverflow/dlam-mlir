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
      Symbolic properties derived from runtime values (shapes, bounds, dimension relations) \
      matter for correctness and performance, but are not preserved as type-level invariants in MLIR.
    ],
    name: <S>,
  ),

  node(
    (0.5, 1),
    [
      *C1 -- Complication (Core MLIR)* \
      MLIR types are uniqued, structural descriptors and cannot depend on SSA values or region-local relationships; \
      invariants that rely on runtime values therefore cannot be carried in types across passes.
    ],
    name: <C1>,
  ),

  node(
    (2.5, 1),
    [
      *C2 -- Complication (Tensor/Shapes)* \
      Tensor shape/bounds constraints are represented operationally (SSA + attributes + analyses), \
      so passes must repeatedly re-derive and re-check legality conditions.
    ],
    name: <C2>,
  ),

  node(
    (0.5, 2),
    [
      *Q1 -- Question (MLIR Core)* \
      How can dependent types be represented at the type level in MLIR while respecting its SSA-based structure \
      and remaining stable under IR transformations?
    ],
    name: <Q1>,
  ),

  node(
    (2.5, 2),
    [
      *Q2 -- Question (Tensor Dialect)* \
      How can dependent types express and preserve tensor shape invariants relevant for correctness \
      and optimization across tensor transformations?
    ],
    name: <Q2>,
  ),

  node(
    (0.5, 3),
    [
      *A1 -- Answer (Core Approach)* \
      Prototype in ScaIR a restricted form of dependent typing (value-dependent types): \
      (1) parametric polymorphism via type variables; \
      (2) generalize to value parameters (SSA-valued type arguments) with scoping and rewrite rules under transformations.
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
      Clarifies minimal mechanisms and MLIR constraints required for transformation-stable types that depend on values.
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

  edge(<S>, <C1>, "-|>"),
  edge(<S>, <C2>, "-|>"),
  edge(<C1>, <Q1>, "-|>"),
  edge(<C2>, <Q2>, "-|>"),
  edge(<Q1>, <A1>, "-|>"),
  edge(<Q2>, <A2>, "-|>"),
  edge(<A1>, <V1>, "-|>"),
  edge(<A2>, <V2>, "-|>"),
)
