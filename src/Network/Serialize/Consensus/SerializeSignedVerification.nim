#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Verification object.
import ../../../Database/Consensus/objects/VerificationObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Memory Verification.
func serialize*(
    verif: SignedVerification
): string {.forceCheck: [].} =
    result =
        verif.holder.toString() &
        verif.nonce.toBinary().pad(INT_LEN) &
        verif.hash.toString() &
        verif.signature.toString()
