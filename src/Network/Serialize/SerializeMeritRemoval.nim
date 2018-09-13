#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Address library.
import ../../Wallet/Address

#MeritRemoval object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/MeritRemovalObj

#Common serialization functions.
import SerializeCommon

#SetOnce lib.
import SetOnce

#Serialize a MeritRemoval.
proc serialize*(mr: MeritRemoval): string {.raises: [ValueError, Exception].} =
    result =
        mr.nonce.toString(255) !
        mr.first.toValue().toBN().toString(255) !
        mr.second.toValue().toBN().toString(255)

    if mr.signature.len != 0:
        result =
            Address.toBN(mr.sender).toString(255) !
            result !
            mr.signature.toBN(16).toString(255)

        result = result.toBN(256).toString(253)
