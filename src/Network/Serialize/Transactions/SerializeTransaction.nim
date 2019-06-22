#Errors lib.
import ../../../lib/Errors

#Transaction object.
import ../../../Database/Transactions/objects/TransactionObj

#Base serialize functions.
method serializeHash*(
    tx: Transaction
): string {.base, forceCheck: [].} =
    doAssert(false, "Transaction serializeHash method called.")

method serialize*(
    tx: Transaction
): string {.base, forceCheck: [].} =
    doAssert(false, "Transaction serialize method called.")
