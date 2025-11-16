package scair.passes

import scair.MLContext
import scair.ir.*
import scair.transformations.*
import scair.dialects.builtin.*

final class MonomorphizePass(ctx: MLContext) extends ModulePass:
  override val name: String = "monomorphize"

  override def transform(op: Operation): Operation =
    op match
      case m: ModuleOp =>
        Monomorphize.run(m)
      case other => other
