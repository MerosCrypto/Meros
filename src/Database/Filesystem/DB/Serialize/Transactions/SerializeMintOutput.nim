#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#MintOutput object.
import ../../../..//Transactions/objects/TransactionObj

#SerializeOutput method.
import SerializeOutput
export SerializeOutput

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Serialization function.
method serialize*(
    output: MintOutput
): string {.inline, forceCheck: [].} =
    result =
        output.key.toBinary(NICKNAME_LEN) &
        output.amount.toBinary(MEROS_LEN)
