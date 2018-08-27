#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#Address library.
import ../../Wallet/Address

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
        result &= delim & i.toHex()

    if data.getHash().len != 0:
        result =
            Address.toBN(data.getSender()).toString(255) !
            result !
            data.getProof().toString(255) !
            data.getSignature().toBN(16).toString(255)

        result = result.toBN(256).toString(253)
