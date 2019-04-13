#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Address library.
import ../../../Wallet/Address

#LatticeIndex object.
import ../../../Database/common/objects/LatticeIndexObj

#Entry and Receive objects.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/ReceiveObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Receive.
func serialize*(
    recv: Receive
): string {.forceCheck: [
    AddressError
].} =
    var input: string
    try:
        input = Address.toPublicKey(recv.index.address)
    except AddressError as e:
        raise e

    result =
        recv.nonce.toBinary().pad(INT_LEN) &
        input &
        recv.index.nonce.toBinary().pad(INT_LEN)

    if recv.signature.len != 0:
        var sender: string
        try:
            sender = Address.toPublicKey(recv.sender)
        except AddressError as e:
            raise e

        result =
            sender &
            result &
            recv.signature
