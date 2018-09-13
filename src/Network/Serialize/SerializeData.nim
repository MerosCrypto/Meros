#Numerical libs.
import BN
import ../../lib/Base

#Address library.
import ../../Wallet/Address

#Node and Data objects.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/DataObj

#Common serialization functions.
import SerializeCommon

#SetOnce lib.
import SetOnce

#String utils standard lib.
import strutils

#Serialization function.
proc serialize*(data: Data): string {.raises: [ValueError, Exception].} =
    result = data.nonce.toString(255)
    for i in data.data:
        result &= delim & i.toHex()

    if data.signature.len != 0:
        result =
            Address.toBN(data.sender).toString(255) !
            result !
            data.proof.toString(255) !
            data.signature.toBN(16).toString(255)

        result = result.toBN(256).toString(253)
