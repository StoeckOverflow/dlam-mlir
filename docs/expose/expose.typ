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

#set page(paper: "a4")
#diagram(
  node-stroke: luma(80%),
  edge-corner-radius: none,
  spacing: (5pt, 35pt),

  node(
    (0.7, 0),
    block(width: 7cm)[
      *S -- Situation* \
      Symbolic properties derived from runtime values (shapes, dimension relations)
      matter for correctness and performance and should ideally be preserved as stable invariants
      (e.g., at the type level), but are difficult to maintain across abstraction levels and MLIR transformations.
    ],
    name: <S>,
  ),

  node(
    (0, 1),
    block(width: 7cm)[
      *C1 -- Complication (Core MLIR)* \
      MLIR types are context-independent and cannot reference SSA values or region-local structure; \
      invariants that depend on SSA values therefore cannot be preserved at the type level across passes.
    ],
    name: <C1>,
  ),

  node(
    (1.5, 1),
    block(width: 7cm)[
      *C2 -- Complication (Tensor Level)* \
      Tensor shape constraints are represented operationally (SSA + attributes + analyses), \
      so passes must repeatedly re-derive and re-check legality conditions.
    ],
    name: <C2>,
  ),

  node(
    (0, 2),
    block(width: 7cm)[
      *Q1 -- Question (Core MLIR)* \
      How can value-dependent types be represented at the type level in MLIR while respecting its SSA-based structure \
      and remaining stable under IR transformations?
    ],
    name: <Q1>,
  ),

  node(
    (1.5, 2),
    block(width: 7cm)[
      *Q2 -- Question (Tensor Dialect)* \
      How can value-dependent types express and preserve tensor shape invariants relevant for correctness \
      and optimization across tensor transformations?
    ],
    name: <Q2>,
  ),

  node(
    (0, 3),
    block(width: 7cm)[
      *A1 -- Answer (MLIR Core)* \
      Prototype a restricted form of dependent typing (value-dependent types): \
      (1) parametric polymorphism via type variables; \
      (2) generalization to types referencing SSA values (program values), with explicit scoping and transformation-aware rewrite rules.
    ],
    name: <A1>,
  ),

  node(
    (1.5, 3),
    block(width: 7cm)[
      *A2 -- Answer (Tensor Dialect)* \
      Define value-indexed tensor/vector types (e.g., `tensor<%n x f32>`) \
      to carry symbolic shape parameters as stable type-level metadata for legality checks.
    ],
    name: <A2>,
  ),

  node(
    (0, 4),
    block(width: 7cm)[
      *V1 -- Value (MLIR Core)* \
      Clarifies minimal mechanisms and MLIR constraints required for transformation-stable types that depend on values.
    ],
    name: <V1>,
  ),

  node(
    (1.5, 4),
    block(width: 7cm)[
      *V2 -- Value (Tensor Dialect)* \
      Preserves symbolic shape information across passes, improving early error detection and robustness of shape-sensitive transformations.
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

Modern compiler pipelines rely on symbolic program properties that depend on runtime values, such as tensor shapes and algebraic relations between dimensions. These properties are central to both correctness and performance. For example, matrix multiplication is well-defined only when specific dimension equalities hold, while optimizations such as tiling, fusion, vectorization, and buffer reuse depend on symbolic constraints over tensor extents (i.e., dimension sizes).

This reliance on symbolic reasoning over program values and their relationships is already evident in modern compiler systems: tensor compilers such as TVM represent shapes and index expressions symbolically during scheduling and lowering, while systems like Halide explore parameterized schedule spaces whose legality and performance depend on symbolic shapes and extents @chen2018tvm, @halide_pldi13.

To support correctness checking and optimization, compiler infrastructures and high-level domain-specific languages must therefore preserve and reason about symbolic properties throughout the compilation pipeline. Representing shape information symbolically (e.g., at the type-level), rather than treating it solely as runtime data, enables earlier detection of errors and more reliable optimization decisions.

In modern compiler infrastructures such as MLIR, however, these symbolic properties must be represented across multiple abstraction levels and program transformations, which presents fundamental challenges.

= Complications (C1, C2)

== C1 -- Core MLIR Complication

In MLIR, types encode stable program invariants. Analyses consult them uniformly, transformations preserve them, and executions assume that they hold for all program instances. For symbolic properties relevant to correctness and optimization, such as shape relations or dimension constraints, types therefore provide the most effective representation, since they persist across transformations and function as global invariants.

MLIR’s core type system, however, is deliberately restricted to non-dependent types. These restrictions are intentional: they ensure that types remain simple, uniformly checkable, and stable under arbitrary IR transformations. Types are designed to be context-independent descriptors of compile-time properties and are kept separate from SSA values, control flow, and region structure.

This design choice is reflected in several core assumptions of the MLIR infrastructure:

- types do not reference SSA values or region-local program structure,
- type checking does not incorporate dominance or control-flow information,
- IR transformations such as replace-all-uses-with, operation cloning, and function inlining are defined to preserve types and therefore do not rewrite them,
- types are treated as closed descriptors that remain valid under arbitrary transformations.

These assumptions ensure that types function as global, transformation-stable invariants, but they also prevent types from depending on runtime values represented as SSA values or on relationships computed at the value level. As a result, dimension equalities and algebraic relations derived from SSA values cannot be expressed, preserved, or checked at the type level.

Although MLIR supports rich symbolic reasoning at the value level through SSA graphs, attributes, and dialect-specific analyses, this information is inherently operational and pass-local. Transformations such as cloning or inlining invalidate value-level reasoning, and symbolic constraints must be repeatedly reconstructed. Consequently, symbolic properties expressed at the value level cannot serve as stable invariants throughout the compilation pipeline.

== C2 -- Tensor Dialect and Application-Level Consequences

At the tensor-dialect level, shape constraints cannot be attached to tensor types as symbolic invariants in a way that remains stable across transformations. As a result, relationships between tensor dimensions cannot be expressed or enforced uniformly at the type level.

Tensor dimensions that are computed dynamically, for example through shape arithmetic or index calculations, must be represented as SSA values or attributes rather than as symbolic components of tensor types. As a result, MLIR tensor and vector types can encode individual dimensions as static integers or dynamic placeholders, but cannot express relationships between dimensions or global constraints that must hold simultaneously.

In particular:

- tensor and vector types cannot encode structural relationships between dimensions, such as equality, sums, divisibility, or alignment,
- shape consistency conditions and dimensional legality constraints cannot be enforced at the type level,
- legality conditions for tensor transformations (e.g., fusion, tiling, or vectorization) cannot be expressed as type-level invariants.

As a consequence, tensor-related compiler passes, including tiling, fusion, bufferization, and canonicalization, must repeatedly reconstruct symbolic shape constraints from SSA graphs, attributes, and pass-local analyses. These constraints remain operational, transient, and pass-specific, and transformations invalidate them. This design increases implementation complexity, requires repeated re-validation of correctness conditions, and reduces the robustness of shape-sensitive optimizations.

Moreover, this approach makes it difficult for MLIR to preserve the shape-level correctness guarantees provided by shape-indexed type systems in high-level DSLs such as Rise @LuckeSS21, where array dimensions are tracked symbolically at the type level. It also precludes the direct expression of value-indexed array or tensor abstractions (e.g. Vector(n) as studied in @pierce2024advanced) and shape-preserving function types, where shape consistency is enforced by construction rather than through repeated dynamic checks.

= Research Questions (Q1, Q2)

== Q1 -- MLIR Core

How can value-dependent types be represented at the type level in MLIR while respecting its SSA-based structure and remaining stable under IR transformations?

== Q2 -- Tensor Dialect

How can value-dependent types be used to express and preserve tensor shape invariants that are relevant for correctness and optimization across tensor transformations?

= Answers (A1, A2) and Approach

== A1 -- Core MLIR Contribution: Value-Dependent Types

To address the absence of stable type-level representations for symbolic program properties in MLIR, this thesis investigates whether and how a form of dependent types can be supported in an SSA-based intermediate representation without violating transformation stability or core MLIR invariants.

Instead of pursuing full dependent typing, the thesis focuses on a restricted form of dependency, namely value-dependent types, in which types may depend on program values under explicitly defined scoping and transformation rules. Rather than introducing refinement types, logical predicates, or proof obligations, this work focuses on preserving symbolic value dependencies as stable type-level invariants. This approach preserves symbolic expressiveness while avoiding the complexity of fully general dependent type theories, as explored in prior work on value-dependent typing and indexed types @paszke2021gettingpointindexsets, @secureDistributedProgrammingValueDependentTypes.

To structure the investigation, the thesis distinguishes between two kinds of parameters. In parametric polymorphism, types are abstracted over type parameters, which range over types and are resolved purely at the type level, even when represented using SSA values. Value-dependent typing generalizes this notion to value parameters, which range over computed program values represented explicitly as SSA values. This distinction motivates a two-stage approach: first establishing parametric polymorphism as a baseline, and then generalizing the same mechanisms to value-dependent types.

To explore this design space in a controlled manner, the thesis uses ScaIR as a prototyping platform. ScaIR is a Scala-based MLIR implementation that provides typed algebraic data types for IR construction, enabling rapid experimentation with type-system designs @edin_dal_scair. Using ScaIR allows conceptual questions about type-level abstraction, scoping, and substitution to be studied independently of MLIR’s C++ implementation constraints.

=== Stage 1: Parametric Polymorphism via Type Parameters

In the first stage, the thesis implements parametric polymorphism in ScaIR to establish a baseline for type-level abstraction and substitution. Two representations are explored, both corresponding to universally quantified types of the form:

$ #sym.Lambda (T: "Type"). #sym.lambda (x:T). x : forall sigma. sigma -> sigma $

Here, $T$ is a type parameter introduced by a type-level abstraction and $sigma$ denotes a bound type variable referring to that parameter, represented in de Bruijn form. The use of de Bruijn indices reflects that the variable is identified by its binding position rather than by name, making scoping and substitution explicit and avoiding reliance on named references at this stage.

The two representations differ only in how references to the type parameter are represented: either positionally, using de Bruijn indices, or explicitly, using SSA-valued references embedded in types.

The first representation encodes references to type parameters using de Bruijn-indexed type variables. Type abstraction introduces a type parameter, while references to that parameter are represented positionally via de Bruijn indices. This encoding relies exclusively on MLIR-compatible type-level mechanisms: types abstract over parameters but do not reference SSA values. As a result, abstraction, substitution, and scoping are handled entirely within the type system, exposing the complexity of implementing these mechanisms without relying on IR-level structure.

The second representation also abstracts over type parameters, but represents references to those parameters using SSA values embedded in types. Instead of de Bruijn-indexed type variables, types refer to parameters directly via SSA-values. Although these parameters still range over types rather than program values, their SSA-based representation already requires several structural mechanisms later needed for value-dependent typing: embedding SSA references into types, enforcing dominance and scoping conditions for well-formedness, and rewriting type-level references during IR transformations.

Comparing these two encodings serves a methodological purpose. The de Bruijn-based encoding preserves MLIR’s current assumption that types are context-independent and self-contained, meaning that their interpretation does not depend on surrounding IR context, SSA values, or dominance relations. In contrast, the SSA-based encoding relaxes this assumption by allowing types to reference program entities under explicit scoping and dominance constraints.

At this stage, the implementation supports:

- type variables represented via de Bruijn indices,
- type variables represented via SSA-valued references embedded structurally in types (corresponding to type parameters),
- universally quantified function types,
- type-level abstraction, substitution, and instantiation,
- basic dominance and scoping checks to ensure structural well-formedness of SSA references in types,
- compatibility with core MLIR transformations.

At this stage, dominance and scoping conditions are enforced solely to ensure structural well-formedness of SSA values used as type-level binders. These SSA values do not denote computed program values and carry no execution semantics. They function purely as symbolic references to type parameters. Consequently, their validity depends only on syntactic availability and scoping, not on lifetime, control flow, or region semantics.

This distinction becomes crucial in the next stage, where SSA values embedded in types denote actual program values and therefore introduce semantic validity requirements, namely that such values must dominate all type use sites and remain valid with respect to region structure and lifetime across transformations.

=== Stage 2: Value-Dependent Types via Value Parameters

Stage 2 generalizes the mechanisms established in Stage 1 from type parameters to value parameters, which range over program values represented as SSA values in the IR. This generalization enables types whose structure depends on the results of computation and enables types of the form:

$ #sym.Lambda (N: "Nat"). #sym.lambda (x: N."f32"). x : #sym.Pi (N:"Nat"). N."f32" -> N."f32" $

This example is schematic and serves to illustrate value-dependent types. The underlying mechanism is independent of tensors or shape-specific abstractions.

Rather than introducing fundamentally new abstraction or substitution mechanisms, this stage reuses the representation, scoping, and substitution machinery developed for parametric polymorphism and extends it to value parameters. Value-dependent types are introduced as a core IR mechanism, independent of any particular dialect or application domain.

While SSA references already appear in Stage 1, they function there purely as binders for type parameters and are checked only for structural well-formedness. In Stage 2, SSA values embedded in types denote computed program values, so dominance, lifetime, and region structure determine whether a value-dependent type is valid at its use sites. As a result, type well-formedness in Stage 2 is no longer purely structural but depends on the semantic validity of referenced SSA values within the IR.

As a consequence, value-dependent types require explicit well-formedness and preservation conditions that are enforced uniformly across the IR, including:

- dominance requirements ensuring that SSA values used in types are available at all type use sites,
- region and lifetime constraints governing the validity of value parameters,
- transformation-aware rewrite rules that preserve the meaning of value parameters under IR transformations.

This stage addresses the core technical question of the thesis: how a restricted form of dependent typing can be represented in an SSA-based IR while remaining well-formed and stable under transformations.

== A2 -- Application-Level Contribution: Value-Indexed Tensor Types

Having established value-dependent types as a core, transformation-stable mechanism, the thesis next applies this machinery to a concrete and practically important domain: tensor shapes.

Tensor and vector types are extended with value-dependent parameters that index shapes using SSA values:

```mlir
tensor<%n x f32>
vector<%m x i32>
```

In standard MLIR, shape information resides at the value level (e.g., as results of `tensor.dim` or shape-dialect operations) and analyses must reconstruct shape relationships after each transformation. By embedding symbolic parameters directly in types, these parameters become pass-stable metadata, provided that dominance-aware well-formedness conditions and transformation-aware rewrite rules are defined and enforced.

This approach enables:

- tensor and vector types indexed by SSA values, allowing symbolic shape parameters to be represented directly at the type level,
- preservation of symbolic shape relationships across IR transformations as transformation-stable type-level invariants,
- expression of legality conditions (e.g., shape compatibility, tiling preconditions) as type-level invariants rather than pass-local checks.

The work intentionally avoids introducing a full equational theory or normalization framework for shape expressions. Instead, shape parameters are treated symbolically, with equality determined syntactically or through explicit constraints. This restriction keeps the scope focused on feasibility and transformation stability.

Case studies include:

- lowering Rise-style shape-indexed types into value-indexed MLIR tensor types,
- encoding value-indexed tensor types inspired by value-indexed array abstractions such as `Vector(n)` (@pierce2024advanced),
- evaluating stability under standard MLIR transformations (e.g., replace-all-uses-with, common subexpression elimination, dead code elimination, and function inlining).

= Values (V1, V2)

== V1 -- Value of Value-Dependent Types in MLIR

Integrating value-dependent types into MLIR, starting from parametric polymorphism and generalizing to value parameters, provides a principled foundation for representing symbolic program properties as transformation-stable type-level invariants.

This contribution:

- establishes a clear conceptual progression from parametric polymorphism to value-dependent typing,
- identifies the minimal mechanisms required for type-level parameters in an SSA-based IR,
- clarifies which MLIR invariants constrain or permit value dependence in types,
- demonstrates how symbolic correctness properties can persist across transformations.

== V2 -- Value of Value-Indexed Tensor Types

Applying value-dependent types to tensor abstractions shows how symbolic shape information can be preserved as stable invariants throughout the MLIR pipeline.

Value-indexed tensor types enable:

- preservation of symbolic shape relations as transformation-stable type-level invariants,
- explicit representation of shape-related correctness assumptions at the type level,
- enabling robust and uniform legality checks for tensor transformations,
- closer alignment between MLIR and shape-indexed DSLs such as Rise.

Rather than introducing a full dependent type system or symbolic solver, this work demonstrates that a restricted, symbolic form of value dependence already yields substantial benefits for correctness and optimization.

#bibliography("references.bib")
