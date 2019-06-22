#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Data object.
import ../../../Database/Transactions/objects/DataObj

#Common serialization functions.
import ../SerializeCommon

#SerializeTransaction method.
import SerializeTransaction
export SerializeTransaction

#Serialization functions.
method serializeHash*(
    data: Data
): string {.forceCheck: [].} =
    result =
        "\3" &
        data.inputs[0].hash.toString() &
        data.data

method serialize*(
    data: Data
): string {.inline, forceCheck: [].} =
    result =
        data.inputs[0].hash.toString() &
        char(data.data.len) &
        data.data &
        data.signature.toString() &
        data.proof.toBinary().pad(INT_LEN)
