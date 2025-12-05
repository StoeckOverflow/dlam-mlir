# Dependent Lambda Calculus in ScaIR

This repository contains notes and prototype implementations exploring dependent types in MLIR using [ScaIR](https://github.com/edin-dal/scair). It provides two independent dialect designs, each illustrating a different approach to representing dependent types inside MLIR:

## 1. `dlam_de_bruijn` — Baseline λ-Calculus with De Bruijn Indices

A minimal dependently typed λ-calculus encoded in MLIR using:

* de Bruijn indices (`!dlam.bvar<k>`) for type variables,
* explicit polymorphism (`!dlam.forall`),
* conventional value/type λ (`dlam.vlambda`, `dlam.tlambda`),
* dependent vector types with natural-number expressions.

This dialect uses only core MLIR ideas (no SSA values inside types) and serves as a baseline / control design for type theory in ScaIR.

Source code lives both in this repository and in the dedicated ScaIR branch:
[https://github.com/StoeckOverflow/scair/tree/dlam_de_bruijn](https://github.com/StoeckOverflow/scair/tree/dlam_de_bruijn)


## 2. `dlam_ssa_in_types` — Dependent Types with SSA Values

A research dialect that will **integrate SSA values directly into type attributes**, enabling:

* dependent types referring to runtime SSA values,
* dependent vector lengths such as `!dlam.dep<vec<%n, i32>>`,
* value-level dependency tracking,
* a symbolic resolver pass converting `%name` → `Value`,
* a dependent-type verifier checking dominance and undefined values.

This design extends MLIR in ways not currently supported by upstream MLIR, and prototypes how dependent typing could be supported natively inside a real IR.

Source code is located in its dedicated branch:
[https://github.com/StoeckOverflow/scair/tree/dlam-ssa-types](https://github.com/StoeckOverflow/scair/tree/dlam-ssa-types)

# Building and Testing

This project uses [Mill](https://mill-build.org/mill/index.html) as build tool:

## Compile

```bash
./mill dlam_de_bruijn.compile
```

## Run unit tests

```bash
./mill dlam_de_bruijn.test
```

## Run FileCheck tests

After compiling:

```bash
out/dlam_de_bruijn/launcher.dest/run dlam_de_bruijn/test/filecheck/<testfile>
```

If the launcher becomes stale, rebuild it:

```bash
./mill dlam_de_bruijn.launcher
```
