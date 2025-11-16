## Polymorphic Identity Examples with SSA Values in Types
ΛT. λ(x:T).x
```mlir
%F = dlam.tlambda (%T : !dlam.type)

      : !dlam.forall<!dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>>> {

      %v = dlam.vlambda (%x : !dlam.tvar<%T>)

            : !dlam.fun<!dlam.tvar<%T> -> !dlam.tvar<%T>> {

        dlam.vreturn %x: !dlam.tvar<%T>;

  }

  dlam.treturn %v : !dlam.fun<!dlam.tvar<%T> -> !dlam.tvar<%T>>

}
```
------
ΛT.ΛU.λ(x:U).x
```mlir
%F = dlam.tlambda (%T : !dlam.type)

      : !dlam.forall<!dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>>> {

    %G = dlam.tlambda (%U : !dlam.type)

      : !dlam.forall<!dlam.fun<!dlam.bvar<0> -> !dlam.bvar<0>>> {

      %v = dlam.vlambda (%x : !dlam.tvar<%U>)

              : !dlam.fun<!dlam.tvar<%U> -> !dlam.tvar<%U>> {

          dlam.vreturn %x: !dlam.tvar<%U>;

      }

      dlam.treturn %v : !dlam.fun<!dlam.tvar<%U> -> !dlam.tvar<%U>>

    }

    %h = dlam.tapply %G %T : !dlam.fun<!dlam.tvar<%T> -> !dlam.tvar<%T>>

    dlam.treturn %h : !dlam.fun<!dlam.tvar<%T> -> !dlam.tvar<%T>>

}
```