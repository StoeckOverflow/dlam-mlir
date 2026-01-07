
= Work Plan

== Phase 1 — Parametric Polymorphism via Type-Level Parameters

This phase studies parametric polymorphism as a precursor to value-dependent typing.

- Study parametric polymorphism of the form
  $ #sym.Lambda (T: "Type"). #sym.lambda (x:T). x : forall sigma. sigma -> sigma $
  and its role as a minimal form of type-level abstraction.

- Implement two representations of parametric polymorphism in ScaIR:
  - a baseline encoding using de Bruijn indices at the type level,
  - an alternative encoding in which type variables are represented explicitly via SSA values embedded in types (still ranging over types).

- Compare the two encodings with respect to:
  - complexity of abstraction and substitution,
  - interaction with core IR transformations,
  - required scoping and purely structural dominance conditions.

- Identify and document limitations of parametric polymorphism without value dependence:
  - verbosity and fragility of de Bruijn-based encodings,
  - lack of connection between types and runtime-computed values,
  - inability to express shape-dependent program properties.

This phase establishes parametric polymorphism as a strict subset of value-dependent typing and provides a concrete baseline for subsequent generalization.

== Phase 2 — Value-Dependent Types

This phase generalizes parametric polymorphism to value-dependent types and investigates how types may depend on program values while remaining well-formed and stable under transformations.

- Generalize type-level parameters from types to values (e.g. natural numbers represented as SSA values) of the form:
  $ #sym.Lambda (N: "Nat"). #sym.lambda (x:N."f32"). x : #sym.Pi (N:"Nat").N."f32" -> N."f32" $
- Define precise well-formedness conditions for types that reference SSA values:
  - dominance of SSA values used in types,
  - region-scoping constraints,
  - lifetime and visibility of value-level parameters.
Define substitution and rewriting behavior for SSA values appearing in types, aligned with IR transformations.
- Analyze failure modes and boundary cases:
  - SSA values going out of scope,
  - interaction with cloning and inlining,
  - conditions under which type rewriting becomes necessary.

- Implement value-dependent types in ScaIR using a structured representation that embeds SSA values within types.
- Support symbolic value parameters (e.g. natural numbers).
- Extend parser and printer support for SSA-valued type parameters, for example:

```mlir
fun<!dlam.tvar<%U> -> !dlam.tvar<%U>>
```

- Model interaction with IR transformations:
  - replacement of value parameters,
  - behavior under cloning, inlining, and region movement,
  - treating SSA values in types as real dependencies for dead code elimination.
- Evaluate consistency under canonicalization, common subexpression elimination, and related passes.
- Use ScaIR as a reference environment to:
  - validate the design independently of MLIR’s C++ implementation constraints,
  - identify which MLIR invariants are essential for value-dependent typing,
  - prepare a possible MLIR-native realization as optional future work.

This phase addresses the core technical question of the thesis: how value-dependent types can be represented in an SSA-based IR while remaining transformation-stable.

== Phase 3 — Tensor and Shape Case Study

This phase applies value-dependent types to tensor abstractions.

- Design tensor and vector types indexed by SSA values:
  ```mlir
  tensor<%n x f32>
  vector<%m x i32>
  ```
- Express shape compatibility and tiling preconditions as type-level invariants,
- Encode legality conditions for tensor transformations (fusion, tiling, vectorization) at the type level,
- Evaluate interaction with standard tensor and bufferization passes.

== Phase 4 — Evaluation

The evaluation focuses on feasibility, stability, and expressiveness rather than runtime performance.

=== Correctness and Static Invariants

- Demonstrate that value-dependent types detect shape inconsistencies not enforced by standard MLIR types.
=== Expressiveness

- Compare the fidelity of lowering Rise-style shape-indexed types (e.g. N.M.f32) to standard MLIR encodings.
- Encode ATTAPL-style value-indexed vectors and assess expressiveness gains over standard MLIR types.
- Contrast the proposed approach with:
  - the de Bruijn-based baseline,
  - systems such as MimIR.

=== Transformation Stability

- Stress-test value-dependent types under:
  - RAUW, cloning, inlining, and region movement,
  - common subexpression elimination, dead code elimination, canonicalization, and tensor transformations.
- Assess whether SSA-valued type parameters remain well-scoped and consistent.

=== Invariant Robustness

- Identify MLIR invariants that must be preserved (e.g. dominance).
- Identify invariants that can be relaxed or adapted (e.g. type uniquing).
- Characterize which aspects of MLIR fundamentally limit value-dependent typing.

=== Compile-Time Overhead

- Estimate compile-time overhead introduced by value-dependent types (parsing, printing, verification, type comparison).
- Compare pass execution time against vanilla MLIR on identical inputs.
- Assess scalability with respect to the number of SSA-valued type parameters.

#bibliography("references.bib")
