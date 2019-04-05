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
        Address.toPublicKey(send.sender) &
        send.nonce.toBinary().pad(INT_LEN) &
        Address.toPublicKey(send.output) &
        send.amount.toString(256).pad(MEROS_LEN)

    if send.signature.len != 0:
        result =
            result &
            send.proof.toBinary().pad(INT_LEN) &
            send.signature
