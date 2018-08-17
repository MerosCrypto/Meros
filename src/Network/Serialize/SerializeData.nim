#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#Errors lib.
import ../../lib/Errors

#Node and Data objects.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/DataObj

#Common serialization functions.
import common

#String utils standard lib.
import strutils

#Serialization function.
proc serialize*(data: Data): string =
    result = data.getNonce().toString(255)
    for i in data.getData():
        result &= delim & $i.toHex()

    if not data.getProof().isNil:
        result &= delim &
            data.getProof().toString(255) !
            data.getSignature().toBN(16).toString(255)
