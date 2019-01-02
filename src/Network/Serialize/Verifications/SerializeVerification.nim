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
func serialize*(verif: Verification): string {.raises: [].} =
    result =
        !verif.verifier.toString() &
        !verif.nonce.toBinary() &
        !verif.hash.toString()
