# Master Thesis: 

## Title Ideas:

* Topic:
    * Integrate SSA Values in Types in MLIR via ScaIR 
    * how to use this in new tensor dialect for dependent shape computation/compilation

* Ideas:
    * Integrating SSA-Dependent Types into MLIR via ScaIR
    * SSA-Dependent Types in MLIR: A ScaIR-Based Design with a Dependent Tensor Dialect
    * SSA-Dependent Types for Shape-Aware Compilation: Extending MLIR via ScaIR
    * From Dependent Type Theory to MLIR: Embedding SSA Values in Types for Dynamic Shape Semantics
    * SSA-Dependent Tensor Types in MLIR: A Dependent Type System Implemented with ScaIR
    * Breaking Type Purity: A Study of SSA-Dependent Types in MLIR
    * A Dependent Type Extension for MLIR: Embedding SSA Values into Types
    * Dependent Types over SSA Values in MLIR: A Design and Prototype via ScaIR
    * Embedding SSA Values in MLIR Types: A Dependent Type System Prototype Using ScaIR
    * Extending MLIR with SSA-Dependent Types for Dependent Shape Reasoning


## SCQAV: A New Tensor Dialect with Dependent Shapes (Motivation) and Enhancing MLIR’s Type System with Dependent Types (Core Thesis)

#### S — Situation

Modern high-level DSLs such as Rise rely on shape-indexed types—for example N.M.f32—to express array dimensions and correctness invariants directly in the type system. These type-level shapes drive correctness-preserving rewrites, optimization legality, and guarantee structural invariants. When lowering such programs into MLIR, however, this shape-level information cannot be preserved in the type system.
MLIR’s tensor types encode shapes as lists of integer dimensions (static or dynamic), but these dynamic dimensions cannot depend on SSA values.

Existing MLIR mechanisms therefore either:

* encode shapes only as constants in types,
* attach shape information as attributes,
* or shift shape reasoning to values (e.g., via the shape dialect),

but none can express types that depend on SSA values, such as:
```mlir
tensor<%n x f32>
```

At the same time, systems like MimIR show that dependent types—including dependent tensor shapes—can be deeply integrated into an IR when the type system is expressive enough and supports normalization. MimIR, however, does not share MLIR’s design constraints (SSA, interning, region structure).

This reveals a more fundamental question: MLIR’s type system is pure, interned, and context-independent. Types cannot reference SSA values, depend on dominance, or carry region-scoped information. Therefore they cannot express dependent types. This limitation prevents MLIR from capturing dependent shape invariants required by shape-aware DSLs like Rise, from enforcing correctness properties at the type level, and from supporting dependent-type–driven optimizations.

This motivates exploring whether MLIR can be extended—carefully and safely with SSA-dependent types, enabling richer type-level invariants directly inside MLIR.

#### C1 — Complication

MLIR’s core type system is designed around **interned, pure, context-independent types**. This brings two complications:

1. **Types cannot reference SSA values.**
   MLIR explicitly assumes types are globally comparable through structural/pointer equality and are independent of region or dominance context.

2. **Dependent-type encodings exist only as workarounds.**
   Existing attempts:

   * Rise-on-MLIR encodes array lengths as pure `Nat` arguments of `map`/`reduce` patterns, *not* as SSA-dependent types.
   * MimIR’s CC-style dependent types work because MimIR is *not* MLIR and can treat types as expressions and normalize them eagerly .
   * ScaIR encodes type relationships more safely than TableGen, but *still inherits MLIR’s limitation that types cannot depend on SSA values* .

As a result:

* **we cannot express a vector type whose length is a computed SSA value** (e.g., the result of a shape computation),
* **we cannot express invariants about dynamic shapes in the type system itself**,
* **and we cannot use dependent typing as described in ATTAPL (e.g., Π-types ensuring index-range correctness) inside MLIR** .

#### C2 — Complication

**MLIR fundamentally breaks with dependent-type needs:**

* An SSA value cannot appear in a type.
* Type-checking cannot depend on dominance.
* Interning disallows dynamic type structure.
* Cloning/inlining cannot rewrite types referencing local SSA values.
* MLIR’s parser/printer assumes absolute purity.

All existing MLIR dialects that “encode dependent information” use workarounds:

* encoding dynamic information into attributes/operands (not types),
* or reifying shape computations on the value level (not semantically tied to the type),
* or relying on the shape dialect and verifying post-hoc.

None achieves **true dependent types** in the sense of ATTAPL’s Π/Sigma types .

#### Q1 — Question

Can MLIR’s type system be extended to support SSA-dependent types safely and decidably, while respecting essential MLIR invariants such as dominance, type purity, and (as far as possible) type interning?

#### Q2 — Question

Can we design a Tensor dialect whose types depend on SSA values, preserve shape invariants, remain compatible with MLIR’s transformation infrastructure, and maintain backward compatibility with existing MLIR dialects?

#### A1 — Answer (Core MLIR Contribution): Embedding SSA Values Inside MLIR Types, Prototyped in ScaIR

We propose extending MLIR’s type system so that **types may contain references to SSA values**, enabling *true dependent types* that express relationships between runtime-computed values and static type structure. To explore this design safely and flexibly, we first implement it as a **prototype inside ScaIR**, which offers typed algebraic data types (ADTs) for IR construction without being constrained by MLIR’s C++ type interner.

##### **Prototype in ScaIR (Design Sandbox)**

In ScaIR, we introduce:

* a **dependent lambda calculus (Dlam)** whose types may embed SSA-like identifiers,
* a representation of **non-interned dependent type expressions** as structured ADTs,
* **region- and dominance-aware verification** for checking the validity of value references inside types,
* an evaluation of how SSA-substitution (RAUW-like behavior) affects type correctness.

This ScaIR prototype serves as a **reference semantics** for SSA-dependent types and allows us to iterate without fighting MLIR’s internals prematurely.

##### **MLIR Extension (Core Answer)**

Guided by the ScaIR prototype, we extend MLIR with dependent types supporting constructs like:

```mlir
fun<!dlam.tvar<%U> -> !dlam.tvar<%U>>
!dlam.tvar<%U>
idx<%n>
```

This requires:

* introducing a **non-interned dependent type attribute** (`DepTypeAttr`) whose internal AST embeds SSA references,
* implementing **dominance-aware type verification** inside MLIR,
* extending MLIR’s parser and printer to accept SSA-valued type expressions,
* extending MLIR’s transformation infrastructure so that types can **survive RAUW, cloning, inlining, and region movement**, including type-level SSA reference rewriting,
* selectively relaxing MLIR’s **global type interning** to support dependent types safely.

This answer defines the **core technical contribution**:
A design and prototype for **SSA-dependent types in MLIR**, developed first in ScaIR and then ported into an MLIR C++ implementation.


#### A2 — Answer (Application-Level Contribution): A Tensor Dialect with Dependent Shapes

Building on the SSA-dependent type mechanism, we design and prototype a **Tensor dialect whose types depend on SSA values**, allowing MLIR to represent dynamic shape semantics directly in the type system. This enables MLIR programs to use types such as:

```mlir
tensor<%n x f32>
vector<%m x i32>
idx(%n)
```

where `%n` or `%m` may be computed at runtime.

We implement and evaluate:

1. **Dependent-shape tensor types**

   * tensors indexed by SSA-driven Nat expressions,
   * dependent index types (`idx(%n)`) for bounds and safety,
   * equality constraints in the type system (e.g., `N+M = M+N` normalization).

2. **Shape-aware legality and verification**

   * dynamic-shape fusion or tiling checks expressed at the type level,
   * type-based invariants for correctness-by-construction tensor programs.

3. **Case studies**

   * Lowering of Rise’s shape-indexed types (`N.M.f32`) into dependent MLIR types,
   * Encoding ATTAPL-style dependent vector/index types (`Vector(n)`, `Idx(n)`),
   * Evaluating transformation stability (RAUW, inlining, CSE, DCE) with dependent shapes.

This answer demonstrates **practical expressiveness and utility**: a dependent-type Tensor dialect that preserves high-level shape invariants, supports correctness-driven optimizations, and validates the feasibility of SSA-dependent types in MLIR.


#### V1 — Value

A successful dependent-type extension enables:

* **More expressive DSL lowering** (Lift/Rise embedding becomes precise, not ad hoc).
* **Stronger invariants**: index bounds, shape consistency, matrix dimension correctness.
* **Better MLIR transformations**: e.g., LICM or CSE with type-aware dependence.
* **Domain breakthroughs**: machine learning shape correctness, tensor algebra safety, etc.

This work also clarifies the *limits* of MLIR’s design:
Which invariants are essential? Which can be relaxed?
Which dependent semantics are realistic for production MLIR?

Ultimately, this prototype can feed into future discussions about **MLIR v2** or dependent-type “sub-dialects.”

#### V2 — Value

A dependent-type-enhanced Tensor dialect would unlock:

* **Correctness-by-construction shape semantics**: MLIR operations could carry dynamic invariants in the type system rather than as ad hoc runtime assertions.
* **Better lowering correctness**: high-level DSLs (Rise, ScaIR, etc.) could preserve their precise semantic guarantees down to MLIR.
* **More advanced optimizations**: type-level equalities (e.g., `N+M = M+N`) could support canonicalization analogous to MimIR’s normalization framework.
* **Interoperability**: MLIR dialects could export richer invariants to optimizers, analyzers, and verification tooling.

In short:
**MLIR gains the expressive power of dependent types (similar to those described in ATTAPL’s Chapters 2 & 9) while preserving its multi-dialect, SSA-based compiler benefits.**



# Master Thesis Proposal: SSA-Dependent Types in MLIR via ScaIR: A Dependent Type System and Tensor Dialect for Dynamic Shape Semantics

## **1. Motivation**

Modern domain-specific compiler frameworks rely on rich type systems to ensure correctness, guide optimizations, and preserve domain semantics across lowering stages.
Functional pattern-based IRs like **Rise** embed array shapes directly into types (e.g., `N.M.f32`), enabling high-level optimizations through semantics-preserving rewrites (e.g., typed `map`, `reduce`, reshaping rules). Meanwhile, systems such as **MimIR** demonstrate the expressiveness of **dependent types**, rooted in the Calculus of Constructions, to encode tensor shapes, index constraints, or invariants directly within the type system.

However, **MLIR’s core type system cannot express dependent types**:

* MLIR types are *pure, interned, immutable*, and
* **cannot reference SSA values** or depend on dominance/region context.

As a result:

* all dynamic shapes must be encoded as operands or attributes,
* no dependent shape invariants can be maintained in types,
* correctness properties expressed at the type level cannot be represented in MLIR’s type system,
* high-level DSLs like Rise lose their type-level structure during lowering.

This thesis investigates how **dependent types or a practically useful subset of them can be integrated into core MLIR**, despite MLIR’s design assumptions of *pure, interned, context-independent types*.


## **2. Problem Statement**

MLIR’s type system enforces several invariants:

* **Types are globally interned** and structurally comparable by pointer equality.
* **Types are context-independent**: they cannot reference SSA values or depend on region/dominance structure.
* **Type checking assumes purity**—no rebuilding during RAUW, cloning, or inlining.
* The MLIR printer, parser, canonicalizer, and conversion passes all assume types contain *no IR references*.

These invariants prevent expressing types such as:

```
tensor<%n x f32>       // dependent shape
vector<%len x i32>     // dependent vector length
idx(%n)                // dependent index bound
```

Even though such dependent types are essential for:

* precise shape invariants,
* correctness proofs (e.g., Π/Sigma types),
* verifying Rise-style rewrite legality,
* and guiding shape-aware optimization pipelines.

MLIR currently resorts to workarounds (attributes, operands, shape dialect), none providing *first-class dependent types*.



## **3. Research Question**

### **Q1 — MLIR Core**

**Can MLIR’s type system be extended to support SSA-dependent types safely and decidably, while respecting essential MLIR invariants such as dominance, type purity, and (as far as possible) type interning?**

Sub-questions:

1. Can dependent type expressions referencing SSA values remain valid under dominance, scoping, cloning, and RAUW?
2. Which MLIR invariants (interning, purity, structural equality) are essential, and which can be relaxed?
3. Can a dependent lambda calculus (Dlam) be embedded into MLIR and verified efficiently?
4. What compromises provide both decidability and expressiveness?
5. How compatible is such a system with existing MLIR dialects and tooling?

### **Q2 — Tensor Dialect Case Study**

**Can we design a Tensor dialect whose types depend on SSA values, preserve shape invariants, remain compatible with MLIR’s transformation infrastructure, and maintain backward compatibility with existing MLIR dialects?**


# **4. Approach: SSA-Dependent Types in MLIR via ScaIR**

### **4.1 Baseline Approach — Dependent Types via de Bruijn Indices (Core MLIR Capabilities Only)**

Before extending MLIR’s type system, we establish a baseline dependent-type encoding using only MLIR’s existing capabilities. This baseline is implemented in ScaIR, using a de Bruijn–indexed representation of types and binders (e.g., `!dlam.bvar<0>`), as demonstrated in examples such as polymorphic identity functions.

This encoding provides:

* type-level binders via de Bruijn indices,
* polymorphism (forall) and dependent arrow types,
* type-level substitution and normalization,
* a direct embedding into MLIR without modifying its type interner,
* full compatibility with MLIR’s transformation infrastructure (RAUW, cloning, inlining),
* no SSA references inside types.

However, this baseline approach cannot express SSA-dependent shapes, shape-indexed vectors such as:

```mlir
tensor<%n x f32>
idx(%n)
```

or dependent equalities involving runtime values. It therefore serves as a control experiment establishing what is possible under MLIR’s type purity constraints before introducing SSA-dependent types.

### **4.2. ScaIR Prototype (Design Sandbox)**

We first prototype SSA-dependent types in **ScaIR**, which provides ADT-based IR construction without MLIR’s interning constraints.
The ScaIR prototype includes:

* a **dependent lambda calculus (Dlam)** whose types may embed SSA-like identifiers,
* non-interned dependent type expressions as typed ADTs,
* dominance- and region-aware type verification,
* RAUW-like substitution over type-level SSA references.

This forms a reference semantics and guides MLIR design decisions safely.

The dependent lambda calculus (Dlam) should consist of:
  * dependent function types,
  * vector/tensor types indexed by Nat expressions,
  * partial evaluation and constant folding of Nat expressions,
  * dependent equality reasoning.

* Test programs including:
  * Rise-style shape types (`N.M.f32`),
  * ScaIR DSL programs with refined types,
  * ATTAPL-style dependent index examples,
  * representative MLIR transformations (DCE, CSE, LICM, RAUW, inlining) applied to dependent types.

### **4.3. MLIR Implementation (DepTypeAttr)**

We extend MLIR with a new dependent type attribute:

```
!dlam.tvar<%u>
tensor<%n x f32>
idx<%i>
fun<!dlam.tvar<%U> -> !dlam.tvar<%U>>
```

Key engineering tasks:

* **DepTypeAttr** storing an AST with SSA references (breaking global interning only for these types).
* **Region- and dominance-aware type verification**.
* **Parser/printer extension** to allow `%value` inside type syntax.
* **Transformation-aware type behavior**:

  * RAUW rewriting inside types
  * cloning/inlining region relocation updates
  * DCE & liveness: making type-embedded values into real uses
  * CSE/canonicalization of Nat/shape expressions

This forms the core of the contribution.

## **5. Tensor Dialect Case Study (A2)**

On top of the MLIR extension, we design a **Tensor dialect with dependent shapes**, enabling types such as:

```mlir
tensor<%n x f32>
vector<%m x i32>
idx(%n)
```

The case study demonstrates:

### **Dependent-shape type forms**

* SSA-indexed tensor types
* dependent index types (e.g., `idx(%n)` for bounds)
* simple equalities / rewrites such as `n + 0 = n`

### **Shape-aware legality checks**

* dependent dimension checks for fusion/tiling
* type-level shape reasoning rather than runtime assertions

### **Case Study Programs**

* lowerings of Rise types (`N.M.f32`)
* ATTAPL-style dependent vectors (`Vector(n)`)
* RAUW, inlining, region movement, CSE, LICM stress tests

The Tensor dialect validates that SSA-in-types is not only feasible but *practically useful*.

## **6. Work Plan / Implementation Roadmap**

### Phase 1 — Formalize Dependent Lambda Calculus (Dlam) and Implement in ScaIR

Define a dependent lambda calculus (Dlam):

* dependent types (Π-types, Nat expressions, vectors/tensors)
* typing and normalization rules
* SSA-like identifiers inside types

Implement it in ScaIR to obtain:

* a safe environment for experimentation,
* a reference type checker and normalizer,
* concrete test examples.

### Phase 2 — SSA-Dependent Types in ScaIR

* implement DepTypeAttr
* SSA reference embedding

#### Dependent Type implemented as `TypeAttribute` in ScaIR 

* Implement `DepTypeAttr` with SSA value references and Nat expressions.
* Extend parser/printer for `%value` inside types.
* Add dominance- and region-aware verification.
* parsing/printing

### **Phase 3 — Integration with MLIR’s Transformation Infrastructure**

Test dependent types under transformations and extend support where needed.

Subsystems addressed:

* **RAUW**: rewrite type-internal SSA references.
* **Cloning / inlining**: ensure dependent types remain valid.
* **DCE**: mark SSA values in types as real uses.
* **Canonicalization/CSE**: ensure Nat/type expressions canonicalize safely.
* **Type interning**: introduce per-module or non-interned modes.
* **Dominance Verification**

Goal: identify the minimal required MLIR adjustments.

### **Phase 4 — Tensor/Shape Case Study**

Implement a dependent-type-aware tensor dialect extension showing real utility:

* dependent tensor shapes (`tensor<%n x f32>`),
* dependent index types
* shape-sensitive correctness checks,
* a simple shape-dependent pass (e.g., fusion legality or dependent index bounds).

### **Phase 5 — Evaluation**

Evaluate:

* correctness
* expressiveness versus Rise/MimIR dependent types and baseline approach,
* compatibility with MLIR passes,
* decidability & performance of type checking,
* limitations and architectural obstacles.

## **7. Expected Contributions**

### **Theoretical**

* A practical dependent lambda calculus (Dlam) for an SSA IR
* Identification of MLIR invariants compatible with SSA-dependent types
* An examination of MLIR invariants under dependent typing

### **Engineering**

* A ScaIR-based prototype
* An MLIR extension enabling SSA-in-types
* A dependent-type Tensor dialect
* A correctness-preserving dependent-type example pipeline

### **Impact**

* Better correctness-preserving lowering for DSLs like Rise
* Richer shape-dependent type semantics in MLIR
* Insight into potential MLIR v2 type-system evolution

## **8. Related Work**

### **Rise**

Rise is a functional, pattern-based IR built on typed combinators (`map`, `zip`, `reduce`) operating over multi-dimensional arrays.
Its type system is *parametric over shape*, enabling rewrite-based optimizations where shape information is integral to correctness (e.g., fusion legality depends on consistent lengths).
Rise demonstrates the power of **type-indexed shapes**, but its MLIR embedding (CC’21) does *not* represent dependent types – shape sizes remain static or parameterized at pattern definition, not true SSA-driven dependent types.
This thesis extends MLIR in ways that could allow a more faithful lowering from Rise to MLIR with preserved type-level shape semantics.

### **MimIR**

MimIR is a higher-order IR based on the **Calculus of Constructions**, where *types are expressions* and can depend on values.
Its pure type system supports polymorphism, dependent types, and aggressively normalizing type expressions.
MimIR shows the feasibility and value of dependent types in compiler IR design but is structurally distinct from MLIR:

* no SSA/purity constraints,
* no interning,
* no region-dominance model,
* IR nodes are hash-consed expressions.

This thesis is directly inspired by MimIR but addresses the significantly harder question:
**How can a constrained SSA-based IR like MLIR support a fragment of MimIR-style dependent types without breaking its foundational invariants?**


## **9. Conclusion**

This thesis bridges the gap between dependent-type-rich DSLs (Rise, MimIR) and MLIR’s conservative type system by introducing SSA-dependent types directly inside MLIR types.  
Through a ScaIR reference prototype, a C++ MLIR implementation, and a dependent Tensor dialect case study, the work evaluates feasibility, risks, and benefits of SSA-in-types, and contributes to future MLIR type-system evolution discussions.