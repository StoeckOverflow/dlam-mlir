# Dlam Dialect Notes

## 1. Purpose of the Dlam Dialect

The `dlam` dialect extends ScaIR with dependent typing.
The dialect is implemented in a seperate branch of my ScaIR fork [dlam-ssa-types](https://github.com/StoeckOverflow/scair/tree/dlam-ssa-types).

It introduces:

### 1.1 Type-level constructs

* `dlam.tlambda` — type-level lambda abstraction
* `dlam.tapply` — instantiate a type-level lambda
* `dlam.treturn` — return from a type-level lambda

### 1.2 Value-level constructs

* `dlam.vlambda` — value-level lambda abstraction
* `dlam.vreturn` — return from a value-level lambda

### 1.3 Dependent types

Types may depend on:

* SSA values (`Value`)
* SSA types (via type-level lambdas)
* Natural-number expressions (lengths of vectors, etc.)

This allows IR such as:

```
%len = dlam.nat_source() : i32
%x   : !dlam.dep<vec<%len, i32>>
```

Here the type of `%x` literally contains a reference to the SSA value `%len`.
This model treats dependent-type expressions as genuine consumers of the SSA use–def graph.

## 2. Dependent Types in Dlam

Dependent types are encoded using an embedded expression language. They are represented by the attribute:

```
DepType(expr: DepTypeExpr)
```

### 2.1 Dependent Type Expressions

```
DepTypeExpr =
  TEConst(pure MLIR type)
  TEFun(input, output)
  TEForall(body)
  TEVec(length: NatExprExpr, elem: DepTypeExpr)
  TEValueRef(v: Value)
```

* `TEConst` embeds a normal ScaIR/MLIR TypeAttribute.
* `TEValueRef` holds a real IR Value, enabling true SSA-dependent typing.

#### Example:

```
!dlam.dep<vec<%len, i32>>
```

Internal Encoding:

```
TEVec(
  len  = NEFromValue(%3),
  elem = TEConst(i32)
)
```

### 2.2 Natural Expressions Used in Types

Natural-number expressions used in types also form a small AST:
```
NatExprExpr =
  NELit(int)
  NEAdd(a, b)
  NEMul(a, b)
  NEFromValue(v: Value)             // SSA value providing a natural number
```

#### Example:

```
%size = "dlam.nat_source"() : () -> i32
!dlam.dep<vec<%size + 4, i32>>
```

Internal Encoding:

```
NEAdd(
  NEFromValue(%size),
  NELit(4)
)
```

## 3. The Dependent-Type Verifier Pass

File: *DependentTypeVerifier.scala*

### 3.1 Purpose

The verifier checks the semantic correctness of dependent types:

#### It checks:

1. All values referenced inside types dominate their use
   If a type refers to `%n`, then `%n` must be defined *before* the operation that uses the type.
   Example of an invalid IR:
    ```
    %f = "dlam.vlambda"() <{funAttr = !dlam.dep<vec<%n, i32>>}> ...
    %n = "dlam.nat_source"() : () -> i32   // too late
    ```
    The verifier emtis an exception.

2. Structural correctness
    * function types (`TEFun`)
    * type-level abstractions (`TEForall`)
    * vector types (`TEVec`)
    * natural expressions (`NEAdd`, `NEMul`, `NEFromValue`)
    * block argument and operation result types

Dominance policy
* Block arguments dominate their block and nested regions.
* Operation results must appear before their use in the same block.
* Values from outer blocks dominate inner regions (standard structured-control semantics).

## 4. Parsing Dependent Types

The `DepTypeParser` integrates directly with ScaIR’s SSA-use parser.
Whenever the parser encounters `%x` inside a dependent type or nat-expression, it immediately resolves it to the corresponding `Value`.

For example:

```
vec<%len, i32>
```

parses to:

```
TEVec(
  len  = NEFromValue(valueForLen),
  elem = TEConst(i32)
)
```

Thus dependent types are guaranteed to contain **real SSA references** after parsing.

## 5. Printing Dependent Types

The `DepTypePrinter` prints dependent-type expressions structurally.

Key behavior:

* `TEValueRef(v)` prints the SSA name of `v`.
* `NEFromValue(v)` prints `%<id>`.
* Pure types delegate to the regular ScaIR printer.

Example internal expression:

```
TEVec(
  len  = NEFromValue(%0),
  elem = TEConst(i32)
)
```

prints as:

```mlir
vec<%0, i32>
```

Since all value references are real SSA values, printing integrates seamlessly with ScaIR’s normal SSA naming.

## 6. Summary of the Compilation Pipeline

| Stage        | Description                                                                                  |
| ------------ | -------------------------------------------------------------------------------------------- |
| **Parser**   | Builds IR; dependent types already contain `Value` references (`TEValueRef`, `NEFromValue`). |
| **Verifier** | Ensures dependent types are well-formed and dominance-correct.                               |
| **Printer**  | Prints dependent types using normal SSA name assignment.                                     |
