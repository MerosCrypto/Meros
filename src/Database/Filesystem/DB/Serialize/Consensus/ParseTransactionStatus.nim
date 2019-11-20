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

#Tables standard lib.
import tables

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
        INT_LEN
    )

    #Start of holders.
    const holdersStart: int = INT_LEN + BYTE_LEN + BYTE_LEN + BYTE_LEN + INT_LEN

    #Create the TransactionStatus.
    result = newTransactionStatusObj(
        hash,
        statusSeq[0].fromBinary()
    )

    result.competing = bool(statusSeq[1][0])
    result.verified = bool(statusSeq[2][0])
    result.beaten = bool(statusSeq[3][0])

    for i in 0 ..< statusSeq[4].fromBinary():
        result.holders[
            uint16(statusStr[
                holdersStart + (i * NICKNAME_LEN) ..<
                holdersStart + NICKNAME_LEN + (i * NICKNAME_LEN)
            ].fromBinary())
        ] = true

    if statusStr.len != holdersStart + (result.holders.len * NICKNAME_LEN):
        result.merit = statusStr[
            holdersStart + (result.holders.len * NICKNAME_LEN) ..<
            holdersStart + NICKNAME_LEN + (result.holders.len * NICKNAME_LEN)
        ].fromBinary()
