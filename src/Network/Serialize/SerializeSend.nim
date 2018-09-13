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

#SetOnce lib.
import SetOnce

#Serialize a Send.
proc serialize*(send: Send): string {.raises: [ValueError, Exception].} =
    result =
        send.nonce.toString(255) !
        Address.toBN(send.output).toString(255) !
        send.amount.toString(255)

    if send.signature.len != 0:
        result =
            Address.toBN(send.sender).toString(255) !
            result !
            send.proof.toString(255) !
            send.signature.toBN(16).toString(255)

        result = result.toBN(256).toString(253)
