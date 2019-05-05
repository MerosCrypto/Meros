#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Address anmd Wallet libraries.
import ../../../Wallet/Address
import ../../../Wallet/Wallet

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
        fcRaise e

    result =
        sender &
        data.nonce.toBinary().pad(INT_LEN) &
        char(data.data.len) & data.data

    if data.signed:
        result =
            result &
            data.proof.toBinary().pad(INT_LEN) &
            data.signature.toString()
    else:
        result = "data" & result
