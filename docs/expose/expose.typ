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
      Symbolic properties derived from runtime values (shapes, bounds, dimension relations)
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
      Tensor shape/bounds constraints are represented operationally (SSA + attributes + analyses), \
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
      (2) generalize to value parameters (SSA-valued type arguments) with scoping and rewrite rules under transformations.
    ],
    name: <A1>,
  ),

  node(
    (1.5, 3),
    block(width: 7cm)[
      *A2 -- Answer (Tensor Dialect)* \
      Define value-indexed tensor/vector and index types (e.g., `tensor<%n x f32>`, `Idx(%n)`) \
      to carry symbolic shape/bounds parameters as stable type-level metadata for legality checks.
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

Modern compiler pipelines rely on symbolic program properties that depend on runtime values, such as tensor shapes, index bounds, and algebraic relations between dimensions. These properties are central to both correctness and performance. For example, matrix multiplication is well-defined only when specific dimension equalities hold, while optimizations such as tiling, fusion, vectorization, and buffer reuse depend on symbolic constraints over tensor extents.

This reliance on symbolic reasoning over program values and their relationships is already evident in modern compiler systems: tensor compilers such as TVM represent shapes and index expressions symbolically during scheduling and lowering, while systems like Halide explore parameterized schedule spaces whose legality and performance depend on symbolic bounds and extents @chen2018tvm, @halide_pldi13.

To support correctness checking and optimization, compiler infrastructures and high-level domain-specific languages must therefore preserve and reason about symbolic properties throughout the compilation pipeline. Representing shape and index information symbolically, rather than treating it solely as runtime data, enables earlier detection of errors and more reliable optimization decisions.

In modern compiler infrastructures such as MLIR, however, these symbolic properties must be represented across multiple abstraction levels and program transformations, which presents fundamental challenges.

= Complications (C1, C2)

== C1 -- Core MLIR Complication

In MLIR, types encode stable program invariants. Analyses consult them uniformly, transformations preserve them, and executions assume that they hold for all program instances. For symbolic properties relevant to correctness and optimization, such as shape relations or index bounds, types therefore provide the most effective representation, since they persist across transformations and function as global invariants.

MLIR’s core type system, however, is deliberately restricted to non-dependent types. These restrictions are intentional: they ensure that types remain simple, uniformly checkable, and stable under arbitrary IR transformations. Types are designed to be context-independent descriptors of compile-time properties and are kept separate from SSA values, control flow, and region structure.

This design choice is reflected in several core assumptions of the MLIR infrastructure:

- types do not reference SSA values or region-local program structure,
- type checking does not incorporate dominance or control-flow information,
- IR transformations such as replace-all-uses-with (RAUW), operation cloning, and function inlining do not rewrite types,
- types are treated as closed descriptors that remain valid under arbitrary transformations.

These assumptions ensure that types function as global, transformation-stable invariants, but they also prevent types from depending on runtime values represented as SSA values or on relationships between them. As a result, dimension equalities, index bounds, and algebraic relations derived from SSA values cannot be expressed, preserved, or checked at the type level.

Although MLIR supports rich symbolic reasoning at the value level through SSA graphs, attributes, and dialect-specific analyses, this information is inherently operational and pass-local. Transformations such as cloning or inlining invalidate value-level reasoning, and symbolic constraints must be repeatedly reconstructed. Consequently, symbolic properties expressed at the value level cannot serve as stable invariants throughout the compilation pipeline.

== C2 -- Tensor Dialect and Application-Level Consequences

At the tensor-dialect level, shape and bounds constraints cannot be attached to tensor types as symbolic invariants in a way that remains stable across transformations. As a result, relationships between tensor dimensions cannot be expressed or enforced uniformly at the type level.

Tensor dimensions that are computed dynamically, for example through shape arithmetic, loop bounds, or index calculations, must be represented as SSA values or attributes rather than as symbolic components of tensor types. As a result, MLIR tensor and vector types can encode individual dimensions as static integers or dynamic placeholders, but cannot express relationships between dimensions or global constraints that must hold simultaneously.

In particular:

- tensor and vector types cannot encode dependencies such as equality, sums, divisibility, or alignment between dimensions,
- index bounds and shape consistency conditions cannot be enforced at the type level,
- legality conditions for tensor transformations (e.g., fusion, tiling, or vectorization) cannot be expressed as type-level invariants.

As a consequence, tensor-related compiler passes, including tiling, fusion, bufferization, and canonicalization, must repeatedly reconstruct symbolic shape constraints from SSA graphs, attributes, and pass-local analyses. These constraints remain operational, transient, and pass-specific, and transformations invalidate them. This design increases implementation complexity, requires repeated re-validation of correctness conditions, and reduces the robustness of shape-sensitive optimizations.

Moreover, this approach prevents MLIR from preserving the shape-level correctness guarantees provided by shape-indexed type systems in high-level DSLs such as Rise, where array dimensions are tracked symbolically at the type level. It also precludes direct expression of value-indexed typing patterns, such as value-indexed tensor and index types (`Vector(n)`, `Idx(n)`) or shape-preserving function types, as studied in systems like ATTAPL, where bounds safety and shape consistency are enforced by construction rather than through repeated dynamic checks (see @pierce2024advanced, ch. 2, 9).

= Research Questions (Q1, Q2)

== Q1 -- MLIR Core

How can value-dependent types be represented at the type level in MLIR while respecting its SSA-based structure and remaining stable under IR transformations?

== Q2 -- Tensor Dialect

How can value-dependent types be used to express and preserve tensor shape invariants that are relevant for correctness and optimization across tensor transformations?

= Answers (A1, A2) and Approach

== A1 -- Core MLIR Contribution: Value-Dependent Types via Type-Level Parameters

To address the absence of stable type-level representations for symbolic program properties in MLIR, this thesis investigates whether and how a form of dependent types can be supported in an SSA-based intermediate representation without violating transformation stability or core MLIR invariants.

Instead of pursuing full dependent typing, the thesis focuses on a restricted and compiler-oriented form of dependency, namely value-dependent types, in which types may depend on program values under explicitly defined scoping and transformation rules. This restriction preserves symbolic value-level dependencies while avoiding the complexity of fully general dependent type theories @paszke2021gettingpointindexsets, @secureDistributedProgrammingValueDependentTypes. Rather than relying on refinement types or logical constraints, this work focuses on preserving symbolic value dependencies as stable type-level invariants.

To explore this design space in a controlled manner, the thesis uses ScaIR as a prototyping platform. ScaIR is a Scala-based intermediate representation that provides typed algebraic data types for IR construction, enabling rapid experimentation with type-system designs @edin_dal_scair. Using ScaIR allows conceptual questions about type-level abstraction, scoping, and substitution to be studied independently of MLIR’s C++ implementation constraints.

Rather than introducing value-dependent types directly, the investigation proceeds incrementally. The central observation is that value-dependent typing is a principled generalization of type-level parametricity: both rely on type-level abstraction, scoping, and substitution, but differ in the domain over which parameters range. In parametric polymorphism, types are abstracted over type parameters, whereas in value-dependent typing, types are abstracted over program values. Parametric polymorphism therefore exercises a strict subset of the mechanisms required for value-dependent typing (abstraction, scoping, and substitution at the type level), while deliberately excluding any dependency on program values.

Based on this observation, the investigation proceeds in two stages: first, the introduction of parametric polymorphism via type variables; second, a principled generalization from type parameters to value-dependent types.

=== Stage 1: Parametric Polymorphism via Type-Level Parameters

The first stage studies parametric polymorphism as a conceptual precursor to value-dependent types and isolates challenges related to type-level abstraction before introducing value parameters. Concretely, two representations of parametric polymorphism are implemented in ScaIR. Both correspond to universally quantified types of the form:

$ #sym.Lambda (T: "Type"). #sym.lambda (x:T). x : forall sigma. sigma -> sigma $

Here, $sigma$ denotes a bound type variable, written in de Bruijn style, reflecting that the variable is referenced outside the scope in which it is named.

The first representation encodes type variables purely at the type level using de Bruijn indices. This encoding relies exclusively on mechanisms compatible with MLIR’s existing type system. Types may abstract over type parameters, but they do not reference SSA values. This implementation establishes a baseline and exposes the complexity of representing abstraction, substitution, and scoping entirely within the type system.

The second representation encodes type variables explicitly using SSA values embedded in types. Although these parameters still range over types rather than program values, their representation via SSA values already requires several of the structural mechanisms later needed for value-dependent typing: embedding SSA references into types, enforcing basic dominance and scoping conditions for well-formedness, and rewriting type-level references during IR transformations.

Comparing these two encodings serves a methodological purpose. The de Bruijn-based encoding preserves MLIR’s current assumption that types are context-independent and self-contained, meaning that their interpretation does not depend on surrounding IR context, SSA values, or dominance relations. In contrast, the SSA-based encoding relaxes this assumption by allowing types to reference program entities under explicit scoping and dominance constraints.

At this stage, the implementation supports:

- type variables represented via de Bruijn indices,
- type variables represented via SSA-valued references embedded structurally in types,
- universally quantified function types,
- type-level abstraction, substitution, and instantiation,
- basic dominance and scoping checks to ensure structural well-formedness of SSA references in types,
- compatibility with core MLIR transformations.

This stage therefore isolates the structural mechanisms needed for type-level abstraction and substitution, while deliberately deferring any interpretation of SSA values as program values to the next stage.

=== Stage 2: Value-Dependent Types

Building on the mechanisms established in Stage 1, Stage 2 generalizes type-level parameters from types to values, such as natural numbers. This generalization enables types of the form:

$ #sym.Lambda (N: "Nat"). #sym.lambda (x: N."f32"). x : #sym.Pi (N:"Nat"). N."f32" -> N."f32" $

This example is schematic and serves to illustrate value-indexed types; the underlying mechanism is independent of tensors or shape-specific abstractions.

Rather than introducing fundamentally new abstraction or substitution mechanisms, this stage reuses the representation, scoping, and substitution machinery developed for parametric polymorphism and extends it to value-level parameters. Value-dependent types are introduced as a core IR mechanism, independent of any particular dialect or application domain.

The key additional challenge in Stage 2 is that type parameters now range over program values rather than abstract type parameters. While SSA references already appear in Stage 1, they function there purely as type-level binders whose scoping constraints ensure only structural well-formedness. In Stage 2, SSA values denote computed program values, and dominance, lifetime, and region structure determine whether a value-dependent type is well-defined at its use sites, including:

- dominance requirements ensuring that SSA values used in types are available at all type use sites,
- region and lifetime constraints governing the validity of value-level parameters,
- transformation-aware rewrite rules that preserve the meaning of SSA-valued type parameters under IR transformations.

ScaIR is extended to support type expressions parameterized by SSA values and to enforce dominance- and region-aware well-formedness checks. Parser and printer support is extended accordingly to accommodate SSA-valued type parameters.

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

- tensor and vector types indexed by SSA values,
- value-indexed index types for bounds-safe access (e.g., `Idx(n)`),
- expression of legality conditions (such as shape compatibility or tiling constraints) as type-level invariants rather than pass-local checks.

The work intentionally avoids introducing a full equational theory or normalization framework for shape expressions. Instead, shape parameters are treated symbolically, with equality determined syntactically or through explicit constraints. This restriction keeps the scope focused on feasibility and transformation stability.

Case studies include:

- lowering Rise-style shape-indexed types into value-indexed MLIR tensor types,
- encoding ATTAPL-style value-indexed tensor and index types (e.g. `Vector(n)`, `Idx(n)`),
- evaluating the stability of such types under standard MLIR transformations, including replace-all-uses-with (RAUW), common subexpression elimination (CSE), dead code elimination (DCE), loop-invariant code motion (LICM), and function inlining.

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

- preservation of symbolic shape relations across transformations,
- static enforcement of shape-related correctness conditions at the type level,
- explicit and robust legality checks for tensor transformations,
- closer alignment between MLIR and shape-indexed DSLs such as Rise.

Rather than introducing a full dependent type system or symbolic solver, this work demonstrates that a restricted, symbolic form of value dependence already yields substantial benefits for correctness and optimization.

== Scope and deliverables.

The thesis delivers (i) a ScaIR prototype supporting SSA-valued type parameters with well-formedness and transformation-aware rewrite behavior, and (ii) a tensor-focused case study using value-indexed shapes and index/bounds types. The scope intentionally excludes full dependent type theories or automated proof systems and instead evaluates feasibility and robustness under MLIR-style transformations and shape-sensitive legality checks.

= Related Work

== Rise

Rise is a functional, pattern-based intermediate representation built on typed combinators such as `map` and `reduce`, operating over multi-dimensional arrays. Its type system is parametric over shape, allowing array dimensions to be tracked symbolically and enabling rewrite-based optimizations whose correctness depends on shape invariants @LuckeSS21.

Rise demonstrates the value of expressing shape information at the type level. However, in its MLIR embedding, these shape-indexed types are not preserved directly. Shape information is lowered into values and attributes, and symbolic relationships between dimensions are no longer represented as type-level invariants. As a result, MLIR cannot retain the same shape-level guarantees that exist in Rise’s source-level type system.

== MimIR

MimIR is a higher-order intermediate representation based on the Calculus of Constructions, in which types are expressions that may depend on values. Its type system supports polymorphism, dependent types, and normalization of type- and value-level expressions, enabling strong correctness guarantees and optimization via type-level computation @leissa2025mimir.

MimIR demonstrates that dependent typing can be highly expressive in a compiler IR. However, it is structurally very different from MLIR: it does not use SSA form, does not impose dominance or region structure.

== MLIR Shape Dialect

MLIR provides a shape inference framework and the `shape` dialect, which allow operations to specify how output shapes are computed from input shapes via reference implementations @mlir_shape_inference, @mlir_shape_dialect_lowering.

However, shape reasoning in MLIR is deliberately confined to the value level. Shape functions operate over SSA values and attributes, and the results of shape computation are not reflected in the type system. Tensor types may contain static dimensions or dynamic placeholders, but they cannot encode symbolic relationships between dimensions or enforce shape invariants at the type level.

As a consequence, MLIR cannot attach type-level legality preconditions (e.g., required equalities/divisibility constraints) to operations in a way that is preserved and checked uniformly across the pipeline.

#bibliography("references.bib")
