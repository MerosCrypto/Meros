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

#Serialization function.
proc serialize*(
    output: SendOutput
): string {.inline, forceCheck: [].} =
    result =
        output.key.toString() &
        output.amount.toBinary().pad(MEROS_LEN)
