#Errors lib.
import ../../lib/Errors

#Transaction object.
import ../Transactions/objects/TransactionObj

#Serialization libs.
import Serialize/Transactions/SerializeTransaction
import Serialize/Transactions/ParseTransaction

#DB lib.
import DB

proc save*(
    db: DB,
    tx: Transaction
): {.forceCheck: [].} =
    discard

proc commit*(
    db: DB
) {.forceCheck: [].} =
    discard
