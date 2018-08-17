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
proc serialize*(tx: Transaction): string {.raises: [ValueError, Exception].} =
    result =
        tx.getNonce().toString(255) !
        Address.toBN(tx.getInput()).toString(255) !
        Address.toBN(tx.getInput()).toString(255) !
        tx.getAmount().toString(255) & delim

    if not tx.getProof().isNil:
        result &= delim &
            tx.getProof().toString(255) !
            tx.getSignature().toBN(16).toString(255)
