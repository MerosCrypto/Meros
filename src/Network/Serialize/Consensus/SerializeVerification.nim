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

#SerializeElement method.
import SerializeElement
export SerializeElement

#Serialize a Verification.
method serialize*(
    verif: Verification
): string {.forceCheck: [].} =
    result =
        verif.holder.toString() &
        verif.nonce.toBinary().pad(INT_LEN) &
        verif.hash.toString()

#Serialize a Verification for signing.
method serializeSign*(
    verif: Verification
): string {.forceCheck: [].} =
    result =
        char(VERIFICATION_PREFIX) &
        verif.serialize()

#Serialize a Signed Verification.
method signedSerialize*(
    verif: SignedVerification
): string {.forceCheck: [].} =
    result =
        verif.serialize() &
        verif.signature.toString()

#Serialize a Verification for a MeritRemoval.
method serializeRemoval*(
    verif: Verification
): string {.forceCheck: [].} =
    result =
        char(VERIFICATION_PREFIX) &
        verif.nonce.toBinary().pad(INT_LEN) &
        verif.hash.toString()
