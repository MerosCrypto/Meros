#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#Wallet lib.
import ../../../../../Wallet/Wallet

#SendOutput object.
import ../../../..//Transactions/objects/TransactionObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Parse function.
proc parseSendOutput*(
    outputStr: string
): SendOutput {.forceCheck: [
    EdPublicKeyError
].} =
    #Key | Amount
    var outputSeq: seq[string] = outputStr.deserialize(
        ED_PUBLIC_KEY_LEN,
        MEROS_LEN
    )

    #Create the SendOutput.
    try:
        result = newSendOutput(
            newEdPublicKey(outputSeq[0]),
            uint64(outputSeq[1].fromBinary())
        )
    except EdPublicKeyError as e:
        fcRaise e
