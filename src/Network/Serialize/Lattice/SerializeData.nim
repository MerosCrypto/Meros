#Util lib.
import ../../../lib/Util

#Base lib.
import ../../../lib/Base

#Address lib.
import ../../../Wallet/Address

#Entry and Data object.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/DataObj

#Common serialization functions.
import ../SerializeCommon

import strutils
#Serialize a Data.
proc serialize*(data: Data): string {.raises: [ValueError].} =
    result =
        Address.toPublicKey(data.sender) &
        data.nonce.toBinary().pad(INT_LEN) &
        char(data.data.len) & data.data

    if data.signature.len != 0:
        result =
            result &
            data.proof.toBinary().pad(INT_LEN) &
            data.signature
