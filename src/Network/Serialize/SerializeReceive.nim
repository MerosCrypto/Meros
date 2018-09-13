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

#SetOnce lib.
import SetOnce

#Serialize a Receive.
proc serialize*(recv: Receive): string {.raises: [ValueError, Exception].} =
    result = recv.nonce.toString(255) & delim

    if recv.inputAddress == "minter":
        result &= delim
    else:
        result &= Address.toBN(recv.inputAddress).toString(255) & delim

    result &= recv.inputNonce.toString(255)

    if recv.signature.len != 0:
        result =
            Address.toBN(recv.sender).toString(255) !
            result !
            recv.signature.toBN(16).toString(255)

        result = result.toBN(256).toString(253)
