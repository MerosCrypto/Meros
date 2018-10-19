#Util lib.
import ../../lib/Util

#Base lib.
import ../../lib/Base

#Address library.
import ../../Wallet/Address

#Index, Entry, and Receive objects.
import ../../Database/Lattice/objects/IndexObj
import ../../Database/Lattice/objects/EntryObj
import ../../Database/Lattice/objects/ReceiveObj

#Common serialization functions.
import SerializeCommon

#Serialize a Receive.
proc serialize*(recv: Receive): string {.raises: [ValueError].} =
    result = !recv.nonce.toBinary()

    if recv.index.address == "minter":
        result &= char(0)
    else:
        result &= !Address.toBN(recv.index.address).toString(256)

    result &= !recv.index.nonce.toBinary()

    if recv.signature.len != 0:
        result =
            !Address.toBN(recv.sender).toString(256) &
            result &
            !recv.signature
