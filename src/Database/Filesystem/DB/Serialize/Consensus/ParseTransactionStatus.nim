#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#Hash lib.
import ../../../../../lib/Hash

#TransactionStatus object.
import ../../../../Consensus/objects/TransactionStatusObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Sets standard lib.
import sets

#Start of the holders in a TransactionStatus.
const holdersStart: int = INT_LEN + BYTE_LEN + BYTE_LEN + BYTE_LEN + NICKNAME_LEN

#Parse function.
proc parseTransactionStatus*(
    statusStr: string,
    hash: Hash[384]
): TransactionStatus {.forceCheck: [].} =
    #Epoch | Competing | Verified | Beaten | Holders Len | Holders | Merit (if finalized)
    var statusSeq: seq[string] = statusStr.deserialize(
        INT_LEN,
        BYTE_LEN,
        BYTE_LEN,
        BYTE_LEN,
        NICKNAME_LEN
    )

    #Create the TransactionStatus.
    result = newTransactionStatusObj(
        hash,
        statusSeq[0].fromBinary()
    )

    result.competing = bool(statusSeq[1][0])
    result.verified = bool(statusSeq[2][0])
    result.beaten = bool(statusSeq[3][0])

    result.holders = initHashSet[uint16]()
    for i in 0 ..< statusSeq[4].fromBinary():
        result.holders.incl(
            uint16(statusStr[
                holdersStart + (i * NICKNAME_LEN) ..<
                holdersStart + NICKNAME_LEN + (i * NICKNAME_LEN)
            ].fromBinary())
        )

    if statusStr.len != holdersStart + (result.holders.len * NICKNAME_LEN):
        result.merit = statusStr[
            holdersStart + (result.holders.len * NICKNAME_LEN) ..<
            holdersStart + NICKNAME_LEN + (result.holders.len * NICKNAME_LEN)
        ].fromBinary()
