# Dlam De Bruijn Dialect

This project implements the Dlam dialect, a small dependently typed λ-calculus using de Bruijn indices, built on top of the [ScaIR](https://github.com/edin-dal/scair) framework.

The dialect includes:

* Function types (`!dlam.fun`)
* Polymorphic types (`!dlam.forall`)
* De Bruijn type variables (`!dlam.bvar<k>`)
* Indexed vector types
* Natural-number expressions for dependent sizes
* Value-level and type-level λ-abstractions and applications

## Build and Test

This project uses the build tool [Mill](https://mill-build.org/mill/index.html).

### Compile:

```bash
./mill dlam_de_bruijn.compile
```

### Run tests:

```bash
./mill dlam_de_bruijn.test
```
