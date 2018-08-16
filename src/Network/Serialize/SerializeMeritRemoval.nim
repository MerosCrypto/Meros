#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#MeritRemoval object.
import ../../DB/Lattice/Node
import ../../DB/Lattice/MeritRemovalObj

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
