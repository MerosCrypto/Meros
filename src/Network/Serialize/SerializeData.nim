#Util lib.
import ../../lib/Util

#Base lib.
import ../../lib/Base

#Address lib.
import ../../Wallet/Address

#Entry and Data object.
import ../../Database/Lattice/objects/EntryObj
import ../../Database/Lattice/objects/DataObj

#Common serialization functions.
import SerializeCommon

#Serialize a Data.
proc serialize*(data: Data): string {.raises: [ValueError].} =
    result =
        !data.nonce.toBinary() &
        !data.data

    if data.signature.len != 0:
        result =
            !Address.toBN(data.sender).toString(256) &
            result &
            !data.proof.toBinary() &
            !data.signature
