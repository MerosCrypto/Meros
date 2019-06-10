#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

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
) {.forceCheck: [].} =
    discard

proc load*(
    db: DB,
    hash: Hash[384]
): Transaction {.forceCheck: [].} =
    discard

proc commit*(
    db: DB
) {.forceCheck: [].} =
    discard
