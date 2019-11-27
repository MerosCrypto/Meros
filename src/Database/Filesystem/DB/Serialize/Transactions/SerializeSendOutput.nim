#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#Wallet lib.
import ../../../../../Wallet/Wallet

#SendOutput object.
import ../../../..//Transactions/objects/TransactionObj

#SerializeOutput method.
import SerializeOutput
export SerializeOutput

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Serialization function.
method serialize*(
    output: SendOutput
): string {.inline, forceCheck: [].} =
    result =
        output.key.toString() &
        output.amount.toBinary(MEROS_LEN)
