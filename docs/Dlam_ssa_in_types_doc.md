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

# 2. Dependent Types in Dlam

Dependent types are encoded using an embedded expression language.

## 2.1 Dependent Type Expressions

```
DepTypeExpr =
  TEConst(pure MLIR type)
  TEFun(input, output)               // dependent function type
  TEForall(body)                     // type-level abstraction
  TEVec(length: NatExprExpr, elem: DepTypeExpr)
  TEValueRef(v: Value)               // refers directly to an SSA value
  TENamedValueRef(name: String)      // placeholder during parsing
```

### Example:

```
!dlam.dep<vec<%len, i32>>
```

parses initially as:

```
TEVec(NENamedValueRef("len"), TEConst(i32))
```

and after resolution becomes:

```
TEVec(NEFromValue(%2), TEConst(i32))
```

## 2.2 Natural Expressions Used in Types

```
NatExprExpr =
  NELit(int)
  NEAdd(a, b)
  NEMul(a, b)
  NEFromValue(v: Value)             // refers directly to an SSA value
  NENamedValueRef(name: String)     // placeholder during parsing
```

Example:

```
vec<%len + 4, i32>
```

becomes:

```
NEAdd(
  NEFromValue(%len),
  NELit(4)
)
```

# 3. The Dependent-Type Resolver Pass

File: *DepTypeResolve.scala*

### 3.1 Purpose

During parsing, dependent types may contain symbolic textual references:

```
TENamedValueRef("n")
NENamedValueRef("A")
```

These must be replaced with actual SSA values.

### 3.2 What the resolver does

It:

1. Scans the entire module for SSA values and block arguments.
2. Matches values by textual name (`ssaName`).
3. Rewrites every dependent type expression in-place:

```
TENamedValueRef("n") → TEValueRef(value)
NENamedValueRef("n") → NEFromValue(value)
```

### 3.3 Why this pass exists

ScaIR’s parser builds types before it knows which SSA values exist.
The resolver is the step that “links” dependent types to the actual IR.

### 3.4 Example

Source:

```
!dlam.dep<vec<%len, i32>>
```

After resolution:

```
!dlam.dep<vec<%2, i32>>
```

where `%2` is the actual SSA value defined earlier in the IR.

# 4. The Dependent-Type Verifier Pass

File: *DependentTypeVerifier.scala*

### 4.1 Purpose

The verifier ensures dependent types are *well-formed* and satisfy dominance:

#### It checks:

1. All dependent types are fully resolved
   (i.e., no `TENamedValueRef` or `NENamedValueRef` remain)

2. All values referenced inside types dominate their use
   If a type refers to `%n`, then `%n` must be defined *before* the operation that uses the type.

3. Natural expressions are valid
   No invalid constructs or unresolvable values.

### 4.2 Dominance check example

Invalid:

```
%f = dlam.vlambda (...)  // references %n inside its type
%n = dlam.nat_source()   // defined later → error
```

The verifier emits an exception:

```
Dependent type use not dominated by its definition
```

Valid:

```
%n = dlam.nat_source()
%f = dlam.vlambda (...)  // now safe
```

# 5. Printing Dependent Types

Because dependent types now contain `Value` objects directly, the ScaIR printer automatically prints types using the same SSA naming logic as normal values.

Example:

```
TEValueRef(v0)   →   %0
NEFromValue(v1)  →   %1
```

So:

```
TEVec(NEFromValue(%0), TEConst(i32))
```

prints as:

```
vec<%0, i32>
```

No special logic is required.

# 6. Summary of the Compilation Pipeline

| Stage                | Purpose                                                 |
| -------------------- | ------------------------------------------------------- |
| 1. Parser            | Builds IR, but dependent types contain *symbolic names* |
| 2. Resolver Pass     | Replaces symbolic references with `Value` objects       |
| 3. Verifier Pass     | Ensures dominance and dependent-type well-formedness    |
| 4. Printer           | Prints value-based dependent types normally             |
