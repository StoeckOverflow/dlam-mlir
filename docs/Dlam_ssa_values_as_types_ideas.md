alright nice, thank you! What do you think now: Is here: # Integration of SSA Values as Types in ScaIR / MLIR-like IR

## 1. Motivation and Goal

### Current situation

* **Types** (`TypeAttribute`, `DlamType`, …) are *pure, internable*, and globally comparable by structural equality.
* They cannot reference SSA values (`%v`), and thus all types are context-independent.
* **Printers/parsers** assume purity: no region scoping or dominance-sensitive references appear in type position.

### Goal

Enable **dependent types** where types may reference SSA values:

```
!dlam.vec<%n, !dlam.const<i32>>
```

That is: type equality and semantics depend on *runtime values* within a given region.

To achieve this, ScaIR needs controlled dependence between values and type expressions, respecting dominance, region boundaries, and lifetime.

---

## 2. Approach A: 
###  2.1 High-Level Architecture

| Concern                   | Solution                                                                                                                                      |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Purity vs dependency      | Keep existing `TypeAttribute` for pure, globally interned types. Introduce a **non-interned expression hierarchy** for value-dependent types. |
| Value references in types | Represent as `ValueId` (module-stable SSA handle) inside a `DepTypeAttr` wrapper.                                                             |
| Verification              | Add a dependent-type verifier that checks dominance and region legality.                                                                      |
| Lifetime management       | Track references from types to SSA values; reject moves/erasures violating dominance or update mappings via rewriters.                        |
| Interning                 | Disable or scope-intern dependent types per module.                                                                                           |
| Printing/parsing          | Extend printers and parsers to resolve `%names ↔ ValueId` within DepTypeAttr.                                                                 |

---

### 2.3. Core IR Model

#### 2.3.1 Type Expression Layer

```scala
sealed trait TypeExpr           // non-interned
final case class TEConst(pure: DlamType) extends TypeExpr
final case class TEValueRef(id: ValueId) extends TypeExpr
final case class TEFun(in: TypeExpr, out: TypeExpr) extends TypeExpr
final case class TEForall(body: TypeExpr) extends TypeExpr
final case class TEVec(len: NatExprExpr, elem: TypeExpr) extends TypeExpr
```

#### 2.3.2 Nat Expressions (value-aware)

```scala
sealed trait NatExprExpr
final case class NELit(n: Long) extends NatExprExpr
final case class NEAdd(a: NatExprExpr, b: NatExprExpr) extends NatExprExpr
final case class NEMul(a: NatExprExpr, b: NatExprExpr) extends NatExprExpr
final case class NEFromValue(id: ValueId) extends NatExprExpr
```

Partial evaluation of NatExpr
  - Add a tiny evaluator:
      - evalNat(NatExprExpr): Option[Long] (if all leaves are NELit).
      - Constant fold NEAdd(NELit a, NELit b) → NELit(a+b) in a canonicalization pass.
  - Optional: a congruence solver (rewrite a+(b+c) ↔ (a+b)+c etc.) if we later need reasoning.

#### 2.3.3 Bridging Attribute

A wrapper attribute embeds this expression tree into the existing MLIR-like type system:

```scala
final case class DepTypeAttr(expr: TypeExpr)
  extends TypeAttribute, ParametrizedAttribute {
  override def name = "dlam.dep_type"
  override def parameters = Seq()   // custom printed
  override def custom_print(p: Printer) = DepTypePrinter.print(expr, p)
  override def custom_verify() = Right(())
}
```

---

### 2.4. Value Identity Infrastructure

#### 2.4.1 Stable IDs

```scala
final case class ValueId(defOpId: OpId, resultIndex: Int)
final case class OpId(path: List[Int]) // indices along region/block/op nesting
```

#### 2.4.2 Mapping

Maintain a per-module table:

```scala
ModuleValueTable: Map[(OpId, resultIndex) ↔ Value]
```

Used for dominance checking, rewriting, and parsing `%name` references.

#### 2.4.3 Rewrite semantics

When cloning, erasing, or replacing ops:

* Either **reject** illegal transformations (initial policy), or
* Remap `ValueId`s using a provided substitution map.



### 2.5. Printers and Parsers

Example printed forms:

```
!dlam.dep<vec<%n, !dlam.const<i32>>>
!dlam.dep<fun<%x, !dlam.const<f32>>>
```

Custom printer:

```scala
object DepTypePrinter:
  def print(e: TypeExpr, p: Printer)(using indent: Int = 0): Unit = e match
    case TEConst(pure)   => p.print(pure)
    case TEValueRef(id)  => p.print("%", ValueNameResolver.nameOf(id))
    case TEFun(i,o)      => p.print("!dlam.dep<fun<"); print(i,p); p.print(", "); print(o,p); p.print(">>")
    case TEVec(len, el)  => p.print("!dlam.dep<vec<"); printNat(len,p); p.print(", "); print(el,p); p.print(">>")
    case TEForall(b)     => p.print("!dlam.dep<forall<"); print(b,p); p.print(">>")
```

Parser: resolve `%n` → `ValueId` via the `ModuleValueTable`.

### 2.6. Verification and Scoping Rules

#### 2.6.1 Dominance

For every `DepTypeAttr(expr)`:

* Every `TEValueRef(id)` must be **dominated** by its defining op.
* Cross-region references are illegal unless explicitly allowed.

#### 2.6.2 Region scoping

* Inner-region values cannot appear in types outside that region.
* Block arguments act as implicit values with `ValueId` derived from their block.

#### 2.6.3 Lifetime

* On erase or move of defining op, either:

  * Reject rewrite (`safe mode`), or
  * Remap dependent uses via `mapValueIds`.
  * ReplaceAllUsesWith: Provide a utility rewriteDependentTypes(replaceMap) so pattern rewriters can update all dependent types when they RAUW values.
  * GC of dep-types: If we keep per-module caches, ensure they drop entries when the referenced ValueId is dead.

#### 2.6.4 Verification pass

Add `verifyDependentTypes(mod: ModuleOp)`:

1. Traverse all `DepTypeAttr`s.
2. Collect all `ValueId`s.
3. Check dominance, scoping, and type kind (`index`, etc.).
4. Emit diagnostics with precise source (`%b` used in !dlam.dep<...> at op X).


### 2.7. Equality, Hashing, Interning

* **Do not** globally intern `DepTypeAttr`.
* Provide **structural equality** over `TypeExpr`, with `ValueId` equality.
* Hashing includes the `ValueId`.
* Optionally cache per-module.

### 2.8. Compiler and Transformation Impact

| Transform            | Required Change                                                        |
| -------------------- | ---------------------------------------------------------------------- |
| **DCE**              | treat use in type as real use                                          |
| **CSE**              | forbid cross-region dedup for values referenced in types               |
| **LICM**             | dominance guard: hoist only if dominance holds for all type-uses       |
| **RAUW**             | call `mapValueIds(old→new)` for DepTypeAttr users                      |
| **Cloning/Inlining** | rebuild ValueIds for cloned values                                     |
| **GVN/ConstFold**    | if SSA becomes constant, substitute `NEFromValue` → `NELit`            |
| **Verifier**         | run `verifyDependentTypes` after normal IR verify                      |
| **Pass infra**       | add `collectValueIdUsesInTypes` and `rejectIfValueUsedInTypes` helpers |

### 2.9. Testing Matrix

| Category     | Example Test                                               |
| ------------ | ---------------------------------------------------------- |
| Round-trip   | parse/print of `!dlam.dep<vec<%n, !dlam.const<i32>>>`      |
| Dominance    | reject outer reference to inner-region value               |
| DCE          | ensure %b used in type isn’t deleted                       |
| RAUW         | remap value refs after replacement                         |
| Cloning      | remap ValueIds correctly when duplicating regions          |
| Inlining     | inlined dependent types refer to cloned values             |
| NatExpr      | constant folding `2 + %n * 3`                              |
| Cycles       | reject self-referential types                              |
| Cross-symbol | reject references across top-level ops (functions/modules) |

### 2.10. Implementation Phases (Practical Roadmap)

| Phase  | Focus                                                                       |
| ------ | --------------------------------------------------------------------------- |
| **1.** | Add `DepTypeAttr` + `TypeExpr` + `ValueId` infrastructure (non-interned).   |
| **2.** | Extend printer/parser to support `%` inside types.                          |
| **3.** | Implement dominance verifier (`verifyDependentTypes`).                      |
| **4.** | Integrate into rewriter infra (`mapValueIds`, `collectValueIdUsesInTypes`). |
| **5.** | Extend passes: DCE, LICM, CSE, RAUW.                                        |
| **6.** | Add NatExpr constant folding, partial evaluation.                           |
| **7.** | Add cloning/inlining remap support.                                         |
| **8.** | Stress-test with nested regions and polymorphic vector types.               |

### 2.11. Example

```mlir
%b : index = "arith.addi"(%n, %m) : (index, index) -> index

// A vector type depending on SSA %b
%arg0 : !dlam.dep_type<!dlam.dep<vec<%b, !dlam.const<i32>>>> = ...
%r = "my.op"(%arg0) : (!dlam.dep_type<!dlam.dep<vec<%b, !dlam.const<i32>>>>) -> ()
```

In Scala IR construction:

```scala
val ty = DepTypeAttr(
  TEVec(NEFromValue(ValueId(bOpId, 0)), TEConst(DlamConstType(I32)))
)
```

### 2.12. Further Stuff

#### Interprocedural boundaries
  - Function arguments in types: Decide policy: allowed if the type-uses are inside the same function? (Usually “yes”.)
  - Return types depending on args: Allowed if dominance holds at function entry (it does for args). Keep in mind inlining/outlining must remap ValueIds (see §10).

#### Expressiveness
  - intensional dependent equality, no equation of runtime-equal SSA Values
  - Equality reasoning pass: maintain equivalence relation over SSA Values?
    - eq(%b1, %b2) if both compute arith.addi %n, %m
    - then merge !dlam.dep<vec<%b1, T>>  →  !dlam.dep<vec<%b2, T>>
      - Example:
        ```mlir
        // both %n and %m are equal, will be equated by CSE/RAUW
        // If %n and %m are not equal, but %b1 and %b2 value are, how to equate that?
        %b1 = arith.addi %n, %m
        %b2 = arith.addi %n, %m
        !dlam.dep<vec<%b1, !dlam.const<i32>>>
        !dlam.dep<vec<%b2, !dlam.const<i32>>>
        ```
  - E-graph engine like egg of NatExprExpr language to evaluate (%n + %m) == (%m + %n)
    - Example for NatExpr Normalization:
      ```mlir
      %b1 = arith.addi %n, %m
      %b2 = arith.addi %m, %n
      !dlam.dep<vec<%b1, !dlam.const<i32>>>
      !dlam.dep<vec<%b2, !dlam.const<i32>>>
      ```

## 3 Alternative Architecture: Types as SSA Values (Approach B)

While the main design proposed in this document (Approach A) embeds SSA references *inside* types using a non-interned `TypeExpr` hierarchy, there is an alternative that preserves MLIR’s core assumptions much more directly: Represent dlam types not as MLIR types but as SSA values.

In this approach, the “type” `T` in `!dlam.tvar<%T>` is not stored inside a type attribute.
Instead, `%T` is an ordinary SSA value of type `!dlam.type`.
Type constructors such as `fun`, `forall`, `vec`, etc. become ops producing type values.

### Example

```
%U : !dlam.type                    // a type value
%funTy = dlam.type_fun %U, %U      // : !dlam.type
%x : %U                            // value typed by SSA type
```

### Motivating Principle

In standard MLIR:

* Types must be pure, immutable, interned, globally unique.
* SSA values obey dominance, RAUW, cloning, and are not interned.

By making types into SSA values, we immediately gain:

* dominance correctness “for free,”
* type rewriting “for free,”
* RAUW for types “for free,”
* cloning / inlining consistency “for free,”
* no interference with MLIR’s type interner.

Thus, Approach B can be compatible with MLIR’s C++ implementation

### **B.1 Core Idea**

Introduce a single MLIR type:

```
!dlam.type            // This is the host-level MLIR type for “dlam type values”
```

And ops producing values of that type:

```
dlam.type_fun      : (!dlam.type, !dlam.type) → !dlam.type
dlam.type_forall   : (region) → !dlam.type
dlam.type_vec      : (!dlam.nat, !dlam.type) → !dlam.type
dlam.nat_from_ssa  : (%v : index) → !dlam.nat
dlam.nat_add       : (!dlam.nat, !dlam.nat) → !dlam.nat
...
```

User-level lambdas are then typed with SSA values:

```
%funTy = dlam.type_fun %U, %U
%v = dlam.vlambda (%x : %U) : %funTy { ... }
```

#### Expressiveness

Approach B is **fully expressive**: it supports all examples from Approach A.
It simply relocates types from the “TypeAttribute world” into the “SSA value world.”

### **B.2 Pros and Cons**

#### Advantages

* **Full MLIR compatibility** (no changes to core type system).
* **Dominance automatically enforced**.
* **RAUW automatically updates all uses of a type value**.
* **Cloning, inlining, CSE, constant folding work without custom machinery**.
* **Serialization is simpler** (types are just SSA values).

#### Disadvantages

* Surface syntax changes:
  * we write `%U` as a value rather than `!dlam.tvar<%U>`.
* Dlam types are no longer MLIR Types, but SSA values.
* Need to implement a `!dlam.type` dialect-level type language (like a mini λ-calculus inside values).

## 3.2 Comparison: Approach A vs. Approach B

| Concern                         | **Approach A: DepTypeAttr (Types-in-Types)** | **Approach B: Types-as-SSA**    |
| ------------------------------- | -------------------------------------------- | ------------------------------- |
| Syntax closeness to type theory | ideal                                  | less elegant              |
| MLIR compatibility              | breaks uniquing                        | native                    |
| RAUW support                    | manual rewrite inside type trees             | automatic                       |
| Dominance checking              | custom                                       | automatic                       |
| Cloning / inlining              | must rewrite inside types                    | automatic                       |
| Parser/printer complexity       | high                                         | low                             |
| Type-level computation          | custom TypeExpr interpreter                  | use SSA ops                     |
| Matches paper-style examples    | perfectly                                    | requires slight notation change |
| Portability to C++ MLIR         | difficult                                    | straightforward                 |

## 3.3 Side-by-Side Example: Polymorphic Identity

### Target example

```
ΛT. (ΛU. λ(x : tvar<%U>). x)[T]
```

### **Approach A (Types-in-Types)**

```
%G = dlam.tlambda () : !dlam.forall<!dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>>> {
  %v = dlam.vlambda (%x : !dlam.tvar<%U>)
      : !dlam.fun<!dlam.tvar<%U> -> !dlam.tvar<%U>> {
        dlam.vreturn %x : !dlam.tvar<%U>
      }
  dlam.treturn %v : !dlam.fun<!dlam.tvar<%U> -> !dlam.tvar<%U>>
}

%h = dlam.tapply %G %T
```

Internally, we store:

```
TETVar(TEValueRef(ValueId(%U)))
```

### **Approach B (Types-as-SSA)**

```
%funU = dlam.type_fun %U, %U         // produces a type value
%v = dlam.vlambda (%x : %U) : %funU {
  dlam.vreturn %x : %U
}

%G = dlam.type_forall (...)          // produces a type abstraction
%h = dlam.tapply %G, %T              // instantiates the forall at T
```

Note: `%U` and `%T` are values of type `!dlam.type`.

Same meaning, different surfaces.

## 3.4 Union-Find and Type Equality (Applies to Both A and B)

Regardless of which approach we adopt, SSA-dependent types require some notion of *type congruence*:

* `(%n + %m)` might equal `(%m + %n)`
* `%t1` and `%t2` might be two separate SSA values representing the same ground type.
* GVN or constant-folding may equate two nat-expressions.

We therefore use **union-find** either way:

### In Approach A

Union-find ranges over `TypeExpr`, with leaves `ValueId`.
We merge equivalence classes of expressions.

### In Approach B

Union-find ranges over SSA values of type `!dlam.type` or `!dlam.nat`.
Merging is just “SSA values %a and %b represent the same type.”