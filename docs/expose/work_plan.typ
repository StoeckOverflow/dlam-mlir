
= Work Plan

== Phase 1 — Parametric Polymorphism without Value Dependence

- Study parametric polymorphism of the form $Λ T. T → T$.
- Implement two representations of parametric polymorphism in ScaIR:
  - a baseline encoding using de Bruijn indices,
  - an alternative encoding where type variables are represented via SSA values embedded in types (still ranging over types).
- Compare the two encodings with respect to:
  - complexity of abstraction and substitution,
  - interaction with RAUW, cloning, and inlining,
  - required scoping and dominance checks.
- Document limitations of parametric polymorphism without value dependence:
  - verbosity and fragility of de Bruijn-based encodings,
  - lack of connection between types and runtime-computed values,
  - inability to express shape- or index-dependent properties.

== Phase 2 — Introducing Value Parameters into Types

- Extend types to reference SSA values explicitly as parameters.
- Define precise well-formedness conditions:
  - dominance of SSA values used in types,
  - region scoping of type-level references.
- Define substitution behavior for SSA values appearing in types, mirroring RAUW-like transformations.
- Investigate failure cases:
  - when an SSA value goes out of scope,
  - how inlining affects type-level value references,
  - when type rewriting becomes necessary.

== Phase 3 — Value-Dependent Types in ScaIR

- Implement value-dependent types in ScaIR via a `DepTypeAttr`:
  - structured ADTs embedding SSA value references,
  - symbolic value parameters (e.g. natural numbers),
  - explicit representation of dependencies.
- Define well-formedness conditions:
  - dominance of SSA values used in types,
  - region-scoping constraints,
  - lifetime and liveness of type-level value parameters.
- Extend parser and printer to support SSA-valued type parameters:

  ```mlir
  fun<!dlam.tvar<%U> -> !dlam.tvar<%U>>
  tensor<%n x f32>
  ```

- Define and evaluate substitution behavior for SSA values appearing in types:
  - RAUW-like replacement of value parameters,
  - updates under cloning and inlining,
  - interaction with region movement.
- Model transformation interactions:
  - treating SSA values in types as real dependencies for DCE,
  - ensuring consistency under canonicalization and CSE,
  - identifying minimal invariants required for correctness.
- Use ScaIR as a reference environment to:
  - validate the design independently of MLIR C++ constraints,
  - identify which MLIR invariants are essential,
  - prepare a possible MLIR-native realization.

== Phase 4 — Tensor and Shape Case Study

- Design tensor and vector types indexed by SSA values:

```mlir
tensor<%n x f32>
vector<%m x i32>
```

- Introduce value-indexed index and bounds types.
- Express shape compatibility and bounds conditions as type-level invariants.
- Encode legality constraints for tensor transformations (fusion, tiling, vectorization) at the type level.
- Evaluate interaction with standard tensor passes.

== Phase 5 — Evaluation

The evaluation focuses on feasibility, stability, and expressiveness rather than runtime performance.

- *Correctness & Static Invariants*
  - demonstrate that value-dependent types detect shape and bounds errors not enforced by standard MLIR types,
  - show how value-indexed index and tensor types prevent invalid accesses and shape mismatches by construction.

- *Expressiveness Comparisons*
  - compare the fidelity of lowering Rise types (`N.M.f32`) against existing MLIR encodings,
  - encode ATTAPL-style value-indexed vectors and indices and evaluate what expressiveness is gained over standard MLIR types (see @pierce2024advanced, ch. 2, 9),
  - contrast the proposed approach with the baseline de Bruijn encoding and with systems such as MimIR.

- *Transformation Stability (Pass Robustness)*
  - stress-test value-dependent types under RAUW, cloning, inlining, region movement,
  - evaluate behavior under CSE, DCE, LICM, canonicalization, and tensor transformations,
  - assess whether SSA-valued type parameters remain well-scoped and consistent across transformations.

- *Invariant Robustness Analysis*
  - identify MLIR invariants that must be preserved (e.g. dominance),
  - identify invariants that can be relaxed or adapted (e.g. type uniquing),
  - characterize which aspects of MLIR fundamentally limit value-dependent typing.

- *Compile-Time Overhead*
  - measure overhead introduced by value-dependent types (parsing, printing, verification, type comparison),
  - compare pass execution time against vanilla MLIR on identical inputs,
  - assess scalability with respect to the number of SSA-valued type parameters.

= Expected Contributions

- *Theoretical Contributions*
  - systematic analysis of how type-level parametricity generalizes to value-dependent types in an SSA-based IR,
  - characterization of MLIR invariants that constrain or enable value-dependent typing (transformation stability),
  - delineation of the boundary between parametric polymorphism (type variables) and value-indexed tensor types.

- *Engineering Contributions*
  - a ScaIR-based prototype supporting value-dependent types,
  - a concrete model of how type-level parameters interact with SSA scoping, substitution, and IR transformations,
  - a tensor-focused case study demonstrating value-indexed shapes and index bounds as stable, type-level invariants.

- *Impact*
  - more precise and robust handling of symbolic shape information in MLIR-based pipelines,
  - improved preservation of shape-indexed DSL invariants during lowering to MLIR,
  - insight into how MLIR’s type system could evolve to support symbolic, value-dependent properties without abandoning SSA.

#bibliography("references.bib")
