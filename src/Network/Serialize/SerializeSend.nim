#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#Address library.
import ../../Wallet/Address

#Send object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/SendObj

#Common serialization functions.
import common

#Serialize a Send.
proc serialize*(send: Send): string {.raises: [ValueError, Exception].} =
    result =
        send.getNonce().toString(255) !
        Address.toBN(send.getOutput()).toString(255) !
        send.getAmount().toString(255)

    if send.getHash().len != 0:
        result =
            Address.toBN(send.getSender()).toString(255) !
            result !
            send.getProof().toString(255) !
            send.getSignature().toBN(16).toString(255)
