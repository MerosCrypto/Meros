#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Send object.
import ../../../Database/Transactions/objects/SendObj

#Common serialization functions.
import ../SerializeCommon

#SerializeTransaction method.
import SerializeTransaction
export SerializeTransaction

#Serialization functions.
method serializeHash*(
    send: Send
): string {.forceCheck: [].} =
    result = "\2"
    for input in send.inputs:
        result &=
            input.hash.toString() &
            cast[SendInput](input).nonce.toBinary().pad(BYTE_LEN)
    for output in send.outputs:
        result &=
            cast[SendOutput](output).key.toString() &
            output.amount.toBinary().pad(MEROS_LEN)

method serialize*(
    send: Send
): string {.inline, forceCheck: [].} =
    #Serialize the inputs.
    result = $char(send.inputs.len)
    for input in send.inputs:
        result &=
            input.hash.toString() &
            char(cast[SendInput](input).nonce)

    #Serialize the outputs.
    result &= char(send.outputs.len)
    for output in send.outputs:
        result &=
            cast[SendOutput](output).key.toString() &
            output.amount.toBinary().pad(MEROS_LEN)

    result &=
        send.signature.toString() &
        send.proof.toBinary().pad(INT_LEN)
