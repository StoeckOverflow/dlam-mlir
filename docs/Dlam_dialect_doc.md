# **Dlam Dialect Specification**

## **1. Overview**

The **`dlam` dialect** models a dependently-typed λ-calculus with explicit polymorphism using **de Bruijn indices** for binders.
Types are represented as **attributes** (`!…`), while programs are expressed as **operations** (`"…"`) in MLIR SSA form.

All types belong to the kind `!dlam.type`, and all binders (both type- and value-level) are encoded via MLIR **regions** that introduce de Bruijn depth.

---

## **2. Type Attributes**

```
DlamType ::= DlamTypeType
           | DlamBVarType
           | DlamFunType
           | DlamForAllType
```

### 2.1 Universe

```
!dlam.type
```

The universe of all Dlam types.

---

### 2.2 De Bruijn Type Variable

```
!dlam.bvar<k>
```

A de Bruijn index referencing the binder `k` steps outward from the current type context.
`k` ∈ ℕ.

---

### 2.3 Function Type

```
!dlam.fun<in, out>
```

A value-level function type from `in` to `out`.
Both `in` and `out` are `DlamType`.

---

### 2.4 Polymorphic Type (∀-abstraction)

```
!dlam.forall<body>
```

A polymorphic type representing `∀α. body`, where occurrences of `!dlam.bvar<0>` in `body` refer to the bound type variable.

---

## **3. Natural Number Index Language**

Dlam supports a small family of **natural-number attributes** for dependent shapes or size indices.

```
NatExpr ::= !dlam.nat_lit<IntData>
          | !dlam.nat.add<NatExpr, NatExpr>
          | !dlam.nat.mul<NatExpr, NatExpr>
```

* `!dlam.nat_lit<n>` A literal natural number (requires n ≥ 0).
* `!dlam.nat.add<a,b>` Addition.
* `!dlam.nat.mul<a,b>` Multiplication.

Example:

```
!dlam.nat.mul<!dlam.nat.add<!dlam.nat_lit<2>, !dlam.nat_lit<3>>, !dlam.nat_lit<2>>
```

These expressions can appear as parameters inside other attributes (e.g., vector sizes).

---

## **4. Operations**

All Dlam operations follow MLIR syntax:

```
"op-name" (operands) [attributes] [regions] : (input-types) -> (result-types)
```

### 4.1 `dlam.vlambda` — Value-level λ-abstraction

```
%f = "dlam.vlambda"()
      <{ funAttr = !dlam.fun<A, B> }>
      ({
        ^bb0(%x: A):
          "dlam.vreturn"(%x) <{expected = A}> : (A) -> ()
      }) : () -> (!dlam.fun<A, B>)
```

**Verifier:**

* One region with exactly one block.
* One argument whose type = `funAttr.in`.
* `res.typ == funAttr`.

---

### 4.2 `dlam.vreturn` — Value-level return

```
"dlam.vreturn"(%x) <{expected = T}> : (T) -> ()
```

Terminates a value region.

**Verifier:** `value.typ == expected`.

---

### 4.3 `dlam.tlambda` — Type-level λ (∀-introduction)

```
%F = "dlam.tlambda"() ({
  ^bb0():
    ... "dlam.treturn"(%v) ...
}) : () -> (!dlam.forall<T>)
```

**Verifier:**

* One block with **zero** arguments.
* `res.typ` is `!dlam.forall<…>`.

---

### 4.4 `dlam.treturn` — Type-level return

```
"dlam.treturn"(%v) <{expected = T}> : (T) -> ()
```

**Verifier:** `value.typ == expected`.

---

### 4.5 `dlam.tapply` — Type-level application (∀-elimination)

```
%h = "dlam.tapply"(%G) <{argType = !dlam.const<i32>}>
      : (!dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>)
        -> (!dlam.fun<!dlam.const<i32>, !dlam.const<i32>>)
```

**Verifier:**
If `polymorphicFun.typ == !dlam.forall<body>`,
then `res.typ == instantiate(body, argType)` (via de Bruijn substitution).

---

### 4.6 `dlam.vapply` — Value-level application

```
%r = "dlam.vapply"(%f, %x)
```

**Verifier:**
If `fun.typ == !dlam.fun<A, B>` then `arg.typ == A` and `res.typ == B`.

---

### 4.7 `dlam.vconst` — Value constant

```
%c = "dlam.vconst"(#builtin.int_attr<42 : i64>)
      : (!dlam.const<i32>)
```

Produces a constant value.
**Verifier:**
`res.typ == !dlam.const<T>` and the literal’s kind matches `T`
(e.g., `IntData` ↔ `i32`, `FloatData` ↔ `f32`).

---

## **5. Example Programs**

### 5.1 Polymorphic Identity (∀α. α → α)

```
%F = "dlam.tlambda"() ({
^bb0():
  %v = "dlam.vlambda"() <{funAttr = !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>}> ({
  ^bb1(%x: !dlam.bvar<0>):
    "dlam.vreturn"(%x) <{expected = !dlam.bvar<0>}> : (!dlam.bvar<0>) -> ()
  }) : () -> (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>)
  "dlam.treturn"(%v) <{expected = !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>}>
    : (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>) -> ()
}) : () -> (!dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>)
```

---

### 5.2 Type Application (Before Monomorphization)

```
%F = "dlam.tlambda"() ({
^bb0():
  %G = "dlam.tlambda"() ({
  ^bb1():
    %v = "dlam.vlambda"() <{funAttr = !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>}> ({
    ^bb2(%x: !dlam.bvar<0>):
      "dlam.vreturn"(%x) <{expected = !dlam.bvar<0>}> : (!dlam.bvar<0>) -> ()
    }) : () -> (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>)
    "dlam.treturn"(%v) <{expected = !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>}>
      : (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>) -> ()
  }) : () -> (!dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>)
  %h = "dlam.tapply"(%G) <{argType = !dlam.bvar<0>}>
        : (!dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>)
          -> (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>)
  "dlam.treturn"(%h) <{expected = !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>}>
    : (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>) -> ()
}) : () -> (!dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>)
```

---

### 5.3 Monomorphized Form

```
%F = "dlam.tlambda"() ({
^bb0():
  %h = "dlam.vlambda"() <{funAttr = !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>}> ({
  ^bb1(%x: !dlam.bvar<0>):
    "dlam.vreturn"(%x) <{expected = !dlam.bvar<0>}> : (!dlam.bvar<0>) -> ()
  }) : () -> (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>)
  "dlam.treturn"(%h) <{expected = !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>}>
    : (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>) -> ()
}) : () -> (!dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>)
```

---

### 5.4 Nat Expression Examples

```
!dlam.nat_lit<2>
!dlam.nat.add<!dlam.nat_lit<2>, !dlam.nat_lit<3>>
!dlam.nat.mul<!dlam.nat.add<!dlam.nat_lit<2>, !dlam.nat_lit<3>>, !dlam.nat_lit<2>>
```

---

### 5.5 Value Constants

```
%0 = "dlam.vconst"(#builtin.int_attr<42 : i64>)
      : (!dlam.const<i32>)
```

---

## **6. Semantics and Invariants**

* **Binders** — Each `TLambda` introduces a type variable bound by de Bruijn depth.
  `!dlam.bvar<0>` refers to the innermost enclosing binder.

* **DBI Operations** — `shift`, `subst`, and `instantiate` behave as standard for de Bruijn indices.
  Verification ensures that `TApply.res.typ == instantiate(body, argType)`.

* **Monomorphization Pass** — Finds `tapply(G, τ)`, substitutes `τ` through the body, inserts the specialized `vlambda`, replaces uses, and removes now-dead polymorphic abstractions.

* **Const Types & Values** — `!dlam.const<T>` classifies literal runtime values of machine type `T`.
  The `dlam.vconst` operation introduces such constants; no separate “return-const-type” op is required.