# **Dlam Dialect Specification**

## **1. Overview**

The **`dlam` dialect** implements a small dependently typed λ-calculus with:

* Higher-order types (`!dlam.fun`)
* Explicit polymorphism (`!dlam.forall`)
* **De Bruijn indices** for type variables (`!dlam.bvar<k>`)
* A small natural-number expression sublanguage for indexed types

All types are encoded as **attributes**, and programs are encoded as **MLIR operations** with regions for binders.

The dialect is registered with:

```scala
val DlamDialect = summonDialect[
  (DlamTypeType, DlamBVarType, DlamForAllType), // attributes
  (VLambda, VReturn, TLambda, TReturn, TApply, VApply) // operations
](Seq(DlamFunType))
```

---

# **2. Type Attributes**

```
DlamType ::=
    !dlam.type
  | !dlam.bvar<k>
  | !dlam.fun<in, out>
  | !dlam.forall<body>
  | !dlam.vec<len, elem>
```

All type attributes extend `DlamType`.

---

## **2.1 Universe**

### **`!dlam.type`**

Represents the universe of all Dlam types — analogous to `Type : Type` in type theory but treated as an attribute.

---

## **2.2 De Bruijn Type Variable**

### **`!dlam.bvar<k>`**

A de Bruijn index referencing a type binder:

* `k = 0` refers to the innermost enclosing `TLambda`
* `k = 1` refers to the next-outer binder, etc.

```mlir
!dlam.bvar<0>
```

---

## **2.3 Function Type**

### **`!dlam.fun<in, out>`**

A value-level function type.

```mlir
!dlam.fun<!dlam.type, !dlam.type>
```

Parser accepts:

```
<in, out>
```

via:

```scala
P("<" ~ p.Type ~ "," ~ p.Type ~ ">")
```

---

## **2.4 Polymorphic Type**

### **`!dlam.forall<body>`**

Represents polymorphism:

```
∀. body
```

The body may contain `!dlam.bvar<0>` referring to the newly introduced type variable.

---

## **2.5 Vector Type (Indexed)**

### **`!dlam.vec<len, elem>`**

A dependent vector type of length `len` and element type `elem`.

Examples:

```
!dlam.vec<!dlam.nat_lit<3>, i32>
```

---

# **3. Natural Number Expression Attributes**

```
NatExpr ::=
    !dlam.nat_lit<n>
  | !dlam.nat.add<a, b>
  | !dlam.nat.mul<a, b>
```

Used for dependent indexing (vector lengths, dimensions, etc.).

### **3.1 Literal**

```
!dlam.nat_lit<n>
```

Verifier enforces `n ≥ 0`.

### **3.2 Addition**

```
!dlam.nat.add<a, b>
```

### **3.3 Multiplication**

```
!dlam.nat.mul<a, b>
```

All `NatExpr` are also valid `TypeAttribute`s, so they can appear inside other type constructors.

---

# **4. De Bruijn Index Utilities**

The dialect defines standard operations for managing de Bruijn indices.

## **4.1 `shift(d, c, t)`**

Increase all indices ≥ `c` by `d`.

Used when entering/exiting binders.

## **4.2 `subst(c, s, t)`**

Substitute:

```
bvar(c) := s
```

with index-adjustment for variables above `c`.

## **4.3 `instantiate(fa, arg)`**

Instantiates:

```
∀. body
```

with a concrete type:

```
instantiate(∀.body, arg) = subst(0, arg, body)
```

Correctly shifts `arg` as required.

---

# **5. Operations**

Only **six** operations exist:

```
dlam.vlambda
dlam.vreturn
dlam.tlambda
dlam.treturn
dlam.tapply
dlam.vapply
```

There is **no** `vconst`.

---

## **5.1 `dlam.vlambda` — Value-level λ**

```
%f = "dlam.vlambda"()
      <{ funAttr = !dlam.fun<A, B> }>
      ({
        ^bb0(%x: A):
          "dlam.vreturn"(%x) <{expected = A}> : (A) -> ()
      }) : () -> (!dlam.fun<A, B>)
```

### Verifier:

* One region, one block.
* Block must have **exactly one argument**.
* Argument type must equal `funAttr.in`.
* The operation result type must equal `funAttr`.

---

## **5.2 `dlam.vreturn` — Return from a value region**

```
"dlam.vreturn"(%x) <{expected = T}> : (T) -> ()
```

Terminator for regions of `VLambda`.

### Verifier:

```
value.typ == expected
```

---

## **5.3 `dlam.tlambda` — Type-level λ (∀-intro)**

```
%F = "dlam.tlambda"() ({
  ^bb0():
    ... type-producing operations ...
}) : () -> (!dlam.forall<body>)
```

### Verifier:

* One block **with zero arguments**.
* Result type is `!dlam.forall<_>`.

---

## **5.4 `dlam.treturn` — Type-level return**

```
"dlam.treturn"(%v) <{expected = T}> : (T) -> ()
```

Terminator for `TLambda` bodies.

### Verifier:

```
value.typ == expected
```

---

## **5.5 `dlam.tapply` — Type-level application (∀-elim)**

```
%h = "dlam.tapply"(%G) <{argType = T}>
      : (!dlam.forall<body>) -> (instantiate(body, T))
```

Where:

```
instantiate(body, T) = DBI.subst(0, T, body)
```

### Verifier:

* `polymorphicFun.typ` must be `DlamForAllType`.
* Result type must equal computed instantiation.

---

## **5.6 `dlam.vapply` — Value-level application**

```
%r = "dlam.vapply"(%f, %x)
      : (!dlam.fun<A, B>) -> B
```

### Verifier:

```
f.typ == !dlam.fun<A, B>
x.typ == A
res.typ == B
```

---

# **6. Examples**

## **6.1 Polymorphic Identity**

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

## **6.2 Type Application**

```
%h = "dlam.tapply"(%G) <{argType = !dlam.bvar<0>}>
      : (!dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>)
        -> (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>)
```

---

# **7. Semantics Summary**

* **Value-level λ** → Regions bind *term variables*.
* **Type-level λ (∀)** → Regions bind *type variables* via de Bruijn indices.
* **Type application** automatically performs **capture-avoiding substitution**.
* Natural number expressions permit **lightweight dependent indexing**.
