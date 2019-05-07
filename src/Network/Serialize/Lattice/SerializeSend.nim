#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BN/Raw lib.
import ../../../lib/Raw

#Address anmd Wallet libraries.
import ../../../Wallet/Address
import ../../../Wallet/Wallet

#Entry and Send objects.
import ../../../Database/Lattice/objects/EntryObj
import ../../../Database/Lattice/objects/SendObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Send.
proc serialize*(
    send: Send
): string {.forceCheck: [
    AddressError
].} =
    var
        sender: string
        output: string
    try:
        sender = Address.toPublicKey(send.sender)
        output = Address.toPublicKey(send.output)
    except AddressError as e:
        fcRaise e

    result =
        sender &
        send.nonce.toBinary().pad(INT_LEN) &
        output &
        send.amount.toRaw().pad(MEROS_LEN)

    if send.signed:
        result =
            result &
            send.signature.toString() &
            send.proof.toBinary().pad(INT_LEN)
    else:
        result = "send" & result
