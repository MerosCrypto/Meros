import ../../../lib/Errors

import ../../../Database/Transactions/objects/TransactionObj

method serializeHash*(
  tx: Transaction
): string {.base, forceCheck: [].} =
  panic("Transaction serializeHash method called.")

method serialize*(
  tx: Transaction
): string {.base, forceCheck: [].} =
  panic("Transaction serialize method called.")
