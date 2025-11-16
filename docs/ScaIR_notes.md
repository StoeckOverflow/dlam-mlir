## What ScaIR Is (short summary for notes)

**ScaIR = a strongly typed, purely Scala re-implementation of MLIR.**
lets you define compiler intermediate representations (IRs) — operations, types, attributes, and dialects — directly as Scala data types instead of generating C++ code from TableGen

### Core ideas

* operations are `case class`es, dialects are Scala objects
* operands, results, attributes, and regions are generic and checked at compile time (`Operand[A <: Attribute]`, `Result[A <: Attribute]`)
* macros derive boilerplate that MLIR would generate
* IR transformations are ordinary Scala pattern matching
* Ill-typed IRs are impossible to build unless you explicitly use the unverified form

---

## The `DerivedOperation` / `OperationCompanion` system

```scala
case class VLambda(...) extends DerivedOperation["dlam.vlambda", VLambda]
object VLambda extends DerivedOperationCompanion[VLambda]
given DerivedOperationCompanion[VLambda] = VLambda
```

* `DerivedOperation` is a base trait that gives op its typed API (`operands`, `results`, `verify()` …).
* `DerivedOperationCompanion[T]` is a typeclass instance that connects typed case class -> the generic IR layer

  * tells ScaIR how to construct, deconstruct, parse, and print that op
  * replaces MLIR’s TableGen-generated C++ boilerplate

### Why both `object` and `given`

* `object` provides the actual implementation of the companion typeclass
* explicit `given` makes the instance available for Scala’s implicit/typeclass resolution (some builds don’t automatically pick up the object)
* Together they let ScaIR generically “summon” operation definition when registering a dialect:

  ```scala
  val DlamDialect = summonDialect[
    EmptyTuple,
    (VLambda, VReturn, TLambda, TReturn, TApply)
  ](Seq())
  ```

## How to code types in ScaIR
- Every Type is an attribute (case classes)
    - Default Case: use TypeAttributes for Ty
    - Parametrizedattributes --> attribute parametrized with other attributes (0-n attributes)
    - DataAttributes --> Core Data , Int String , wraps core type into attribute --> builtin dialect
        - look into builtin dialect to see how to do type definitions

## Further stuff
- Monomorphization passes: code specification and erasure approach and look at trade-offs