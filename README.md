# Dependent Lambda Calculus in ScaIR

This project contains some notes and implementations refgarding implementing a small dependently type lambda calculus. 
It implements two dialects, which are built on top of [ScaIR](https://github.com/edin-dal/scair):

1. the Dlam_de_bruijn Dialect, which is the baseline approach using de Bruijn indices, built on top of ScaIR, using only the core MLIR internals. The code can be found in this repo and also in my seperate branch of my ScaIR fork [dlam_de_bruijn](https://github.com/StoeckOverflow/scair/tree/dlam_de_bruijn).
    
2. the Dlam_ssa_in_types Dialect, which integrates SSA values as types for enabling dependent types in core MLIR, here also prototyped in ScaIR. The dialect is implemented in my seperate branch of my ScaIR fork [dlam-ssa-types](https://github.com/StoeckOverflow/scair/tree/dlam-ssa-types).


## Compile and test the local code

This project uses the build tool [Mill](https://mill-build.org/mill/index.html).

### Compile:

```bash
./mill dlam_de_bruijn.compile
```

### Run tests:

```bash
./mill dlam_de_bruijn.test
```

### Run filecheck tests:

After compiling run:

```bash
out/dlam_de_bruijn/launcher.dest/run dlam_de_bruijn/test/filecheck/<test>
```

In case something does not work, rebuilding the launcher with `./mill dlam_de_bruijn.launcher` helps.









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
