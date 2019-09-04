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

#Serialization function.
proc serialize*(
    status: TransactionStatus
): string {.forceCheck: [].} =
    result =
        status.epoch.toBinary().pad(INT_LEN) &
        (if status.defaulting: char(1) else: char(0)) &
        (if status.verified: char(1) else: char(0))

    for verifier in status.verifiers:
        result &= verifier.toString()
