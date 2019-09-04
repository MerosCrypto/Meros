#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#MinerWallet lib.
import ../../../../../Wallet/MinerWallet

#TransactionStatus object.
import ../../../../Consensus/objects/TransactionStatusObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Parse function.
proc parseTransactionStatus*(
    statusStr: string
): TransactionStatus {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Epoch | Defaulting | Verified | Verifiers
    var statusSeq: seq[string] = statusStr.deserialize(
        INT_LEN,
        BYTE_LEN,
        BYTE_LEN,
        statusStr.len - (INT_LEN + BYTE_LEN + BYTE_LEN)
    )

    result = newTransactionStatusObj(statusSeq[0].fromBinary())
    result.defaulting = statusSeq[1] == "\1"
    result.verified = statusSeq[2] == "\1"

    if statusSeq[3].len mod 48 != 0:
        raise newException(ValueError, "TransactionStatus wasn't saved with a proper list of verifiers.")

    for v in countup(0, statusSeq[3].len - 1, 48):
        try:
            result.verifiers.add(newBLSPublicKey(statusSeq[3][v ..< v + 48]))
        except BLSError as e:
            fcRaise e