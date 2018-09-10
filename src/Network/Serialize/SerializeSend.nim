#Numerical libs.
import BN
import ../../lib/Base

#Address lib.
import ../../Wallet/Address

#Node and Send object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/SendObj

#Common serialization functions.
import SerializeCommon

#Serialize a Send.
proc serialize*(send: Send): string {.raises: [ValueError, Exception].} =
    result =
        send.getNonce().toString(255) !
        Address.toBN(send.getOutput()).toString(255) !
        send.getAmount().toString(255)

    if send.getSignature().len != 0:
        result =
            Address.toBN(send.getSender()).toString(255) !
            result !
            send.getProof().toString(255) !
            send.getSignature().toBN(16).toString(255)

        result = result.toBN(256).toString(253)
