// Experimental, does not work
// RUN: scair-opt -p=monomorphize | filecheck %s

builtin.module {
  %0 = "dlam.tlambda"() ({
  ^bb0(%1: !dlam.type):
    %2 = "dlam.tlambda"() ({
    ^bb1(%3: !dlam.type):
      %4 = "dlam.vlambda"() <{funAttr = !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>}> ({
      ^bb2(%5: !dlam.bvar<0>):
        "dlam.vreturn"(%5) <{expected = !dlam.bvar<0>}> : (!dlam.bvar<0>) -> ()
      }) : () -> (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>)
      "dlam.treturn"(%4) <{expected = !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>}> : (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>) -> ()
    }) : () -> (!dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>)
    %6 = "dlam.tapply"(%2) <{argType = !dlam.bvar<0>}> : (!dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>) -> (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>)
    "dlam.treturn"(%6) <{expected = !dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>}> : (!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>) -> ()
  }) : () -> (!dlam.forall<!dlam.fun<!dlam.bvar<0>, !dlam.bvar<0>>>)
}

// CHECK-NOT: dlam.tapply
// CHECK: "dlam.vlambda"() <{funAttr = !dlam.fun<
