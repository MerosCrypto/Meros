#Errors lib.
import ../../../../../lib/Errors

#MintOutput object.
import ../../../..//Transactions/objects/TransactionObj

#Base serialization function.
method serialize*(
    output: Output
): string {.base, forceCheck: [].} =
    doAssert(false, "Output serialize method called.")
