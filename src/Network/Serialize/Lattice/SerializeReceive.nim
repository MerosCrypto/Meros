#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Address anmd Wallet libraries.
import ../../../Wallet/Address
import ../../../Wallet/Wallet

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
        input = Address.toPublicKey(recv.input.address)
    except AddressError as e:
        fcRaise e

    result =
        recv.nonce.toBinary().pad(INT_LEN) &
        input &
        recv.input.nonce.toBinary().pad(INT_LEN)

    if recv.signed:
        var sender: string
        try:
            sender = Address.toPublicKey(recv.sender)
        except AddressError as e:
            fcRaise e

        result =
            sender &
            result &
            recv.signature.toString()
    else:
        result = "receive" & result
