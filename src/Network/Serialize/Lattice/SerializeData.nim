#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Address lib.
import ../../../Wallet/Address

#Entry and Data objects.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/DataObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Data.
func serialize*(
    data: Data
): string {.forceCheck: [
    AddressError
].} =
    var sender: string
    try:
        sender = Address.toPublicKey(data.sender)
    except AddressError as e:
        raise e

    result =
        sender &
        data.nonce.toBinary().pad(INT_LEN) &
        char(data.data.len) & data.data

    if data.signature.len != 0:
        result =
            result &
            data.proof.toBinary().pad(INT_LEN) &
            data.signature
