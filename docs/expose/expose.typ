// =========================================================
// Master Thesis Expose
// =========================================================
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

// =========================================================
// Title Page
// =========================================================
#align(horizon + center)[

  #text(size: 24pt, weight: "bold", [Master Thesis Expose])

  #text(size: 16pt, weight: "semibold", [Integrating Value-Dependent Types into MLIR:])

  #text(size: 16pt, weight: "semibold", [From Type Variables to Value-Indexed Tensor Shapes])

  #text(size: 12pt, [Dominic Stöcker])

  #text(size: 12pt, weight: "semibold", [Supervisor:])
  #text(size: 12pt, [Prof. Michel Steuwer])

  #text(size: 12pt, weight: "semibold", [Chair:])
  #text(size: 12pt, [ComPL - Compilers and Programming Languages])

  #text(size: 12pt, [#datetime.today().display()])
]
// =========================================================
// SCQAV Diagram Page
// =========================================================
#pagebreak()

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

  edge(<S>, <C1>, "-|>"),
  edge(<S>, <C2>, "-|>"),
  edge(<C1>, <Q1>, "-|>"),
  edge(<C2>, <Q2>, "-|>"),
  edge(<Q1>, <A1>, "-|>"),
  edge(<Q2>, <A2>, "-|>"),
  edge(<A1>, <V1>, "-|>"),
  edge(<A2>, <V2>, "-|>"),
)

// =========================================================
// Exposé Text
// =========================================================
#pagebreak()
#set page(
  paper: "a4",
  margin: (x: 2.0cm, y: 2.0cm),
)
#set align(left)
#set text(size: 10pt)
#set par(justify: true)


= Situation (S)

Modern compiler pipelines increasingly rely on symbolic, value-dependent program properties such as tensor shapes, index bounds, and algebraic relations between dimensions. These properties are central to both correctness and performance. For example, the validity of tensor operations such as matrix multiplication depends on equality constraints between dimensions, while optimizations such as tiling, fusion, vectorization, and buffer reuse rely on symbolic constraints over tensor extents.

Across compiler infrastructures and high-level domain-specific languages, preserving and reasoning about such symbolic properties throughout the compilation pipeline is therefore essential. In particular, treating shape and index information symbolically, rather than purely as runtime values, enables earlier validation of program correctness and more robust optimization decisions.

In modern compiler infrastructures such as MLIR, these symbolic properties must be represented and preserved across multiple abstraction levels and pogram transformations.

= Complications (C1, C2)

== C1 -- Core MLIR Complication

In compiler infrastructures, types are intended to encode stable program invariants: they are preserved across transformations, consulted uniformly by analyses, and assumed to hold for all executions of a program fragment. Symbolic properties that are relevant for correctness and optimization—such as shape relations or index bounds—are therefore most effective when represented at the type level rather than reconstructed operationally from program structure.

Despite this role of types, MLIR’s core type system does not provide a mechanism to represent value-dependent information as stable, type-level invariants.

In MLIR, types are uniqued within an `MLIRContext` and are defined solely by context-independent structural parameters. As a consequence, types cannot depend on SSA values, dominance relations, or region-local program structure. Type equality is determined globally by structural equivalence under uniquing, and type checking does not incorporate information about control flow or value provenance.

Concretely, MLIR’s core infrastructure assumes that:

- types are independent of SSA values and control-flow structure,
- type equality is determined by global structural equivalence,
- dominance and region scoping are not considered during type checking,
- IR transformations such as RAUW, cloning, and inlining do not rewrite types,
- parsing and printing treat types as closed, context-free descriptors.

As a result, symbolic constraints that arise from runtime values—such as algebraic relations between tensor dimensions, index bounds, or equality conditions—cannot be expressed, preserved, or checked at the type level. While MLIR supports limited forms of parametricity at the operation level via attributes and generic mechanisms, the core type system has no notion of type variables or value-dependent type parameters.

Instead, symbolic information must be represented at the value level, where it is inherently operational: it depends on SSA graphs, control flow, and local analyses, and must be re-derived after transformations such as cloning, inlining, or rewriting. Consequently, symbolic constraints expressed solely at the value level lack persistence and cannot function as global invariants throughout the compilation pipeline.

== C2 -- Tensor Dialect and Application-Level Consequences

At the tensor-dialect level, the absence of value-dependent types means that shape-related correctness and performance constraints cannot be represented as stable, type-level invariants.

Tensor dimensions that are computed dynamically—such as the results of shape arithmetic, loop bounds, or index calculations—must be represented as SSA values or attributes rather than as symbolic components of tensor types. Consequently, tensor and vector types in MLIR can describe only individual dimensions as static integers or dynamic placeholders, but cannot encode relationships between dimensions or constraints that must hold globally.

In particular:

- tensor and vector types cannot express symbolic relationships between dimensions (e.g. equality, sums, divisibility, or alignment constraints),
- index bounds and shape consistency conditions cannot be enforced or checked at the type level,
- legality conditions for tensor transformations (such as fusion, tiling, or vectorization) cannot be encoded as type-level invariants.

As a result, tensor-related compiler passes, including tiling, fusion, bufferization, and canonicalization, must repeatedly reconstruct symbolic shape constraints from SSA graphs, attributes, and local analyses. These constraints are derived operationally, are pass-specific, and are not preserved as global invariants across transformations. This increases implementation complexity, requires repeated re-validation of correctness conditions, and limits the robustness of shape-sensitive optimizations.

Moreover, this design prevents MLIR from preserving the shape-related correctness guarantees provided by shape-indexed type systems in high-level DSLs such as Rise, where array dimensions are tracked symbolically at the type level. It also precludes the direct expression of value-dependent typing patterns—such as value-indexed tensor and index types (e.g. `Vector(n)`, `Idx(n)`) or shape-preserving function types—as studied in type-theoretic systems like ATTAPL, where bounds safety and shape consistency are enforced by construction rather than by repeated dynamic checks (see @pierce2024advanced, ch. 2, 9).

= Research Questions (Q1, Q2)

== Q1 -- MLIR Core

How can value-dependent information be represented at the type level in MLIR while respecting its SSA-based structure and remaining stable under IR transformations?

== Q2 -- Tensor Dialect

How can value-dependent types be used to express and preserve tensor shape invariants that are relevant for correctness and optimization across tensor transformations?

= Answers (A1, A2) and Approach

== A1 -- Core MLIR Contribution: Value-Dependent Types via Type-Level Parameters

To address the lack of stable representations for symbolic program properties in MLIR, this thesis investigates how value-dependent information can be reflected at the type level while remaining compatible with MLIR’s SSA-based architecture and transformation structure.

Rather than addressing symbolic tensor shapes directly, we proceed incrementally. The key observation is that value-dependent typing is a principled generalization of type-level parametricity. Both rely on the same underlying mechanism—type-level abstraction and substitution, but differ in the domain over which parameters range. We therefore structure the investigation in two steps: first, parametric polymorphism via type variables; second, generalization to value-dependent type parameters.

This decomposition isolates conceptual and engineering challenges and allows the mechanisms required for value-dependence to be introduced in a controlled and well-understood manner.

=== Step 1: Parametric Polymorphism via Type-Level Parameters

This step studies parametric polymorphism as a conceptual precursor to value-dependent typing and isolates the challenges of type-level abstraction before introducing value-dependent parameters.

Concretely, we implement two representations of parametric polymorphism in ScaIR, both corresponding to universally quantified types of the form:

$ #sym.Lambda T: "Type". #sym.lambda x:T. x $

First, we encode type variables purely at the type level using de Bruijn indices (e.g. `!dlam.bvar<0>`), relying only on mechanisms compatible with MLIR’s existing type model. In this encoding, types may abstract over type parameters, but do not depend on SSA values. This implementation demonstrates what can be expressed without introducing value-dependence into the type system, and exposes the complexity of representing abstraction, substitution, and scoping purely at the type level.

Second, we implement an alternative representation in which type variables are represented explicitly via SSA values embedded in types. Although this still corresponds to parametric polymorphism, since parameters range over types rather than values, it already requires the same core mechanisms needed for value-dependent typing: embedding SSA references into types, tracking dominance and scope, and rewriting type-level references under transformations.

Comparing these two encodings serves a methodological purpose. The de Bruijn-based encoding establishes a baseline that remains compatible with MLIR’s current assumptions, while the SSA-based encoding illustrates how much simpler and more uniform abstraction becomes once types are allowed to reference SSA values directly.

Concretely, the parametric polymorphism stage supports:

- type variables represented either via de Bruijn indices or via SSA values embedded in types,
- universally quantified (parametric) function types,
- type-level substitution and instantiation,
- full compatibility with MLIR transformations (RAUW, cloning, inlining).

At this stage, SSA values appearing in types represent type parameters, not runtime-computed values. Consequently, this phase captures parametric polymorphism rather than full value-dependent typing.

This step isolates challenges related only to type variables and polymorphism, and establishes parametric polymorphism as a strict subset of value-dependent typing. It provides a concrete baseline against which the subsequent generalization to value-dependent parameters, such as natural numbers indexing tensor shapes, can be evaluated.

=== Step 2: Value-Dependent Types in ScaIR

Building on parametric polymorphism, we then generalize type-level parameters from types to values, such as natural numbers. This enables types of the form:

$ #sym.Lambda N: "Nat". #sym.lambda x:N."f32". x $

To explore this generalization safely, we implement a small dependent type calculus, `Dlam`, in ScaIR. ScaIR provides typed algebraic data types (ADTs) for IR construction, allowing us to model type-level structure explicitly without being constrained by MLIR’s C++ type uniquing infrastructure (@edin_dal_scair).

In this stage, ScaIR is extended to support:

- type expressions parameterized by SSA values,
- embedding SSA value references as structured components of types,
- substitution of type-level value parameters,
- dominance- and region-aware type well-formedness checks,
- parser and printer support for SSA-valued type parameters.

This step addresses the core technical question of the thesis: how value-dependent information can be represented at the type level while interacting correctly with SSA scoping and transformations.

An MLIR C++ prototype reflecting these ideas is considered optional future work and serves primarily to validate the feasibility of transferring the ScaIR design into MLIR’s infrastructure.

== A2 -- Application-Level Contribution: Value-Indexed Tensor Types

Using the mechanisms developed in A1, we study how value-dependent types can be applied to tensor abstractions.

Using value-dependent type parameters, we design tensor and vector types whose shapes are indexed by SSA values:

```mlir
tensor<%n x f32>
vector<%m x i32>
```

In standard MLIR, shape information is represented at the value level (e.g., results of `tensor.dim` or shape-dialect operations) and must be re-established by dedicated analysis passes that reconstruct shape relationships from the rewritten SSA graph after each transformation. //must be re-established by analyses after transformations.
By placing symbolic parameters in types, the intent is to make these parameters available as pass-stable metadata, rather than being re-derived operationally, provided that well-formedness (dominance/region scoping) and rewrite rules for transformations (e.g., RAUW, cloning, inlining) are defined and enforced.

This enables the expression of:

- tensor and vector types indexed by SSA values,
- value-indexed index types for bounds-safe access (e.g. `Idx(n)`),
- expressing legality conditions (e.g. shape compatibility, tiling constraints) as type-level invariants rather than pass-local checks.

Importantly, this work does not aim to introduce a full equational theory or normalization framework for shape expressions. Instead, shape parameters are treated symbolically, with equality determined syntactically or by explicit constraints, keeping the scope intentionally limited.

Case studies include:

- lowering Rise-style shape-indexed types into value-indexed MLIR tensor types,
- encoding ATTAPL-style value-indexed tensor and index types (e.g. `Vector(n)`, `Idx(n)`),
- evaluating the stability of such types under MLIR transformations (RAUW, CSE, DCE, LICM, inlining).

= Values (V1, V2)

== V1 -- Value of Value-Dependent Types in MLIR

Integrating value-dependent types into MLIR—starting from parametric polymorphism via type variables and generalizing to value parameters—provides a principled foundation for representing symbolic program properties as stable, type-level invariants.

In particular, this contribution:

- establishes a clear conceptual progression from parametric polymorphism to value-dependent typing,
- identifies the minimal mechanisms required to support type-level parameters in an SSA-based IR,
- clarifies which core MLIR invariants constrain or permit type-level dependence on values,
- demonstrates how symbolic properties relevant for correctness can be expressed as transformation-invariant metadata.

== V2 -- Value of Value-Indexed Tensor Types

Applying value-dependent types to tensor abstractions shows how symbolic shape information can be preserved as stable invariants throughout the MLIR compilation pipeline.

Concretely, value-indexed tensor types enable:

- preservation of symbolic shape relationships across IR transformations,
- static enforcement of shape-related correctness conditions,
- more robust and explicit legality checks for tensor transformations such as fusion and tiling,
- closer alignment between MLIR and shape-indexed DSLs such as Rise.

Rather than introducing a full dependent type system or a symbolic solver for shapes, this work demonstrates that a carefully restricted form of value-dependence—treating shape parameters symbolically at the type level—already yields significant benefits for correctness and optimization.


== Scope and deliverables.

The thesis delivers (i) a ScaIR prototype that supports SSA-valued type parameters with well-formedness and rewrite behavior under core transformations, and (ii) a tensor-focused case study with value-indexed shapes and index/bounds types. The scope intentionally excludes a full dependent type theory (e.g., proof automation or rich normalization/equality solving) and instead evaluates feasibility and robustness with respect to MLIR-style transformations and shape-sensitive legality checks.

= Related Work

== Rise

Rise is a functional, pattern-based intermediate representation built on typed combinators such as `map` and `reduce`, operating over multi-dimensional arrays. Its type system is parametric over shape, allowing array dimensions to be tracked symbolically and enabling rewrite-based optimizations whose correctness depends on shape invariants (@LuckeSS21).

Rise demonstrates the value of expressing shape information at the type level. However, in its MLIR embedding, these shape-indexed types are not preserved directly. Shape information is lowered into values and attributes, and symbolic relationships between dimensions are no longer represented as type-level invariants. As a result, MLIR cannot retain the same shape-level guarantees that exist in Rise’s source-level type system.

== MimIR

MimIR is a higher-order intermediate representation based on the Calculus of Constructions, in which types are expressions that may depend on values. Its type system supports polymorphism, dependent types, and normalization of type- and value-level expressions, enabling strong correctness guarantees and optimization via type-level computation (@leissa2025mimir).

MimIR demonstrates that dependent typing can be highly expressive in a compiler IR. However, it is structurally very different from MLIR: it does not use SSA form, does not impose dominance or region structure, and does not employ context-based type uniquing.

== MLIR Shape Dialect

MLIR provides a shape inference framework and the `shape` dialect, which allow operations to specify how output shapes are computed from input shapes via reference implementations (@mlir_shape_inference; @mlir_shape_dialect_lowering).

However, shape reasoning in MLIR is deliberately confined to the value level. Shape functions operate over SSA values and attributes, and the results of shape computation are not reflected in the type system. Tensor types may contain static dimensions or dynamic placeholders, but they cannot encode symbolic relationships between dimensions or enforce shape invariants at the type level.

As a consequence, MLIR cannot attach type-level legality preconditions (e.g., required equalities/divisibility constraints) to operations in a way that is preserved and checked uniformly across the pipeline.

#bibliography("references.bib")
