# Dlam Dialect Specification

## 1. Overview

The `dlam` dialect implements a small dependently typed λ-calculus with:

* Higher-order types (`!dlam.fun`)
* Explicit polymorphism (`!dlam.forall`)
* De Bruijn indices for type variables (`!dlam.bvar<k>`)
* A small natural-number expression sublanguage for indexed types

All Dlam types are represented as MLIR type attributes, and programs are represented as MLIR operations with regions for binders.

The code can be found in this repo and also in my seperate branch of my ScaIR fork [dlam_de_bruijn](https://github.com/StoeckOverflow/scair/tree/dlam_de_bruijn).

# 2. Type Attributes

```
DlamType ::=
    !dlam.type
  | !dlam.bvar<k>
  | !dlam.fun<in, out>
  | !dlam.forall<body>
  | !dlam.vec<len, elem>
```

All type attributes extend `DlamType`.

## 2.1 Universe

### `!dlam.type`

Represents the universe of all Dlam types. It is the type of type-level values manipulated by Dlam operations (e.g. for type abstraction/application), but is itself just a type attribute.

## 2.2 De Bruijn Type Variable

### `!dlam.bvar<k>`

Represents a type variable via a de Bruijn index:

* `!dlam.bvar<0>` refers to the innermost enclosing type binder (the nearest dlam.tlambda).
* `!dlam.bvar<1>` refers to the next outer binder, and so on.

The verifier for `!dlam.bvar<k>` is purely structural; correctness of indices is enforced at the operation level (dlam.tlambda, dlam.tapply) via shifting / substitution.

## 2.3 Function Type

### `!dlam.fun<in, out>`

```mlir
!dlam.fun<!dlam.type, !dlam.type>
!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>
!dlam.fun<!dlam.vec<!dlam.nat_lit<4>, i32>, !dlam.vec<!dlam.nat_lit<4>, i32>>
```

Represents a value-level function type from `in` to `out`.

* Both in and out are arbitrary DlamType.
* Used by `dlam.vlambda`, `dlam.vapply`, and type-level constructs (`dlam.tlambda`, `dlam.tapply`).

## 2.4 Polymorphic Type

### `!dlam.forall<body>`

```
!dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>
```

Represents a type-level universal quantification:

* Logically: `∀. body`
* Syntactically: `body` may contain `!dlam.bvar<0>` referencing the type variable introduced by this forall.
* Nested foralls are represented by nesting and using higher `!dlam.bvar<k>` indices.

This connective is introduced by `dlam.tlambda` and eliminated by `dlam.tapply`.

## 2.5 Vector Type (Indexed)

### `!dlam.vec<len, elem>`

```
!dlam.vec<!dlam.nat_lit<3>, i32>
!dlam.vec<!dlam.nat.add<!dlam.nat_lit<2>, !dlam.nat_lit<2>>, i32>
!dlam.vec<!dlam.nat.mul<!dlam.nat_lit<2>, !dlam.nat_lit<3>>, !dlam.bvar<0>>
```

Represents a vector of length `len` with element type `elem`:

* `len` is a `NatExpr` attribute (see Section 3).
* `elem` is a `DlamType` attribute.

There is no additional semantic restriction beyond the shape; it is up to later passes to interpret and/or check specific arithmetic properties if desired.

# 3. Natural Number Expression Attributes

Natural number expressions (`NatExpr`) are used as indices inside types, e.g. for vector lengths.

```
NatExpr ::=
    !dlam.nat_lit<n>
  | !dlam.nat.add<a, b>
  | !dlam.nat.mul<a, b>
```

Each of these is a `TypeAttribute` and can be used wherever a natural expression is expected (e.g. in `!dlam.vec`).

### 3.1 Literal

```
!dlam.nat_lit<n>
```

Represents a non-negative integer literal. The verifier enforces `n ≥ 0`.

### 3.2 Addition

```
!dlam.nat.add<a, b>
```

Represents the sum of two natural expressions.

### 3.3 Multiplication

```
!dlam.nat.mul<a, b>
```

Represents the product of two natural expressions.

## 4. De Bruijn Index Operations (Meta-Level)

At the meta-level, the dialect defines standard utilities for manipulating de Bruijn indices in `DlamType` and `NatExpr` structures. These are used internally by type-level operations such as `dlam.tlambda` and `dlam.tapply`.

### 4.1 `shift(d, c, t)`

Increase all de Bruijn indices ≥ `c` by `d` in a type `t`:

* `d` — shift amount (typically `+1` when entering a binder, `−1` when exiting).
* `c` — cutoff; only indices ≥ `c` are shifted.

This is the usual de Bruijn shift operation, used to maintain correct binding structure when moving types across binders.

### 4.2 `subst(c, s, t)`

Substitute a type `s` for de Bruijn index `c` inside type `t`:

```text
subst(c, s, !dlam.bvar<c>)     = s
subst(c, s, !dlam.bvar<k>)     = !dlam.bvar<k>         if k < c
subst(c, s, !dlam.bvar<k>)     = !dlam.bvar<k-1>       if k > c
subst(c, s, !dlam.fun<A, B>)   = !dlam.fun<subst(c,s,A), subst(c,s,B)>
subst(c, s, !dlam.forall<body>)= !dlam.forall<subst(c+1, shift(1,0,s), body)>
…
```

Exact rules follow the standard de Bruijn substitution scheme, including appropriate shifting of `s` when descending under binders.

### 4.3 `instantiate(fa, arg)`

Instantiate a polymorphic type:

```text
instantiate(!dlam.forall<body>, arg) = subst(0, arg, body)
```

with the usual shift-before-substitute discipline for de Bruijn indices. This is the meta-level semantics of `dlam.tapply`.


## 5. Operations

The de Bruijn Dlam dialect defines the following core operations:

```text
dlam.vlambda   // value-level lambda
dlam.vreturn   // return from value lambda
dlam.tlambda   // type-level lambda (forall-intro)
dlam.treturn   // return from type lambda
dlam.tapply    // type-level application (forall-elim)
dlam.vapply    // value-level application
```

Each operation is an ordinary MLIR operation with regions and blocks used to represent binders.

### 5.1 `dlam.vlambda` — Value-Level Lambda

Value abstraction:

```mlir
%f = "dlam.vlambda"()
      <{ funAttr = !dlam.fun<A, B> }>
      ({
        ^bb0(%x: A):
          "dlam.vreturn"(%x) <{expected = A}> : (A) -> ()
      }) : () -> !dlam.fun<A, B>
```

**Operands:** none
**Results:** one value of type `!dlam.fun<A, B>`
**Regions:** exactly one region with exactly one block

#### Verification

* Region has a single block.
* The block has exactly one argument `%x : A`.
* `funAttr` is a `!dlam.fun<A, B>` attribute.
* Block argument type equals `funAttr.in`.
* Operation result type equals `funAttr`.

### 5.2 `dlam.vreturn` — Value-Level Return

Terminator for `dlam.vlambda` regions:

```mlir
"dlam.vreturn"(%x) <{expected = T}> : (T) -> ()
```

**Operands:**

* `%x` — the value to return

**Results:** none
**Attributes:**

* `expected` — type attribute `T`

#### Verification

* Operand type equals `expected`.
* Operation is used only as terminator of `dlam.vlambda` regions.

### 5.3 `dlam.tlambda` — Type-Level Lambda (∀-Intro)

Type abstraction:

```mlir
%F = "dlam.tlambda"() ({
^bb0():
  // body produces some type-level value %v : !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>
  …
}) : () -> !dlam.forall<body>
```

**Operands:** none
**Results:** one value of type `!dlam.forall<body>`
**Regions:** exactly one region with one block and zero block arguments

#### Verification

* Region has a single block with zero arguments.
* Result type is `!dlam.forall<body>` for some `body : DlamType`.
* Inside `body`, `!dlam.bvar<0>` refers to the type variable bound by this `tlambda`.

### 5.4 `dlam.treturn` — Type-Level Return

Terminator for `dlam.tlambda` regions:

```mlir
"dlam.treturn"(%v) <{expected = T}> : (T) -> ()
```

**Operands:**

* `%v` — type-level value of type `T`

**Results:** none
**Attributes:**

* `expected` — type attribute `T`

#### Verification

* Operand type equals `expected`.
* Operation is used only as terminator of `dlam.tlambda` regions.

### 5.5 `dlam.tapply` — Type-Level Application (∀-Elim)

Apply a polymorphic value to a type argument:

```mlir
%h = "dlam.tapply"(%G)
       <{argType = T}>
       : (!dlam.forall<body>) -> R
```

Intuitively:

```text
G : ∀. body
T : DlamType
R = instantiate(body, T)
```

**Operands:**

* `%G` — polymorphic value of type `!dlam.forall<body>`

**Results:**

* `%h` — value of type `R = instantiate(body, T)`

**Attributes:**

* `argType` — the type argument `T`

#### Verification

* Operand type is `!dlam.forall<body>` for some `body`.
* Compute `R = instantiate(body, argType)` using de Bruijn substitution.
* Result type equals `R`.

### 5.6 `dlam.vapply` — Value-Level Application

Value-level function application:

```mlir
%r = "dlam.vapply"(%f, %x)
       : (!dlam.fun<A, B>, A) -> B
```

**Operands:**

* `%f` — function value of type `!dlam.fun<A, B>`
* `%x` — argument of type `A`

**Results:**

* `%r` — result of type `B`

#### Verification

* Type of `%f` is `!dlam.fun<A, B>`.
* Type of `%x` equals `A`.
* Result type equals `B`.

## 6. Examples

### 6.1 Polymorphic Identity

```mlir
%F = "dlam.tlambda"() ({
^bb0():
  %v = "dlam.vlambda"()
         <{funAttr = !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>}> ({
         ^bb1(%x: !dlam.bvar<0>):
           "dlam.vreturn"(%x)
             <{expected = !dlam.bvar<0>}>
             : (!dlam.bvar<0>) -> ()
       }) : () -> !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>
  "dlam.treturn"(%v)
    <{expected = !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>}>
    : (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>) -> ()
}) : () -> !dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>
```

### 6.2 Type Application

```mlir
%h = "dlam.tapply"(%G)
       <{argType = !dlam.type}>
       : (!dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>)
         -> !dlam.fun<!dlam.type, !dlam.type>
```

Here:

* `%G : !dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>`
* `argType = !dlam.type`
* Result type is `!dlam.fun<!dlam.type, !dlam.type>` obtained by instantiating `bvar<0>` with `!dlam.type`.
