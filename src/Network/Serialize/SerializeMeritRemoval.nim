#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#Address library.
import ../../Wallet/Address

#MeritRemoval object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/MeritRemovalObj

#Common serialization functions.
import common

#Serialize a MeritRemoval.
proc serialize*(mr: MeritRemoval): string =
    result =
        mr.getNonce().toString(255) !
        mr.getFirst().toBN(16).toString(255) !
        mr.getSecond().toBN(16).toString(255)

    if mr.getHash().len != 0:
        result =
            Address.toBN(mr.getSender()).toString(255) !
            result !
            mr.getSignature().toBN(16).toString(255)

        result = result.toBN(256).toString(253)
