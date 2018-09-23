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
proc serialize*(send: Send): string {.raises: [ValueError].} =
    result =
        !send.nonce.toString(256) &
        !Address.toBN(send.output).toString(256) &
        !send.amount.toString(256)

    if send.signature.len != 0:
        result =
            !Address.toBN(send.sender).toString(256) &
            result &
            !send.proof.toString(256) &
            !send.signature.toBN(16).toString(256)
