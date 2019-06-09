#Errors lib.
import ../../../lib/Errors

#Transaction object.
import ../../Transactions/objects/TransactionObj

#Serialization libs.
import Serialize/Transactions/SerializeTransaction
import Serialize/Transactions/ParseTransaction

#DB object.
import objects/DBObj
export DBObj

proc save*(
    db: DB,
    tx: Transaction
): {.forceCheck: [].} =
    discard

proc commit*(
    db: DB
) {.forceCheck: [].} =
    discard
