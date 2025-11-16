## Polymorphic Identity Examples with de Bruijn Indices
ΛT. λ(x:T).x
```mlir
%F = dlam.tlambda ()

      : !dlam.forall<!dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>>> {

  %v = dlam.vlambda (%x : !dlam.bvar<0>)

            : !dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>> {

        dlam.vreturn %x: !dlam.bvar<0>;

  }

  dlam.treturn %v : !dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>>

}
```
------
ΛT.ΛU.λ(x:U).x
```mlir
%F = dlam.tlambda ()

      : !dlam.forall<!dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>>> {

    %G = dlam.tlambda ()

      : !dlam.forall<!dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>>> {

      %v = dlam.vlambda (%x : !dlam.bvar<0>)

              : !dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>> {

          dlam.vreturn %x: !dlam.bvar<0>;

      }

      dlam.treturn %v : !dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>>

    }

    %h = dlam.tapply %G <!dlam.bvar<0>> : !dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>>

    dlam.treturn %h : !dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>>

}
```