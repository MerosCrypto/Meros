#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#MeritRemoval object.
import ../../DB/Lattice/objects/NodeObj
import ../../DB/Lattice/objects/MeritRemovalObj

#Common serialization functions.
import common

#Serialize a MeritRemoval.
proc serialize*(mr: MeritRemoval): string =
    result =
        mr.getNonce().toString(255) !
        (
            mr.getFirst().getHash() &
            mr.getSecond().getHash()
        ).toBN(16).toString(255)

    if mr.getHash().len == 128:
        result &= delim & mr.getSignature().toBN(16).toString(255)
