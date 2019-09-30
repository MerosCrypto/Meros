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
    ValueError
].} =
    if false:
        raise newException(ValueError, "")
    discard
