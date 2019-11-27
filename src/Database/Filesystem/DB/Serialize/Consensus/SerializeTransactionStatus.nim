#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#TransactionStatus object.
import ../../../../Consensus/objects/TransactionStatusObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Tables standard lib.
import tables

#Serialization function.
proc serialize*(
    status: TransactionStatus
): string {.forceCheck: [].} =
    result =
        status.epoch.toBinary().pad(INT_LEN) &
        char(status.competing) &
        char(status.verified) &
        char(status.beaten) &
        status.holders.len.toBinary().pad(NICKNAME_LEN)

    for holder in status.holders.keys():
        result &= holder.toBinary().pad(NICKNAME_LEN)

    if status.merit != -1:
        result &= status.merit.toBinary().pad(NICKNAME_LEN)
