#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#TransactionStatus object.
import ../../../../Consensus/objects/TransactionStatusObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Sets standard lib.
import sets

#Serialization function.
proc serialize*(
    status: TransactionStatus
): string {.forceCheck: [].} =
    result =
        status.epoch.toBinary(INT_LEN) &
        char(status.competing) &
        char(status.verified) &
        char(status.beaten) &
        status.holders.len.toBinary(NICKNAME_LEN)

    for holder in status.holders:
        result &= holder.toBinary(NICKNAME_LEN)

    if status.merit != -1:
        result &= status.merit.toBinary(NICKNAME_LEN)
