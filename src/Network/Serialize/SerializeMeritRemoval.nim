#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Address lib.
import ../../Wallet/Address

#Node and MeritRemoval object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/MeritRemovalObj

#Common serialization functions.
import SerializeCommon

#Serialize a MeritRemoval.
proc serialize*(mr: MeritRemoval): string {.raises: [ValueError].} =
    result =
        !newBN(mr.nonce).toString(256) &
        !mr.first.toString() &
        !mr.second.toString()

    if mr.signature.len != 0:
        result =
            !Address.toBN(mr.sender).toString(256) &
            result &
            !mr.signature
