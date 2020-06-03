import ../../../../../lib/Errors

import ../../../../Transactions/objects/TransactionObj

method serialize*(
  output: Output
): string {.base, forceCheck: [].} =
  panic("Output serialize base method called.")
