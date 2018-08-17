#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#Address library.
import ../../Wallet/Address

#Receive object.
import ../../Database/Lattice/objects/NodeObj
import ../../Database/Lattice/objects/ReceiveObj

#Common serialization functions.
import common

#Serialize a Receive.
proc serialize*(recv: Receive): string {.raises: [ValueError, Exception].} =
    result =
        recv.getNonce().toString(255) !
        Address.toBN(recv.getInputAddress()).toString(255) !
        recv.getInputNonce().toString(255) !
        recv.getAmount().toString(255)

    if recv.getHash().len != 0:
        result =
            Address.toBN(recv.getSender()).toString(255) !
            result !
            recv.getSignature().toBN(16).toString(255)
