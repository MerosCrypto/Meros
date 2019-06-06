#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Transaction object.
import objects/TransactionObj
export TransactionObj

#Get a TX's hash, creating one if there isn't one yet.
proc hash*(
    tx: Transaction
): Hash[384] {.forceCheck: [].} =
    if not hashed:
        hash = Blake384(tx.serializeHash())
        hashed = true
    result = hash

#Set the signature field.
func `signature=`(
    tx: Transaction,
    sig: EdSignature
) {.forceCheck: [].} =
    discard tx.hash
    tx.signature = sig
