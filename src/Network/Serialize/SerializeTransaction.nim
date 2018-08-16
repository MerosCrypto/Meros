#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#Errors lib.
import ../../lib/Errors

#Address library.
import ../../Wallet/Address

#Transaction object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/TransactionObj

#Common serialization functions.
import common

#Serialize a Transaction.
proc serialize*(tx: Transaction): string {.raises: [ValueError].} =
    result =
        tx.getNonce().toString(255) !
        tx.getInput().substr(3, tx.getInput().len).toBN(58).toString(255) !
        tx.getOutput().substr(3, tx.getOutput().len).toBN(58).toString(255) !
        tx.getAmount().toString(255) & delim

    for i in tx.getData():
        result = result & $((char) i)

    if not tx.getProof().isNil:
        result &= delim &
            tx.getProof().toString(255) !
            tx.getSignature().toBN(16).toString(255)
