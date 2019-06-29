#Errors lib.
import ../../../../../lib/Errors

#MinerWallet lib.
import ../../../../../Wallet/MinerWallet

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Serialization function.
proc serializeUnknown*(
    hash: string,
    key: BLSPublicKey
): string {.forceCheck: [].} =
    result =
        key.toString() &
        hash
