#Numerical libs.
import BN
import ../../lib/Base

#Address library.
import ../../Wallet/Address

#Receive object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/ReceiveObj

#Common serialization functions.
import SerializeCommon

#Serialize a Receive.
proc serialize*(recv: Receive): string {.raises: [ValueError].} =
    result = !recv.nonce.toString(256)

    if recv.inputAddress == "minter":
        result &= !""
    else:
        result &= !Address.toBN(recv.inputAddress).toString(256)

    result &= !recv.inputNonce.toString(256)

    if recv.signature.len != 0:
        result =
            !Address.toBN(recv.sender).toString(256) &
            result &
            !recv.signature.toBN(16).toString(256)
