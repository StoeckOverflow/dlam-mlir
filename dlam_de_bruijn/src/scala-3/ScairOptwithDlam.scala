package scair.tools

import scair.tools.ScairOptBase
import scair.dialects.dlam_de_bruijn.DlamDialect
import scair.passes.MonomorphizePass

object ScairOptWithDlam extends ScairOptBase:
  override def allDialects =
    super.allDialects :+ DlamDialect

  override def allPasses =
    super.allPasses :+ MonomorphizePass(ctx)

  def main(args: Array[String]): Unit = run(args)
