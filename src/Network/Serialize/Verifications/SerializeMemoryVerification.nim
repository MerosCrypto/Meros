#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Verification object.
import ../../../Database/Verifications/objects/VerificationObj

#Common serialization functions.
import ../SerializeCommon

#Serialize a Verification.
func serialize*(verif: MemoryVerification): string {.raises: [].} =
    result =
        verif.verifier.toString() &
        verif.nonce.toBinary().pad(INT_LEN) &
        verif.hash.toString() &
        verif.signature.toString()
