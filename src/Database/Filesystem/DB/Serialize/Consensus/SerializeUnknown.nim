#Errors lib.
import ../../../../../lib/Errors

#Hash lib.
import ../../../../../lib/Hash

#MinerWallet lib.
import ../../../../../Wallet/MinerWallet

#Verification object.
import ../../../../Consensus/objects/VerificationObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Serialization function.
proc serializeUnknown*(
    verif: Verification
): string {.forceCheck: [].} =
    result =
        verif.holder.toString() &
        verif.hash.toString()
