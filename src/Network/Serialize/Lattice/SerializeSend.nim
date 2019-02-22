#Util lib.
import ../../../lib/Util

#Base lib.
import ../../../lib/Base

#Address lib.
import ../../../Wallet/Address

#Entry and Send object.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/SendObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Send.
proc serialize*(send: Send): string {.raises: [ValueError].} =
    result =
        !Address.toBN(send.sender).toString(256) &
        !send.nonce.toBinary() &
        !Address.toBN(send.output).toString(256) &
        !send.amount.toString(256)

    if send.signature.len != 0:
        result =
            result &
            !send.proof.toBinary() &
            !send.signature
